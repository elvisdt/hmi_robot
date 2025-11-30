"""
Conversor DXF -> TXT/CSV (topologia + color + area), version OOP.
Clasifica por color/layer, une topologicamente, polygonize y exporta con bandera de corte.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

import ezdxf
import matplotlib.pyplot as plt
import numpy as np
from scipy.interpolate import splev, splprep
from shapely.geometry import LineString, MultiLineString, Polygon
from shapely.ops import linemerge, polygonize, unary_union
from sklearn.cluster import DBSCAN


class DxfTopologyConverter:
    def __init__(self, dxf_path: str | Path, tol_topo: float = 0.05) -> None:
        self.dxf_path = Path(dxf_path)
        self.tol_topo = tol_topo
        self._geoms_raw: List[dict] = []
        self._geoms_cortar: List[LineString] = []
        self._geoms_nocortar: List[LineString] = []
        self._polys_cut: List[Polygon] = []
        self._opens_cut: List[LineString] = []
        self._polys_nocut: List[Polygon] = []
        self._opens_nocut: List[LineString] = []
        self._geoms_final: List[Tuple[LineString | Polygon, int]] = []

    def process(self) -> "DxfTopologyConverter":
        self._read_dxf()
        self._split_by_color()
        self._process_categories()
        self._build_final_order()
        return self

    def export_txt(self, out_path: str | Path) -> Path:
        out_path = Path(out_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            f.write("X Y Z CORTAR\n")
            for i, (geom, flag) in enumerate(self._geoms_final):
                x, y = self._coords_no_close(geom)
                for xi, yi in zip(x, y):
                    f.write(f"{xi:.6f} {yi:.6f} 0.000 {flag}\n")
                if i < len(self._geoms_final) - 1:
                    f.write("NaN NaN NaN NaN\n")
        print(f"Exportado TXT: {out_path}")
        return out_path

    def export_csv(self, out_path: str | Path) -> Path:
        out_path = Path(out_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            f.write("X,Y,Z,C\n")
            for i, (geom, flag) in enumerate(self._geoms_final):
                x, y = self._coords_no_close(geom)
                for xi, yi in zip(x, y):
                    f.write(f"{xi:.6f},{yi:.6f},0.000,{flag}\n")
                if i < len(self._geoms_final) - 1:
                    f.write("NaN,NaN,NaN,NaN\n")
        print(f"Exportado CSV: {out_path}")
        return out_path

    def plot(self, show: bool = True):
        fig, ax = plt.subplots(figsize=(9, 9))
        for p in self._polys_cut:
            x, y = p.exterior.xy
            ax.fill(x, y, "g", alpha=0.3)
            ax.plot(x, y, "k-", lw=0.6)
        for g in self._opens_cut:
            x, y = g.xy
            ax.plot(x, y, "g-", lw=2)
        for p in self._polys_nocut:
            x, y = p.exterior.xy
            ax.fill(x, y, "y", alpha=0.3)
            ax.plot(x, y, "r--", lw=1)
        for g in self._opens_nocut:
            x, y = g.xy
            ax.plot(x, y, "y--", lw=1)
        ax.set_aspect("equal", adjustable="box")
        ax.grid(True)
        ax.set_title("Topologia reconstruida")
        if show:
            plt.show()
        return fig, ax

    # Interno
    def _read_dxf(self) -> None:
        if not self.dxf_path.is_file():
            raise FileNotFoundError(f"No se encontro el DXF: {self.dxf_path}")
        doc = ezdxf.readfile(self.dxf_path)
        msp = doc.modelspace()
        geoms_raw: List[dict] = []
        for e in msp:
            g = self._entity_to_linestring(e)
            if g is not None:
                geoms_raw.append(g)
        if not geoms_raw:
            raise ValueError("No se detectaron entidades validas en el DXF.")
        self._geoms_raw = geoms_raw

    def _split_by_color(self) -> None:
        corte: List[LineString] = []
        nocorte: List[LineString] = []
        for g in self._geoms_raw:
            if self._clasificar_color(g["color"], g["layer"]) == "NO_CORTAR":
                nocorte.append(g["geom"])
            else:
                corte.append(g["geom"])
        self._geoms_cortar = corte
        self._geoms_nocortar = nocorte

    def _process_categories(self) -> None:
        self._polys_cut, self._opens_cut = self._process_category(self._geoms_cortar)
        self._polys_nocut, self._opens_nocut = self._process_category(self._geoms_nocortar)

    def _build_final_order(self) -> None:
        polys_sorted = sorted(self._polys_cut, key=lambda p: abs(p.area))
        geoms_final: List[Tuple[LineString | Polygon, int]] = []
        geoms_final.extend((g, 1) for g in polys_sorted)
        geoms_final.extend((g, 1) for g in self._opens_cut)
        geoms_final.extend((g, 0) for g in self._polys_nocut)
        geoms_final.extend((g, 0) for g in self._opens_nocut)
        self._geoms_final = self._reordenar_por_distancia(geoms_final)

    # Helpers
    @staticmethod
    def _entity_to_linestring(e) -> dict | None:
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

    @staticmethod
    def _clasificar_color(color, layer: str) -> str:
        try:
            if color is not None and int(color) == 2:
                return "NO_CORTAR"
        except Exception:
            pass
        if "NO" in layer.upper():
            return "NO_CORTAR"
        return "CORTAR"

    def _process_category(self, geoms: List[LineString]) -> Tuple[List[Polygon], List[LineString]]:
        merged = self._merge_and_snap(geoms, self.tol_topo)
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

    @staticmethod
    def _merge_and_snap(geoms: List[LineString], tol: float) -> List[LineString]:
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

    @staticmethod
    def _coords_no_close(geom: LineString | Polygon):
        if isinstance(geom, Polygon):
            x, y = geom.exterior.xy
            return x[:-1], y[:-1]
        return geom.xy

    @staticmethod
    def _centro_geom(geom: LineString | Polygon) -> Tuple[float, float]:
        c = geom.centroid
        try:
            return (float(c.x), float(c.y))
        except Exception:
            return (0.0, 0.0)

    def _reordenar_por_distancia(
        self, geoms: List[Tuple[LineString | Polygon, int]]
    ) -> List[Tuple[LineString | Polygon, int]]:
        if not geoms:
            return geoms
        remaining = geoms.copy()
        ordered: List[Tuple[LineString | Polygon, int]] = []
        remaining.sort(key=lambda g: np.hypot(*self._centro_geom(g[0])))
        current_geom, current_flag = remaining.pop(0)
        ordered.append((current_geom, current_flag))
        while remaining:
            cur_cx, cur_cy = self._centro_geom(current_geom)
            nxt_idx, nxt_item = min(
                enumerate(remaining),
                key=lambda item: np.hypot(
                    self._centro_geom(item[1][0])[0] - cur_cx,
                    self._centro_geom(item[1][0])[1] - cur_cy,
                ),
            )
            current_geom, current_flag = nxt_item
            ordered.append((current_geom, current_flag))
            remaining.pop(nxt_idx)
        return ordered


def main():
    parser = argparse.ArgumentParser(description="Conversor DXF -> TXT/CSV (topologia + color + area)")
    parser.add_argument(
        "dxf",
        type=str,
        nargs="?",
        default=str(Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\dxf_files\UPC-30_ESPECIAL.dxf")),
        help="Ruta del DXF (por defecto: UPC-30_ESPECIAL.dxf)",
    )
    parser.add_argument(
        "--tol",
        type=float,
        default=0.05,
        help="Tolerancia para unir extremos (DBSCAN), en mm",
    )
    parser.add_argument(
        "--out",
        type=str,
        default=str(Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\trayectorias\UPC-30_ESPECIAL_3D.txt")),
        help="Ruta de salida del TXT (CSV se generara con misma ruta y extension .csv)",
    )
    args = parser.parse_args()
    converter = DxfTopologyConverter(args.dxf, tol_topo=args.tol).process()
    txt_path = Path(args.out)
    converter.export_txt(txt_path)
    converter.export_csv(txt_path.with_suffix(".csv"))
    converter.plot(show=True)


if __name__ == "__main__":
    main()
