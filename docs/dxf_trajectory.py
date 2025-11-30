"""
Conversor DXF -> trayectoria 3D (corte/no-corte) con resample y perfiles de velocidad.
Modular y orientado a objetos, basado en converter_02.py.
"""

from __future__ import annotations

import math
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

import ezdxf
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401 - needed for 3D plot
from scipy.interpolate import splev, splprep
from shapely.geometry import LineString, MultiLineString, Point, Polygon
from shapely.ops import linemerge, polygonize, unary_union
from sklearn.cluster import DBSCAN


class DxfTrajectoryPlanner:
    """Genera trayectoria 3D a partir de un DXF, separando corte/no-corte por color."""

    def __init__(
        self,
        dxf_path: str | Path,
        paso_mm: float = 1.0,
        z_guardado: float = 200.0,
        z_corte: float = 150.0,
        v_trans: float = 50.0,
        v_corte: float = 20.0,
        n_z_steps: int = 50,
        transit_accel_frac: float = 0.2,
        tol_topo: float = 0.05,
        simplify_tolerance: float = 0.01,
    ) -> None:
        self.dxf_path = Path(dxf_path)
        self.paso_mm = paso_mm
        self.z_guardado = z_guardado
        self.z_corte = z_corte
        self.v_trans = v_trans
        self.v_corte = v_corte
        self.n_z_steps = int(n_z_steps)
        self.transit_accel_frac = transit_accel_frac
        self.tol_topo = tol_topo
        self.simplify_tolerance = simplify_tolerance

        self._geoms: List[LineString] = []
        self._colors: List[int | Tuple[int, int, int]] = []
        self._geoms_corte: List[LineString] = []
        self._geoms_nocorte: List[LineString] = []
        self._merged_cut: List[LineString] = []
        self._rings_cut: List[LineString] = []
        self._open_cut: List[LineString] = []
        self._final_cut_seq: List[List[LineString]] = []
        self._traj_points: List[List[float]] = []  # [x,y,z,v,c] con NaN separadores
        self._visual_3d: List[List[float]] = []

    # -------------------- API pública --------------------
    def process(self) -> "DxfTrajectoryPlanner":
        """Ejecuta todo el flujo: leer, clasificar, unir, ordenar y generar trayectoria."""
        self._read_entities()
        self._split_by_color()
        self._merge_cut_geoms()
        self._build_cut_sequence()
        self._build_trajectory()
        return self

    def to_array(self, include_separators: bool = True, fill_nan: bool = False) -> np.ndarray:
        """Devuelve ndarray (N,5) con columnas X,Y,Z,V,C. C=1 corte, 0 tránsito. NaN separa cadenas."""
        if not self._traj_points:
            raise RuntimeError("Ejecuta process() antes de solicitar la trayectoria.")
        arr = np.array(self._traj_points, dtype=float)
        if fill_nan:
            arr = self._fill_nan_segments(arr)
        if include_separators and not fill_nan:
            return arr
        mask = ~np.isnan(arr).any(axis=1)
        return arr[mask]

    def export_txt(self, output_path: str | Path = "Trayectoria_final_3D.txt") -> Path:
        """Exporta la trayectoria a TXT con separadores NaN y bandera C."""
        arr = self.to_array(include_separators=True)
        out_path = Path(output_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            f.write("X Y Z V C\n")
            for row in arr:
                if np.isnan(row).any():
                    f.write("NaN NaN NaN NaN NaN\n")
                else:
                    f.write(
                        f"{row[0]:.6f} {row[1]:.6f} {row[2]:.6f} {row[3]:.6f} {row[4]:.0f}\n"
                    )
        return out_path

    def plot_2d(self, show: bool = True):
        """Plot 2D: verde = corte, amarillo = no corte."""
        if not self._geoms:
            raise RuntimeError("Ejecuta process() antes de graficar.")
        fig, ax = plt.subplots(figsize=(8, 8))
        for g in self._geoms_corte:
            x, y = g.xy
            ax.plot(x, y, color="#00ff00", linewidth=1.2)
        for g in self._geoms_nocorte:
            x, y = g.xy
            ax.plot(x, y, color="yellow", linewidth=2.2, linestyle="--")
        ax.set_aspect("equal", adjustable="box")
        ax.set_title("2D: Verde = corte | Amarillo = no corte")
        ax.grid(True)
        if show:
            plt.show()
        return fig, ax

    def plot_3d(self, show: bool = True):
        """Plot 3D de la trayectoria generada."""
        if not self._visual_3d:
            raise RuntimeError("Ejecuta process() antes de graficar.")
        fig = plt.figure(figsize=(10, 6))
        ax = fig.add_subplot(111, projection="3d")
        tp = np.array(self._visual_3d)
        if tp.size:
            ax.plot(tp[:, 0], tp[:, 1], tp[:, 2], linewidth=0.8)
        ax.set_xlabel("X (mm)")
        ax.set_ylabel("Y (mm)")
        ax.set_zlabel("Z (mm)")
        ax.set_title("Trayectoria 3D generada (mm)")
        if show:
            plt.show()
        return fig, ax

    # -------------------- Flujo interno --------------------
    def _read_entities(self) -> None:
        doc = ezdxf.readfile(self.dxf_path)
        msp = doc.modelspace()
        geoms: List[LineString] = []
        colors: List[int | Tuple[int, int, int]] = []
        for ent in msp:
            geom, color = self._entity_to_linestring(ent, doc)
            if geom is not None:
                geoms.append(geom)
                colors.append(color)
        if not geoms:
            raise ValueError("No se detectaron entidades validas en el DXF.")
        self._geoms = geoms
        self._colors = colors

    def _split_by_color(self) -> None:
        corte: List[LineString] = []
        nocorte: List[LineString] = []
        for g, c in zip(self._geoms, self._colors):
            if self._is_yellow(c):
                nocorte.append(g)
            else:
                corte.append(g)
        if not corte:
            raise ValueError("No hay entidades de corte (todas clasificadas como amarillo).")
        self._geoms_corte = corte
        self._geoms_nocorte = nocorte

    def _merge_cut_geoms(self) -> None:
        merged_list = self._unir_topologicamente(self._geoms_corte, self.tol_topo)
        self._merged_cut = merged_list
        self._rings_cut, self._open_cut = self._extract_rings_and_open(merged_list)

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
        sg_items = list(supergroups_cortar.items())
        sg_items.sort(key=lambda item: polys_cortar[item[0]].area if polys_cortar else 0)
        for _, members in sg_items:
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
        for r in sorted(remaining_rings, key=lambda c: c.length):
            supergroup_contours.append([r])

        open_groups = [[ln] for ln in sorted(self._open_cut, key=lambda l: l.length)]
        final_cut_sequence: List[List[LineString]] = []
        final_cut_sequence.extend(supergroup_contours)
        final_cut_sequence.extend(open_groups)
        self._final_cut_seq = final_cut_sequence

    def _build_trajectory(self) -> None:
        if not self._final_cut_seq:
            self._traj_points = []
            self._visual_3d = []
            return

        tray_pts: List[List[float]] = []
        visual_3d: List[List[float]] = []
        prev_guard_xy = None

        for group in self._final_cut_seq:
            for chain in group:
                pts_xy = self._resample_linestring(chain, paso_mm=self.paso_mm)
                if pts_xy.shape[0] < 2:
                    continue

                # Elegir orientación minimizando tránsito desde el anterior
                start_xy = pts_xy[0]
                end_xy = pts_xy[-1]
                if prev_guard_xy is None:
                    if np.linalg.norm(end_xy - np.array([0.0, 0.0])) < np.linalg.norm(
                        start_xy - np.array([0.0, 0.0])
                    ):
                        pts_xy = pts_xy[::-1]
                        start_xy = pts_xy[0]
                        end_xy = pts_xy[-1]
                else:
                    d_start = np.linalg.norm(prev_guard_xy - start_xy)
                    d_end = np.linalg.norm(prev_guard_xy - end_xy)
                    if d_end < d_start:
                        pts_xy = pts_xy[::-1]
                        start_xy = pts_xy[0]
                        end_xy = pts_xy[-1]

                # 1) Tránsito en Z_guardado desde prev_guard_xy a start_xy
                transit_xy = self._build_transit(prev_guard_xy, start_xy)
                v_trans_profile = self._perfil_trapezoidal(
                    dist=self._path_length(transit_xy),
                    v_max=self.v_trans,
                    frac_acc=self.transit_accel_frac,
                    steps=transit_xy.shape[0],
                )
                for p, vv in zip(transit_xy, v_trans_profile):
                    tray_pts.append([p[0], p[1], self.z_guardado, vv, 0.0])
                    visual_3d.append([p[0], p[1], self.z_guardado])

                # 2) Descenso vertical a Z_corte
                zs_desc = np.linspace(self.z_guardado, self.z_corte, self.n_z_steps)
                for z in zs_desc:
                    tray_pts.append([start_xy[0], start_xy[1], z, self.v_trans, 0.0])
                    visual_3d.append([start_xy[0], start_xy[1], z])

                # 3) Corte en XY a Z_corte con perfil suavizado
                v_cut_profile = self._perfil_s_curve(pts_xy.shape[0], self.v_corte)
                for p, vv in zip(pts_xy, v_cut_profile):
                    tray_pts.append([p[0], p[1], self.z_corte, float(vv), 1.0])
                    visual_3d.append([p[0], p[1], self.z_corte])

                # 4) Ascenso vertical a Z_guardado
                zs_asc = np.linspace(self.z_corte, self.z_guardado, self.n_z_steps)
                last_xy = pts_xy[-1]
                for z in zs_asc:
                    tray_pts.append([last_xy[0], last_xy[1], z, self.v_trans, 0.0])
                    visual_3d.append([last_xy[0], last_xy[1], z])

                # Separador
                tray_pts.append([math.nan, math.nan, math.nan, math.nan, math.nan])
                prev_guard_xy = np.array([last_xy[0], last_xy[1]])

        self._traj_points = tray_pts
        self._visual_3d = visual_3d

    # -------------------- Utilidades --------------------
    def _entity_to_linestring(
        self, ent, doc
    ) -> Tuple[LineString | None, int | Tuple[int, int, int]]:
        dtype = ent.dxftype()
        color = self._obtener_color_real(ent, doc)
        puntos: Iterable[Sequence[float]] | None = None
        try:
            if dtype == "LINE":
                s, e2 = ent.dxf.start, ent.dxf.end
                puntos = [[s.x, s.y], [e2.x, e2.y]]
            elif dtype == "LWPOLYLINE":
                puntos = np.array(ent.get_points())[:, :2]
            elif dtype == "POLYLINE":
                pts = [v.dxf.location[:2] for v in ent.vertices]
                puntos = np.array(puntos) if len(pts) == 0 else np.array(pts)
            elif dtype == "CIRCLE":
                c, r = ent.dxf.center, ent.dxf.radius
                t = np.linspace(0, 2 * np.pi, 200)
                puntos = np.column_stack([c.x + r * np.cos(t), c.y + r * np.sin(t)])
            elif dtype == "ARC":
                c, r = ent.dxf.center, ent.dxf.radius
                a1, a2 = np.deg2rad(ent.dxf.start_angle), np.deg2rad(ent.dxf.end_angle)
                t = np.linspace(a1, a2, 120)
                puntos = np.column_stack([c.x + r * np.cos(t), c.y + r * np.sin(t)])
            elif dtype == "SPLINE":
                fit = np.array(getattr(ent, "fit_points", []))
                if len(fit) >= 2:
                    tck, _ = splprep([fit[:, 0], fit[:, 1]], s=0)
                    u = np.linspace(0, 1, 200)
                    x, y = splev(u, tck)
                    puntos = np.column_stack([x, y])
                else:
                    ctrl = np.array(getattr(ent, "control_points", []))
                    if len(ctrl) >= 2:
                        tck, _ = splprep([ctrl[:, 0], ctrl[:, 1]], s=0)
                        u = np.linspace(0, 1, 200)
                        x, y = splev(u, tck)
                        puntos = np.column_stack([x, y])
        except Exception as exc:
            print(f"No se pudo procesar {dtype}: {exc}")
            return None, color

        if puntos is None:
            return None, color
        puntos_arr = np.array(puntos)
        if len(puntos_arr) < 2:
            return None, color
        return LineString(puntos_arr), color

    @staticmethod
    def _unir_topologicamente(
        geoms: List[LineString], tolerancia: float
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
                if ext.length > 1e-6:
                    rings.append(ext)
            except Exception:
                pass
            for hole in p.interiors:
                try:
                    h = LineString(hole.coords)
                    if h.length > 1e-6:
                        rings.append(h)
                except Exception:
                    pass
        for g in merged_list:
            try:
                coords = list(g.coords)
                if len(coords) >= 4 and (np.allclose(coords[0], coords[-1]) or g.is_ring):
                    if g.length > 1e-6:
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
        bounds = [polys[i].bounds for i in range(n)]
        idx_by_area = sorted(range(n), key=lambda i: areas[i])
        for i in range(n):
            candidates: List[Tuple[float, int]] = []
            rep = reps[i]
            rx, ry = rep.x, rep.y
            area_i = areas[i]
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

    @staticmethod
    def _obtener_color_real(ent, doc) -> int | Tuple[int, int, int]:
        """Devuelve color ACI (int) o truecolor (tuple) si está presente, o color de la capa."""
        try:
            if hasattr(ent.dxf, "true_color") and ent.dxf.get("true_color", None):
                rgb = ent.rgb
                if rgb is not None:
                    return tuple(rgb)
            color_index = int(getattr(ent.dxf, "color", 7))
            if color_index <= 0 or color_index == 256:
                layer = ent.dxf.layer
                layer_color_index = int(doc.layers.get(layer).color)
                return layer_color_index
            return color_index
        except Exception:
            return 7

    @staticmethod
    def _is_yellow(c) -> bool:
        if isinstance(c, (tuple, list)):
            r, g, b = c
            return r >= 200 and g >= 200 and b <= 120
        try:
            return int(c) == 2
        except Exception:
            return False

    @staticmethod
    def _resample_linestring(ls: LineString, paso_mm: float = 1.0) -> np.ndarray:
        pts = np.array(ls.coords)
        segs = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        if segs.sum() == 0:
            return pts
        s = np.concatenate(([0.0], np.cumsum(segs)))
        s_new = np.arange(0, s[-1] + 1e-9, paso_mm)
        xs = np.interp(s_new, s, pts[:, 0])
        ys = np.interp(s_new, s, pts[:, 1])
        return np.vstack([xs, ys]).T

    @staticmethod
    def _path_length(points: np.ndarray) -> float:
        if points.shape[0] < 2:
            return 0.0
        return float(np.sum(np.linalg.norm(np.diff(points, axis=0), axis=1)))

    def _build_transit(self, prev_xy, start_xy) -> np.ndarray:
        if prev_xy is None:
            return np.array([start_xy])
        dist_transit = np.linalg.norm(start_xy - prev_xy)
        n_steps = max(2, int(np.ceil(dist_transit / self.paso_mm)))
        xs = np.linspace(prev_xy[0], start_xy[0], n_steps)
        ys = np.linspace(prev_xy[1], start_xy[1], n_steps)
        return np.column_stack([xs, ys])

    def _perfil_trapezoidal(
        self, dist: float, v_max: float, frac_acc: float, steps: int
    ) -> np.ndarray:
        steps = max(2, steps)
        t = np.linspace(0, 1, steps)
        acc_t = frac_acc
        dec_t = 1 - frac_acc

        def piece(ti: float) -> float:
            if ti < acc_t:
                return v_max * (ti / acc_t)
            if ti > dec_t:
                return v_max * (1 - (ti - dec_t) / (1 - dec_t))
            return v_max

        vec = np.array([piece(float(ti)) for ti in t], dtype=float)
        return vec

    def _perfil_s_curve(self, steps: int, v_max: float) -> np.ndarray:
        t = np.linspace(0, 1, max(2, steps))
        return v_max * (0.5 - 0.5 * np.cos(np.pi * t))

    def _fill_nan_segments(self, arr: np.ndarray) -> np.ndarray:
        """Interpola NaN entre cadenas en XY a Z_guardado con perfil trapezoidal (C=0)."""
        if not np.isnan(arr).any():
            return arr
        rows: List[List[float]] = []
        i = 0
        n = arr.shape[0]
        while i < n:
            row = arr[i]
            if not np.isnan(row).any():
                rows.append(row.tolist())
                i += 1
                continue
            # buscar siguiente no-NaN
            j = i + 1
            while j < n and np.isnan(arr[j]).any():
                j += 1
            if rows and j < n:
                prev_xy = np.array(rows[-1][:2])
                next_xy = arr[j][:2]
                transit_xy = self._build_transit(prev_xy, next_xy)
                v_profile = self._perfil_trapezoidal(
                    dist=self._path_length(transit_xy),
                    v_max=self.v_trans,
                    frac_acc=self.transit_accel_frac,
                    steps=transit_xy.shape[0],
                )
                for p, vv in zip(transit_xy, v_profile):
                    rows.append([p[0], p[1], self.z_guardado, vv, 0.0])
            i = j
        return np.array(rows, dtype=float)


if __name__ == "__main__":
    # Ajusta esta ruta a un DXF existente
    demo_path_load = Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\dxf_files\logo7_especial.dxf")
    demo_path_out = Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\trayectorias\logo7_especial_3d.txt")
    
    if not demo_path_load.is_file():
        raise FileNotFoundError(f"DXF no encontrado en {demo_path_load}")

    planner = DxfTrajectoryPlanner(
        dxf_path=demo_path_load,
        paso_mm=0.2,
        z_guardado=200.0,
        z_corte=150.0,
        v_trans=50.0,
        v_corte=20.0,
        n_z_steps=50,
        transit_accel_frac=0.2,
    ).process()

    arr = planner.to_array()
    print("Muestra de trayectoria:\n", arr[:5])

    out_txt = planner.export_txt(demo_path_out)
    print(f"Exportado: {out_txt}")

    planner.plot_2d(show=True)
    planner.plot_3d(show=True)
