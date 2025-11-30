"""
Conversor DXF -> secuencia de corte jerarquica.
Basado en conversor_03.py, pero modular y orientado a objetos.
"""

from __future__ import annotations

import io
import math
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

import ezdxf
import matplotlib.pyplot as plt
import numpy as np
from scipy.interpolate import splev, splprep
from shapely.geometry import LineString, MultiLineString, Point, Polygon
from shapely.ops import linemerge, polygonize, unary_union
from sklearn.cluster import DBSCAN


class DxfHierarchyConverter:
    """Genera secuencias de corte/no-corte con jerarquia interior-exterior."""

    def __init__(
        self,
        dxf_path: str | Path,
        tol_topo: float = 0.05,
        interpolation_points: int = 200,
        min_ring_len: float = 1e-6,
        simplify_tolerance: float = 0.01,
        export_in_meters: bool = True,
    ) -> None:
        self.dxf_path = Path(dxf_path)
        self.tol_topo = tol_topo
        self.interpolation_points = interpolation_points
        self.min_ring_len = min_ring_len
        self.simplify_tolerance = simplify_tolerance
        self.export_in_meters = export_in_meters

        self._geoms: List[LineString] = []
        self._colors: List[int | Tuple[int, int, int]] = []
        self._layers: List[str] = []
        self._geoms_cut: List[LineString] = []
        self._geoms_nocut: List[LineString] = []
        self._rings_cut: List[LineString] = []
        self._open_cut: List[LineString] = []
        self._rings_nocut: List[LineString] = []
        self._open_nocut: List[LineString] = []
        self._supergroup_contours: List[List[LineString]] = []
        self._final_cut_seq: List[List[LineString]] = []
        self._final_nocut_seq: List[List[LineString]] = []

    # -------------------- API publica --------------------
    def process(self) -> "DxfHierarchyConverter":
        self._read_entities()
        self._split_by_color()
        merged_cut = self._unir_topologicamente(self._geoms_cut, self.tol_topo)
        merged_nocut = self._unir_topologicamente(self._geoms_nocut, self.tol_topo)
        self._rings_cut, self._open_cut = self._extract_rings_and_open(merged_cut)
        self._rings_nocut, self._open_nocut = self._extract_rings_and_open(merged_nocut)
        self._build_cut_sequence()
        self._build_nocut_sequence()
        return self

    def cut_sequence(self) -> List[List[LineString]]:
        self._require_sequences()
        return self._final_cut_seq

    def nocut_sequence(self) -> List[List[LineString]]:
        self._require_sequences()
        return self._final_nocut_seq

    def to_array(self) -> np.ndarray:
        """Devuelve ndarray (N,4) con X,Y,Z,CUT_FLAG (NaN separador). Z=0 en este flujo."""
        self._require_sequences()
        factor = 0.001 if self.export_in_meters else 1.0
        rows: List[Tuple[float, float, float, float]] = []

        def add_group(seq: List[List[LineString]], cut_flag: float):
            for group in seq:
                for chain in group:
                    x, y = chain.xy
                    for xi, yi in zip(x, y):
                        rows.append((xi * factor, yi * factor, 0.0, cut_flag))
                    rows.append((math.nan, math.nan, math.nan, math.nan))

        add_group(self._final_cut_seq, 1.0)
        add_group(self._final_nocut_seq, 0.0)
        return np.array(rows, dtype=float)

    def to_array_3d(
        self,
        z_guardado: float = 5.0,
        z_corte: float = 0.0,
        n_z_steps: int = 20,
    ) -> np.ndarray:
        """
        Devuelve ndarray (N,4) con X,Y,Z,CUT_FLAG, incluyendo subidas/bajadas por cadena.
        No conecta grupos entre sí; cada cadena baja a z_corte (si CUT) y sube a z_guardado.
        """
        self._require_sequences()
        factor = 0.001 if self.export_in_meters else 1.0
        rows: List[Tuple[float, float, float, float]] = []

        def add_cut_chain(coords: List[Tuple[float, float]]):
            if len(coords) < 2:
                return
            x0, y0 = coords[0]
            # descenso
            for z in np.linspace(z_guardado, z_corte, max(2, n_z_steps)):
                rows.append((x0 * factor, y0 * factor, z * factor, 1.0))
            # corte
            for x, y in coords:
                rows.append((x * factor, y * factor, z_corte * factor, 1.0))
            # ascenso
            x1, y1 = coords[-1]
            for z in np.linspace(z_corte, z_guardado, max(2, n_z_steps)):
                rows.append((x1 * factor, y1 * factor, z * factor, 1.0))
            rows.append((math.nan, math.nan, math.nan, math.nan))

        def add_nocut_chain(coords: List[Tuple[float, float]]):
            for x, y in coords:
                rows.append((x * factor, y * factor, z_guardado * factor, 0.0))
            rows.append((math.nan, math.nan, math.nan, math.nan))

        for group in self._final_cut_seq:
            for chain in group:
                add_cut_chain(list(chain.coords))
        for group in self._final_nocut_seq:
            for chain in group:
                add_nocut_chain(list(chain.coords))

        return np.array(rows, dtype=float)

    def export_txt(self, filename: str | Path = "TrayectoriaScaraCnc_PRO.txt") -> Path:
        """Exporta secuencia completa (corte + no corte) a TXT."""
        arr = self.to_array()
        out_path = Path(filename)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            f.write("X Y Z CUT_FLAG\n")
            for row in arr:
                if np.isnan(row).any():
                    f.write("NaN NaN NaN NaN\n")
                else:
                    f.write(
                        f"{row[0]:.6f} {row[1]:.6f} {row[2]:.6f} {row[3]:.0f}\n"
                    )
        return out_path

    def plot(self, show: bool = True):
        """Grafica jerarquia y secuencia (corte/no-corte)."""
        self._require_sequences()
        fig, ax = plt.subplots(figsize=(9, 9))
        for gi, sg in enumerate(self._final_cut_seq):
            for ci, contour in enumerate(sg):
                x, y = contour.xy
                if ci < len(sg) - 1:
                    ax.plot(
                        x,
                        y,
                        linestyle="--",
                        linewidth=1.3,
                        label="CORTAR (interior)" if gi == 0 and ci == 0 else "",
                    )
                else:
                    ax.plot(
                        x,
                        y,
                        linestyle="-",
                        linewidth=1.7,
                        label="CORTAR (exterior)" if gi == 0 else "",
                    )
        for i, sg in enumerate(self._final_nocut_seq):
            for contour in sg:
                x, y = contour.xy
                ax.plot(
                    x, y, linestyle=":", linewidth=1.2, label="NO_CORTAR" if i == 0 else ""
                )
        ax.set_aspect("equal", adjustable="box")
        ax.set_title("Jerarquia y orden de corte")
        ax.set_xlabel("X [mm]")
        ax.set_ylabel("Y [mm]")
        ax.grid(True)
        ax.legend()
        if show:
            plt.show()
        return fig, ax

    def plot_3d(
        self,
        show: bool = True,
        z_guardado: float = 5.0,
        z_corte: float = 0.0,
        n_z_steps: int = 20,
    ):
        """Grafica 3D de las secuencias (corte/no-corte) con subidas/bajadas."""
        self._require_sequences()
        arr = self.to_array_3d(
            z_guardado=z_guardado, z_corte=z_corte, n_z_steps=n_z_steps
        )
        fig = plt.figure(figsize=(10, 6))
        ax = fig.add_subplot(111, projection="3d")
        # separar tramos por NaN
        is_nan = np.isnan(arr).any(axis=1)
        splits = np.where(is_nan)[0]
        start = 0
        for idx in range(len(splits) + 1):
            end = splits[idx] if idx < len(splits) else len(arr)
            segment = arr[start:end]
            if segment.size:
                cut_flag = segment[0, 3] if segment.shape[0] else 1.0
                color = "#00aa00" if cut_flag == 1 else "#ffaa00"
                ax.plot(segment[:, 0], segment[:, 1], segment[:, 2], color=color, linewidth=0.8)
            start = end + 1
        ax.set_xlabel("X")
        ax.set_ylabel("Y")
        ax.set_zlabel("Z")
        ax.set_title("Trayectoria 3D (corte/no-corte)")
        if show:
            plt.show()
        return fig, ax

    # -------------------- Etapas internas --------------------
    def _read_entities(self) -> None:
        doc = ezdxf.readfile(self.dxf_path)
        msp = doc.modelspace()
        geoms: List[LineString] = []
        colors: List[int | Tuple[int, int, int]] = []
        layers: List[str] = []
        for ent in msp:
            geom, color, layer = self._entity_to_linestring(ent)
            if geom is not None:
                geoms.append(geom)
                colors.append(color)
                layers.append(layer)
        if not geoms:
            raise ValueError("No se detectaron entidades validas en el DXF.")
        self._geoms = geoms
        self._colors = colors
        self._layers = layers

    def _split_by_color(self) -> None:
        geoms_cut: List[LineString] = []
        geoms_nocut: List[LineString] = []
        for g, c, l in zip(self._geoms, self._colors, self._layers):
            if self._clasificar_color(c, l) == "NO_CORTAR":
                geoms_nocut.append(g)
            else:
                geoms_cut.append(g)
        if not geoms_cut:
            raise ValueError("No hay entidades de corte (todas clasificadas como NO_CORTAR).")
        self._geoms_cut = geoms_cut
        self._geoms_nocut = geoms_nocut

    def _build_cut_sequence(self) -> None:
        polys_cortar = []
        ring_to_poly_map: dict[int, LineString] = {}
        for r in self._rings_cut:
            p = self._ring_to_polygon(r)
            if p is not None:
                polys_cortar.append(p)
                ring_to_poly_map[id(p)] = r

        supergroups_cortar, _ = self._build_supergroups(polys_cortar)
        supergroup_contours: List[List[LineString]] = []
        for _, members in supergroups_cortar.items():
            contours = self._poly_index_to_contours(members, polys_cortar)
            contours_sorted = sorted(contours, key=lambda c: c.length)
            supergroup_contours.append(contours_sorted)

        remaining_rings = []
        for r in self._rings_cut:
            used = False
            for p in polys_cortar:
                r_used = ring_to_poly_map.get(id(p))
                if r_used is None:
                    continue
                if abs(r_used.length - r.length) < 1e-6 and Point(r.centroid).distance(
                    Point(r_used.centroid)
                ) < 1e-6:
                    used = True
                    break
            if not used:
                remaining_rings.append(r)
        for r in remaining_rings:
            supergroup_contours.append([r])

        open_groups = [[ln] for ln in sorted(self._open_cut, key=lambda l: l.length)]

        final_cut_sequence: List[List[LineString]] = []
        final_cut_sequence.extend(supergroup_contours)
        final_cut_sequence.extend(open_groups)

        self._supergroup_contours = supergroup_contours
        self._final_cut_seq = final_cut_sequence

    def _build_nocut_sequence(self) -> None:
        seq: List[List[LineString]] = []
        for r in self._rings_nocut:
            seq.append([r])
        for ln in sorted(self._open_nocut, key=lambda l: l.length):
            seq.append([ln])
        self._final_nocut_seq = seq

    # -------------------- Utilidades geom --------------------
    def _entity_to_linestring(
        self, e
    ) -> Tuple[LineString | None, int | Tuple[int, int, int], str]:
        dtype = e.dxftype()
        color = self._get_color(e)
        layer = self._get_layer(e)
        puntos: Iterable[Sequence[float]] | None = None
        try:
            if dtype == "LINE":
                start, end = e.dxf.start, e.dxf.end
                puntos = np.array([[start.x, start.y], [end.x, end.y]])
            elif dtype == "LWPOLYLINE":
                puntos = np.array(e.get_points())[:, :2]
            elif dtype == "POLYLINE":
                pts = [v.dxf.location[:2] for v in e.vertices]
                puntos = np.array(pts)
            elif dtype == "CIRCLE":
                c, r = e.dxf.center, e.dxf.radius
                t = np.linspace(0, 2 * np.pi, self.interpolation_points)
                puntos = np.column_stack([c.x + r * np.cos(t), c.y + r * np.sin(t)])
            elif dtype == "ARC":
                c, r = e.dxf.center, e.dxf.radius
                a1, a2 = np.deg2rad(e.dxf.start_angle), np.deg2rad(e.dxf.end_angle)
                if a2 < a1:
                    a2 += 2 * np.pi
                t = np.linspace(a1, a2, max(10, self.interpolation_points // 2))
                puntos = np.column_stack([c.x + r * np.cos(t), c.y + r * np.sin(t)])
            elif dtype == "SPLINE":
                fit = np.array(getattr(e, "fit_points", []))
                if len(fit) >= 2:
                    tck, _ = splprep([fit[:, 0], fit[:, 1]], s=0)
                    u = np.linspace(0, 1, self.interpolation_points)
                    x, y = splev(u, tck)
                    puntos = np.column_stack([x, y])
                else:
                    ctrl = np.array(getattr(e, "control_points", []))
                    if len(ctrl) >= 2:
                        tck, _ = splprep([ctrl[:, 0], ctrl[:, 1]], s=0)
                        u = np.linspace(0, 1, self.interpolation_points)
                        x, y = splev(u, tck)
                        puntos = np.column_stack([x, y])
        except Exception as exc:
            print(f"No se pudo procesar {dtype}: {exc}")
            return None, color, layer

        if puntos is None or len(puntos) < 2:
            return None, color, layer
        pts = [tuple(p) for p in puntos]
        pts_clean = [pts[0]]
        for p in pts[1:]:
            if p != pts_clean[-1]:
                pts_clean.append(p)
        if len(pts_clean) < 2:
            return None, color, layer
        return LineString(pts_clean), color, layer

    def _get_color(self, ent) -> int | Tuple[int, int, int]:
        try:
            if hasattr(ent.dxf, "true_color") and ent.dxf.get("true_color", None):
                rgb = ent.rgb
                if rgb is not None:
                    return tuple(rgb)
            color_index = int(getattr(ent.dxf, "color", 7))
            if color_index <= 0 or color_index == 256:
                layer = ent.dxf.layer
                layer_color_index = int(ent.doc.layers.get(layer).color)
                return layer_color_index
            return color_index
        except Exception:
            return 7

    @staticmethod
    def _get_layer(ent) -> str:
        try:
            return str(ent.dxf.layer) if hasattr(ent.dxf, "layer") else ""
        except Exception:
            return ""

    @staticmethod
    def _is_yellow(color) -> bool:
        """Detecta amarillo por ACI==2 o RGB cercano a amarillo."""
        if color is None:
            return False
        try:
            if int(color) == 2:
                return True
        except Exception:
            pass
        if isinstance(color, (tuple, list)) and len(color) == 3:
            r, g, b = color
            try:
                return (r >= 200) and (g >= 200) and (b <= 120)
            except Exception:
                return False
        return False

    def _clasificar_color(self, color, layer) -> str:
        if self._is_yellow(color):
            return "NO_CORTAR"
        if isinstance(layer, str) and "NO" in layer.upper():
            return "NO_CORTAR"
        return "CORTAR"

    def _unir_topologicamente(
        self, geoms: List[LineString], tolerancia: float
    ) -> List[LineString]:
        if not geoms:
            return []
        endpoints = []
        for g in geoms:
            coords = list(g.coords)
            endpoints.append(coords[0])
            endpoints.append(coords[-1])
        endpoints_arr = np.array(endpoints)
        labels = DBSCAN(eps=tolerancia, min_samples=1).fit_predict(endpoints_arr)
        n_clusters = labels.max() + 1
        centroids = np.zeros((n_clusters, 2))
        for k in range(n_clusters):
            pts = endpoints_arr[labels == k]
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

    def _extract_rings_and_open(
        self, merged_list: List[LineString]
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
                if ext.length > self.min_ring_len:
                    rings.append(ext)
            except Exception:
                pass
            for hole in p.interiors:
                try:
                    h = LineString(hole.coords)
                    if h.length > self.min_ring_len:
                        rings.append(h)
                except Exception:
                    pass
        for g in merged_list:
            try:
                coords = list(g.coords)
                if len(coords) >= 4 and (
                    np.allclose(coords[0], coords[-1]) or g.is_ring
                ):
                    if g.length > self.min_ring_len:
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

    def _ring_to_polygon(self, ring_ls: LineString) -> Polygon | None:
        try:
            coords = list(ring_ls.coords)
            if not np.allclose(coords[0], coords[-1]):
                coords = coords + [coords[0]]
            poly = Polygon(coords)
            if self.simplify_tolerance > 0:
                poly = poly.simplify(self.simplify_tolerance, preserve_topology=True)
            if not poly.is_valid:
                poly = poly.buffer(0)
            if poly.is_valid and poly.area > 0:
                return poly
        except Exception:
            pass
        return None

    @staticmethod
    def _build_supergroups(polys: List[Polygon]):
        n = len(polys)
        if n == 0:
            return {}, []
        parents = [-1] * n
        areas = [polys[i].area for i in range(n)]
        reps = [polys[i].representative_point() for i in range(n)]
        bounds = [polys[i].bounds for i in range(n)]  # minx, miny, maxx, maxy
        idx_by_area = sorted(range(n), key=lambda i: areas[i])
        for i in range(n):
            candidates: List[Tuple[float, int]] = []
            rep = reps[i]
            rx, ry = rep.x, rep.y
            area_i = areas[i]
            # Solo considerar j con area mayor (posible contenedor) y cuyo bbox incluya rep
            for j in idx_by_area:
                if j == i or areas[j] <= area_i:
                    continue
                minx, miny, maxx, maxy = bounds[j]
                if not (minx <= rx <= maxx and miny <= ry <= maxy):
                    continue
                if polys[j].contains(rep):
                    candidates.append((areas[j], j))
            if candidates:
                candidates.sort()
                parents[i] = candidates[0][1]
        supergroups: dict[int, List[int]] = {}
        for i in range(n):
            root = i
            hops = 0
            while parents[root] != -1 and hops <= n:
                root = parents[root]
                hops += 1
            if hops > n:
                # ciclo detectado; romper jerarquia para este nodo
                root = i
                parents[i] = -1
            if root not in supergroups:
                supergroups[root] = []
            supergroups[root].append(i)
        return supergroups, parents

    @staticmethod
    def _poly_index_to_contours(indices: List[int], polys: List[Polygon]) -> List[LineString]:
        contours: List[LineString] = []
        for idx in indices:
            p = polys[idx]
            try:
                ext_ring = LineString(p.exterior.coords)
                contours.append(ext_ring)
            except Exception:
                pass
            for hole in p.interiors:
                try:
                    hole_ls = LineString(hole.coords)
                    contours.append(hole_ls)
                except Exception:
                    pass
        return contours

    def _require_sequences(self) -> None:
        if not self._final_cut_seq and not self._final_nocut_seq:
            raise RuntimeError("Ejecuta process() antes de acceder a las secuencias.")


if __name__ == "__main__":
    demo_path = Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\dxf_files\logo7_especial.dxf")
    demo_path_out = Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\trayectorias\logo7_especial_hi.txt")
    
    
    # demo_path = Path(r"docs/dxf_files/corte_especial.dxf")
    if not demo_path.is_file():
        raise FileNotFoundError(f"No se encontro el DXF en {demo_path}")

    converter = DxfHierarchyConverter(
        dxf_path=demo_path,
        tol_topo=0.05,
        interpolation_points=200,
        min_ring_len=1e-6,
        simplify_tolerance=0.01,
        export_in_meters=True,
    ).process()

    arr = converter.to_array()
    print("Muestra de trayectoria:", arr[:5])
    out_file = converter.export_txt(demo_path_out)
    print(f"Exportado: {out_file}")
    converter.plot(show=True)
    converter.plot_3d(show=True)
