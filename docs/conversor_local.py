"""
Conversor DXF -> TXT (SCARA/CNC) para uso local.

Basado en la version Pro del notebook original, sin dependencias de Google Colab.
Permite escoger el DXF con un dialogo de archivos o pasando la ruta por argumento.
"""

from __future__ import annotations

import argparse
import io
import sys
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

import ezdxf
import matplotlib.pyplot as plt
import numpy as np
from scipy.interpolate import splev, splprep
from shapely.geometry import LineString, MultiLineString, Point, Polygon
from shapely.ops import linemerge, polygonize, unary_union
from sklearn.cluster import DBSCAN

# Parametros principales (ajusta segun tu proyecto)
TOL_TOPO = 0.05  # mm - tolerancia para unir extremos
EXPORT_IN_METERS = True  # True -> divide por 1000 al exportar
INTERPOLATION_POINTS = 200  # puntos para CIRCLE/ARC/SPLINE
MIN_RING_LEN = 1e-6  # tolerancia para descartar anillos degenerados
SIMPLIFY_TOLERANCE = 0.01  # simplificacion de poligonos para acelerar (mm)
DEFAULT_OUTPUT = "TrayectoriaScaraCnc_PRO.txt"


def prompt_for_dxf(cli_path: str | None) -> Path:
    """Obtiene la ruta del DXF desde CLI o dialogo grafico."""
    if cli_path:
        path = Path(cli_path).expanduser()
        if not path.is_file():
            sys.exit(f"No existe el archivo DXF: {path}")
        return path

    # Intento de dialogo grafico (tkinter). Si falla, se pide por consola.
    try:
        import tkinter as tk
        from tkinter import filedialog

        root = tk.Tk()
        root.withdraw()
        dialog_path = filedialog.askopenfilename(
            title="Selecciona un DXF",
            filetypes=[("DXF", "*.dxf"), ("Todos", "*.*")],
        )
        root.destroy()
        if dialog_path:
            return Path(dialog_path)
    except Exception:
        pass

    while True:
        raw = input("Ruta del DXF (Enter para cancelar): ").strip()
        if not raw:
            sys.exit("No se selecciono ningun archivo DXF.")
        path = Path(raw).expanduser()
        if path.is_file():
            return path
        print("Ruta invalida, intenta nuevamente.")


def clean_points(points: Iterable[Tuple[float, float]]) -> List[Tuple[float, float]]:
    """Elimina duplicados consecutivos manteniendo el orden."""
    pts = list(points)
    if not pts:
        return []
    cleaned = [pts[0]]
    for p in pts[1:]:
        if p != cleaned[-1]:
            cleaned.append(p)
    return cleaned


def convert_entity(e) -> dict | None:
    """Convierte una entidad DXF en LineString + metadatos de color/layer."""
    dtype = e.dxftype()
    color = None
    layer = ""
    try:
        color = int(getattr(e.dxf, "color", None))
    except Exception:
        color = None
    try:
        layer = str(getattr(e.dxf, "layer", "") or "")
    except Exception:
        layer = ""

    puntos = None
    try:
        if dtype == "LINE":
            start, end = e.dxf.start, e.dxf.end
            puntos = np.array([[start.x, start.y], [end.x, end.y]])
        elif dtype == "LWPOLYLINE":
            pts = np.array(e.get_points())[:, :2]
            puntos = pts
        elif dtype == "POLYLINE":
            pts = [v.dxf.location[:2] for v in e.vertices]
            puntos = np.array(pts)
        elif dtype == "CIRCLE":
            c, r = e.dxf.center, e.dxf.radius
            t = np.linspace(0, 2 * np.pi, INTERPOLATION_POINTS)
            puntos = np.column_stack([c.x + r * np.cos(t), c.y + r * np.sin(t)])
        elif dtype == "ARC":
            c, r = e.dxf.center, e.dxf.radius
            a1, a2 = np.deg2rad(e.dxf.start_angle), np.deg2rad(e.dxf.end_angle)
            if a2 < a1:
                a2 += 2 * np.pi
            t = np.linspace(a1, a2, max(10, INTERPOLATION_POINTS // 2))
            puntos = np.column_stack([c.x + r * np.cos(t), c.y + r * np.sin(t)])
        elif dtype == "SPLINE":
            fit = None
            try:
                fit = np.array(e.fit_points)
            except Exception:
                fit = None
            if fit is not None and len(fit) >= 2:
                tck, _ = splprep([fit[:, 0], fit[:, 1]], s=0)
                u = np.linspace(0, 1, INTERPOLATION_POINTS)
                x, y = splev(u, tck)
                puntos = np.column_stack([x, y])
            else:
                try:
                    ctrl = np.array(e.control_points)
                except Exception:
                    ctrl = None
                if ctrl is not None and len(ctrl) >= 2:
                    tck, _ = splprep([ctrl[:, 0], ctrl[:, 1]], s=0)
                    u = np.linspace(0, 1, INTERPOLATION_POINTS)
                    x, y = splev(u, tck)
                    puntos = np.column_stack([x, y])
    except Exception:
        return None

    if puntos is None or len(puntos) < 2:
        return None

    pts_clean = clean_points([tuple(p) for p in puntos])
    if len(pts_clean) < 2:
        return None

    return {
        "geom": LineString(pts_clean),
        "color": color,
        "layer": layer,
        "type": dtype,
    }


def read_dxf_geoms(dxf_path: Path) -> List[dict]:
    doc = ezdxf.readfile(dxf_path)
    msp = doc.modelspace()
    geoms: List[dict] = []
    for e in msp:
        g = convert_entity(e)
        if g is not None:
            geoms.append(g)
    if not geoms:
        raise ValueError("No se detectaron entidades validas en el DXF.")
    return geoms


def clasificar_color(color: int | None, layer: str) -> str:
    if color is not None and int(color) == 2:
        return "NO_CORTAR"
    if layer and "NO" in layer.upper():
        return "NO_CORTAR"
    return "CORTAR"


def unir_topologicamente(
    geoms: Sequence[LineString], tolerancia: float = TOL_TOPO
) -> List[LineString]:
    if not geoms:
        return []

    endpoints = []
    for g in geoms:
        coords = list(g.coords)
        endpoints.append(coords[0])
        endpoints.append(coords[-1])

    endpoints = np.array(endpoints)
    if len(endpoints) == 0:
        return []

    labels = DBSCAN(eps=tolerancia, min_samples=1).fit_predict(endpoints)
    n_clusters = labels.max() + 1
    centroids = np.zeros((n_clusters, 2))
    for k in range(n_clusters):
        pts = endpoints[labels == k]
        centroids[k] = pts.mean(axis=0)

    geoms_sanitized = []
    for gi, g in enumerate(geoms):
        coords = list(g.coords)
        label_start = labels[2 * gi]
        label_end = labels[2 * gi + 1]
        new_coords = coords.copy()
        new_coords[0] = tuple(centroids[label_start])
        new_coords[-1] = tuple(centroids[label_end])
        geoms_sanitized.append(LineString(new_coords))

    union = unary_union(geoms_sanitized)
    merged = linemerge(union)
    merged_list: List[LineString] = []
    if isinstance(merged, LineString):
        merged_list = [merged]
    elif isinstance(merged, MultiLineString):
        merged_list = list(merged.geoms)
    else:
        try:
            for g in merged:
                if isinstance(g, LineString):
                    merged_list.append(g)
        except Exception:
            pass
    return merged_list


def extract_rings_and_openlines(
    merged_list: Sequence[LineString],
) -> Tuple[List[LineString], List[LineString]]:
    rings: List[LineString] = []
    open_lines: List[LineString] = []

    try:
        u = unary_union(merged_list)
        polys = list(polygonize(u))
    except Exception:
        polys = []

    for p in polys:
        try:
            ext = LineString(p.exterior.coords)
            if ext.length > MIN_RING_LEN:
                rings.append(ext)
        except Exception:
            pass
        for hole in p.interiors:
            try:
                h = LineString(hole.coords)
                if h.length > MIN_RING_LEN:
                    rings.append(h)
            except Exception:
                pass

    for g in merged_list:
        try:
            coords = list(g.coords)
            if len(coords) >= 4 and (np.allclose(coords[0], coords[-1]) or g.is_ring):
                if g.length > MIN_RING_LEN:
                    dup = False
                    for r in rings:
                        if abs(r.length - g.length) < 1e-6 and Point(
                            r.centroid
                        ).distance(Point(g.centroid)) < 1e-6:
                            dup = True
                            break
                    if not dup:
                        rings.append(LineString(g.coords))
            else:
                open_lines.append(g)
        except Exception:
            open_lines.append(g)
    return rings, open_lines


def ring_to_polygon(
    ring_ls: LineString, tolerance: float = SIMPLIFY_TOLERANCE
) -> Polygon | None:
    try:
        coords = list(ring_ls.coords)
        if not np.allclose(coords[0], coords[-1]):
            coords = coords + [coords[0]]
        poly = Polygon(coords)
        if tolerance > 0:
            poly = poly.simplify(tolerance, preserve_topology=True)
        if not poly.is_valid:
            poly = poly.buffer(0)
        if poly.is_valid and poly.area > 0:
            return poly
    except Exception:
        return None
    return None


def build_supergroups(polys: Sequence[Polygon]):
    n = len(polys)
    parents = [-1] * n
    areas = [polys[i].area for i in range(n)]
    for i in range(n):
        candidates = []
        pi = polys[i]
        rep = pi.representative_point()
        for j in range(n):
            if i == j:
                continue
            pj = polys[j]
            if pj.contains(rep):
                candidates.append((areas[j], j))
        if candidates:
            candidates.sort()
            parents[i] = candidates[0][1]

    supergroups = {}
    for i in range(n):
        root = i
        while parents[root] != -1:
            root = parents[root]
        supergroups.setdefault(root, []).append(i)
    return supergroups, parents


def poly_index_to_contours(
    poly_indices: Iterable[int], polys: Sequence[Polygon]
) -> List[LineString]:
    contours: List[LineString] = []
    for idx in poly_indices:
        p = polys[idx]
        try:
            contours.append(LineString(p.exterior.coords))
        except Exception:
            pass
        for hole in p.interiors:
            try:
                contours.append(LineString(hole.coords))
            except Exception:
                pass
    return contours


def build_sequences(
    geoms_cortar: Sequence[LineString],
    geoms_nocortar: Sequence[LineString],
):
    merged_cortar = unir_topologicamente(geoms_cortar, tolerancia=TOL_TOPO)
    merged_nocortar = unir_topologicamente(geoms_nocortar, tolerancia=TOL_TOPO)

    rings_cortar, open_cortar = extract_rings_and_openlines(merged_cortar)
    rings_nocortar, open_nocortar = extract_rings_and_openlines(merged_nocortar)

    polys_cortar: List[Polygon] = []
    ring_to_poly_map = {}
    for r in rings_cortar:
        p = ring_to_polygon(r)
        if p is not None:
            polys_cortar.append(p)
            ring_to_poly_map[id(p)] = r

    supergroups_cortar, _ = build_supergroups(polys_cortar)

    supergroup_contours: List[List[LineString]] = []
    for _, members in supergroups_cortar.items():
        contours = poly_index_to_contours(members, polys_cortar)
        contours_sorted = sorted(contours, key=lambda c: c.length)
        supergroup_contours.append(contours_sorted)

    polys_rings_ids = set()
    for p in polys_cortar:
        ring = ring_to_poly_map.get(id(p))
        if ring is not None:
            polys_rings_ids.add(id(ring))

    remaining_rings = []
    for r in rings_cortar:
        used = False
        for p in polys_cortar:
            r_used = ring_to_poly_map.get(id(p))
            if r_used is None:
                continue
            if abs(r_used.length - r.length) < 1e-6 and Point(
                r.centroid
            ).distance(Point(r_used.centroid)) < 1e-6:
                used = True
                break
        if not used:
            remaining_rings.append(r)

    for r in remaining_rings:
        supergroup_contours.append([r])

    open_groups = [[ln] for ln in sorted(open_cortar, key=lambda l: l.length)]

    final_cut_sequence: List[List[LineString]] = []
    for sg in supergroup_contours:
        final_cut_sequence.append(sg)
    for og in open_groups:
        final_cut_sequence.append(og)

    final_nocut_sequence: List[List[LineString]] = []
    for r in rings_nocortar:
        final_nocut_sequence.append([r])
    for ln in sorted(open_nocortar, key=lambda l: l.length):
        final_nocut_sequence.append([ln])

    return final_cut_sequence, final_nocut_sequence


def export_sequence_to_txt(
    filename: Path,
    cut_seq: Sequence[Sequence[LineString]],
    nocut_seq: Sequence[Sequence[LineString]],
    export_in_meters: bool = EXPORT_IN_METERS,
) -> None:
    factor = 0.001 if export_in_meters else 1.0
    out = io.StringIO()
    out.write("# X Y Z CUT_FLAG\n")

    for group in cut_seq:
        for chain in group:
            x, y = chain.xy
            for xi, yi in zip(x, y):
                out.write(f"{xi * factor:.6f} {yi * factor:.6f} 0.000 1\n")
            out.write("NaN NaN NaN NaN\n")

    for group in nocut_seq:
        for chain in group:
            x, y = chain.xy
            for xi, yi in zip(x, y):
                out.write(f"{xi * factor:.6f} {yi * factor:.6f} 0.000 0\n")
            out.write("NaN NaN NaN NaN\n")

    filename.write_text(out.getvalue())
    print(f"Exportado: {filename} (en metros: {export_in_meters})")


def plot_sequences(
    final_cut_sequence: Sequence[Sequence[LineString]],
    final_nocut_sequence: Sequence[Sequence[LineString]],
) -> None:
    plt.figure(figsize=(9, 9))
    for gi, sg in enumerate(final_cut_sequence):
        for ci, contour in enumerate(sg):
            x, y = contour.xy
            if ci < len(sg) - 1:
                plt.plot(
                    x,
                    y,
                    linestyle="--",
                    linewidth=1.3,
                    label="CORTAR (interior)" if gi == 0 and ci == 0 else "",
                )
            else:
                plt.plot(
                    x,
                    y,
                    linestyle="-",
                    linewidth=1.7,
                    label="CORTAR (exterior)" if gi == 0 else "",
                )
    for i, sg in enumerate(final_nocut_sequence):
        for contour in sg:
            x, y = contour.xy
            plt.plot(
                x,
                y,
                linestyle=":",
                linewidth=1.2,
                label="NO_CORTAR" if i == 0 else "",
            )

    plt.axis("equal")
    plt.title("Jerarquia y orden de corte (interior primero -> exterior ultimo)")
    plt.xlabel("X [mm]")
    plt.ylabel("Y [mm]")
    plt.grid(True)
    plt.legend()
    plt.show()


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Conversor DXF -> trayectoria TXT (SCARA/CNC) sin Colab."
    )
    parser.add_argument("-i", "--input", help="Ruta del archivo DXF a procesar.")
    parser.add_argument(
        "-o",
        "--output",
        help="Ruta de salida .txt. Por defecto se guarda junto al DXF.",
    )
    parser.add_argument(
        "--meters",
        dest="meters",
        action=argparse.BooleanOptionalAction,
        default=EXPORT_IN_METERS,
        help="Exportar en metros (divide por 1000). Usa --no-meters para mantener mm.",
    )
    parser.add_argument(
        "--no-plot",
        action="store_true",
        help="Omite la ventana de grafico.",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> None:
    args = parse_args(argv)
    dxf_path = prompt_for_dxf(args.input)
    print(f"Archivo cargado: {dxf_path}")

    geoms = read_dxf_geoms(dxf_path)
    geoms_cortar = [
        g["geom"] for g in geoms if clasificar_color(g["color"], g["layer"]) == "CORTAR"
    ]
    geoms_nocortar = [
        g["geom"]
        for g in geoms
        if clasificar_color(g["color"], g["layer"]) == "NO_CORTAR"
    ]

    print(f"Figuras a cortar (raw): {len(geoms_cortar)}")
    print(f"Figuras NO cortar (raw): {len(geoms_nocortar)}")

    final_cut_sequence, final_nocut_sequence = build_sequences(
        geoms_cortar, geoms_nocortar
    )

    print(f"Secuencia de corte (grupos): {len(final_cut_sequence)}")
    print(f"Secuencia NO_CORTAR (grupos): {len(final_nocut_sequence)}")

    output_path = (
        Path(args.output)
        if args.output
        else dxf_path.with_name(f"{dxf_path.stem}_trayectoria.txt")
    )
    export_sequence_to_txt(output_path, final_cut_sequence, final_nocut_sequence, args.meters)

    if not args.no_plot:
        try:
            plot_sequences(final_cut_sequence, final_nocut_sequence)
        except Exception as exc:
            print(f"No se pudo mostrar el grafico: {exc}")


if __name__ == "__main__":
    main()
