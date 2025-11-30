"""
Conversor DXF -> TXT (topologia + color + area) basado en Untitled5.ipynb.
Incluye clasificacion por color/layer, union topologica, polygonize y export con banderas de corte.
"""

from __future__ import annotations

from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

import ezdxf
import matplotlib.pyplot as plt
import numpy as np
from scipy.interpolate import splev, splprep
from shapely.geometry import LineString, MultiLineString, Polygon
from shapely.ops import linemerge, polygonize, unary_union
from sklearn.cluster import DBSCAN

TOL_TOPO = 0.05  # tolerancia para unir extremos (mm)


def procesar_entidad(e) -> dict | None:
    """Convierte entidad DXF a LineString con metadatos de color/layer."""
    dtype = e.dxftype()
    color = getattr(e.dxf, "color", None)
    layer = getattr(e.dxf, "layer", "") or ""
    puntos: Iterable[Sequence[float]] | None = None
    try:
        if dtype == "LINE":
            start, end = e.dxf.start, e.dxf.end
            puntos = [[start.x, start.y], [end.x, end.y]]
        elif dtype == "LWPOLYLINE":
            puntos = np.array(e.get_points())[:, :2]
        elif dtype == "POLYLINE":
            puntos = np.array([v.dxf.location[:2] for v in e.vertices])
        elif dtype == "CIRCLE":
            c, r = e.dxf.center, e.dxf.radius
            t = np.linspace(0, 2 * np.pi, 200)
            puntos = np.column_stack([c.x + r * np.cos(t), c.y + r * np.sin(t)])
        elif dtype == "ARC":
            c, r = e.dxf.center, e.dxf.radius
            a1, a2 = np.deg2rad(e.dxf.start_angle), np.deg2rad(e.dxf.end_angle)
            if a2 < a1:
                a2 += 2 * np.pi
            t = np.linspace(a1, a2, 120)
            puntos = np.column_stack([c.x + r * np.cos(t), c.y + r * np.sin(t)])
        elif dtype == "SPLINE":
            fit = np.array(getattr(e, "fit_points", []))
            if len(fit) >= 2:
                tck, _ = splprep([fit[:, 0], fit[:, 1]], s=0)
            else:
                ctrl = np.array(getattr(e, "control_points", []))
                if len(ctrl) < 2:
                    return None
                tck, _ = splprep([ctrl[:, 0], ctrl[:, 1]], s=0)
            u = np.linspace(0, 1, 200)
            x, y = splev(u, tck)
            puntos = np.column_stack([x, y])
        else:
            return None
    except Exception:
        return None

    if puntos is None or len(puntos) < 2:
        return None
    return {"geom": LineString(puntos), "color": color, "layer": layer}


def clasificar_color(color, layer: str) -> str:
    """Color 2 o capa que contenga 'NO' => NO_CORTAR."""
    try:
        if color is not None and int(color) == 2:
            return "NO_CORTAR"
    except Exception:
        pass
    if "NO" in layer.upper():
        return "NO_CORTAR"
    return "CORTAR"


def merge_and_snap(geoms: List[LineString], tol: float = TOL_TOPO) -> List[LineString]:
    if not geoms:
        return []
    endpoints = []
    for g in geoms:
        c = list(g.coords)
        endpoints.append(c[0])
        endpoints.append(c[-1])
    endpoints = np.array(endpoints)
    labels = DBSCAN(eps=tol, min_samples=1).fit_predict(endpoints)
    n_clusters = labels.max() + 1
    centroids = np.zeros((n_clusters, 2))
    for k in range(n_clusters):
        centroids[k] = endpoints[labels == k].mean(axis=0)

    snapped = []
    for i, g in enumerate(geoms):
        coords = list(g.coords)
        coords[0] = tuple(centroids[labels[2 * i]])
        coords[-1] = tuple(centroids[labels[2 * i + 1]])
        snapped.append(LineString(coords))

    merged = linemerge(unary_union(snapped))
    if isinstance(merged, LineString):
        return [merged]
    if isinstance(merged, MultiLineString):
        return list(merged.geoms)
    return []


def process_category(geoms: List[LineString]) -> Tuple[List[Polygon], List[LineString]]:
    merged = merge_and_snap(geoms)
    polys = list(polygonize(merged))
    opens: List[LineString] = []

    if merged:
        diff = unary_union(merged).difference(unary_union(polys))
        if isinstance(diff, LineString):
            opens.append(diff)
        elif isinstance(diff, MultiLineString):
            opens.extend(list(diff.geoms))
        elif hasattr(diff, "geoms"):
            for g in diff.geoms:
                if isinstance(g, LineString):
                    opens.append(g)
                elif isinstance(g, MultiLineString):
                    opens.extend(g.geoms)

    uniq_polys: List[Polygon] = []
    seen = set()
    for p in polys:
        k = p.exterior.wkt
        if k not in seen:
            seen.add(k)
            uniq_polys.append(p)
    return uniq_polys, opens


def exportar_txt(nombre: Path, polys_cut, opens_cut, polys_nocut, opens_nocut):
    geoms_final = _build_geoms_final(polys_cut, opens_cut, polys_nocut, opens_nocut)

    nombre.parent.mkdir(parents=True, exist_ok=True)
    with nombre.open("w", encoding="utf-8") as f:
        f.write("X Y Z CORTAR\n")
        for i, (geom, flag) in enumerate(geoms_final):
            if isinstance(geom, Polygon):
                x, y = geom.exterior.xy
                x, y = x[:-1], y[:-1]
            else:
                x, y = geom.xy
            for xi, yi in zip(x, y):
                f.write(f"{xi:.6f} {yi:.6f} 0.000 {flag}\n")
            if i < len(geoms_final) - 1:
                f.write("NaN NaN NaN NaN\n")
    print(f"Exportado: {nombre}")


def exportar_csv(nombre: Path, polys_cut, opens_cut, polys_nocut, opens_nocut):
    """Exporta a CSV con columnas X,Y,Z,C manteniendo NaN como separadores."""
    geoms_final = _build_geoms_final(polys_cut, opens_cut, polys_nocut, opens_nocut)
    nombre.parent.mkdir(parents=True, exist_ok=True)
    with nombre.open("w", encoding="utf-8") as f:
        f.write("X,Y,Z,C\n")
        for i, (geom, flag) in enumerate(geoms_final):
            if isinstance(geom, Polygon):
                x, y = geom.exterior.xy
                x, y = x[:-1], y[:-1]
            else:
                x, y = geom.xy
            for xi, yi in zip(x, y):
                f.write(f"{xi:.6f},{yi:.6f},0.000,{flag}\n")
            if i < len(geoms_final) - 1:
                f.write("NaN,NaN,NaN,NaN\n")
    print(f"Exportado CSV: {nombre}")


def _build_geoms_final(polys_cut, opens_cut, polys_nocut, opens_nocut):
    polys_sorted = sorted(polys_cut, key=lambda p: abs(p.area))
    geoms_final: List[Tuple[LineString | Polygon, int]] = []
    geoms_final.extend((g, 1) for g in polys_sorted)
    geoms_final.extend((g, 1) for g in opens_cut)
    geoms_final.extend((g, 0) for g in polys_nocut)
    geoms_final.extend((g, 0) for g in opens_nocut)
    return _reordenar_por_distancia(geoms_final)


def _centro_geom(geom: LineString | Polygon) -> Tuple[float, float]:
    if isinstance(geom, Polygon):
        c = geom.centroid
        return (c.x, c.y)
    c = geom.centroid
    return (c.x, c.y)


def _reordenar_por_distancia(
    geoms: List[Tuple[LineString | Polygon, int]]
) -> List[Tuple[LineString | Polygon, int]]:
    """Greedy nearest-neighbor sobre centroides para reducir saltos entre figuras."""
    if not geoms:
        return geoms
    remaining = geoms.copy()
    ordered: List[Tuple[LineString | Polygon, int]] = []
    # arranca en el centro más cercano al origen
    remaining.sort(key=lambda g: np.hypot(*_centro_geom(g[0])))
    current_geom, current_flag = remaining.pop(0)
    ordered.append((current_geom, current_flag))
    while remaining:
        cur_cx, cur_cy = _centro_geom(current_geom)
        nxt_idx, nxt_item = min(
            enumerate(remaining),
            key=lambda item: np.hypot(_centro_geom(item[1][0])[0] - cur_cx, _centro_geom(item[1][0])[1] - cur_cy),
        )
        current_geom, current_flag = nxt_item
        ordered.append((current_geom, current_flag))
        remaining.pop(nxt_idx)
    return ordered


def plot_result(polys_cut, opens_cut, polys_nocut, opens_nocut, show: bool = True):
    plt.figure(figsize=(9, 9))
    for p in polys_cut:
        x, y = p.exterior.xy
        plt.fill(x, y, "g", alpha=0.3)
        plt.plot(x, y, "k-", lw=0.6)
    for g in opens_cut:
        x, y = g.xy
        plt.plot(x, y, "g-", lw=2)
    for p in polys_nocut:
        x, y = p.exterior.xy
        plt.fill(x, y, "y", alpha=0.3)
        plt.plot(x, y, "r--", lw=1)
    for g in opens_nocut:
        x, y = g.xy
        plt.plot(x, y, "y--", lw=1)
    plt.axis("equal")
    plt.grid(True)
    plt.title("Topología reconstruida")
    if show:
        plt.show()
    return plt.gcf(), plt.gca()


def main():
    dxf_path = Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\dxf_files\UPC-30_ESPECIAL.dxf")
    out_txt = Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\trayectorias\UPC_30_ESPECIAL_3d.txt")
    if not dxf_path.is_file():
        raise FileNotFoundError(f"No se encontró el DXF: {dxf_path}")

    doc = ezdxf.readfile(dxf_path)
    msp = doc.modelspace()
    geoms_raw = []
    for e in msp:
        g = procesar_entidad(e)
        if g is not None:
            geoms_raw.append(g)
    if not geoms_raw:
        raise ValueError("No se detectaron entidades válidas en el DXF.")

    geoms_cortar = [g["geom"] for g in geoms_raw if clasificar_color(g["color"], g["layer"]) == "CORTAR"]
    geoms_nocortar = [g["geom"] for g in geoms_raw if clasificar_color(g["color"], g["layer"]) == "NO_CORTAR"]
    print(f"CORTAR: {len(geoms_cortar)}")
    print(f"NO CORTAR: {len(geoms_nocortar)}")

    polys_cut, opens_cut = process_category(geoms_cortar)
    polys_nocut, opens_nocut = process_category(geoms_nocortar)
    print(f"Polígonos corte: {len(polys_cut)} | Líneas corte: {len(opens_cut)}")
    print(f"Polígonos NO corte: {len(polys_nocut)} | Líneas NO corte: {len(opens_nocut)}")

    plot_result(polys_cut, opens_cut, polys_nocut, opens_nocut, show=True)
    exportar_txt(out_txt, polys_cut, opens_cut, polys_nocut, opens_nocut)
    exportar_csv(out_txt.with_suffix(".csv"), polys_cut, opens_cut, polys_nocut, opens_nocut)


if __name__ == "__main__":
    main()
