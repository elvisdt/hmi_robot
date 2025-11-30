"""
Conversor robusto DXF -> trayectorias (DBSCAN) basado en conversor_ori.ipynb.
Incluye interfaz orientada a objetos, exportacion a DataFrame y TXT.
"""

from __future__ import annotations

from pathlib import Path
from typing import Iterable, List, Sequence

import ezdxf
import matplotlib.pyplot as plt
import numpy as np
from scipy.interpolate import splev, splprep
from shapely.geometry import LineString, MultiLineString
from shapely.ops import linemerge, unary_union
from sklearn.cluster import DBSCAN


class RobustDxfConverter:
    """Pipeline para leer un DXF, unir extremos con DBSCAN y exportar trayectorias."""

    def __init__(self, dxf_path: str | Path, endpoint_tolerance: float = 0.05) -> None:
        self.dxf_path = Path(dxf_path)
        self.endpoint_tolerance = endpoint_tolerance
        self._raw_geoms: List[LineString] = []
        self._merged: List[LineString] = []

    def process(self) -> "RobustDxfConverter":
        """Ejecuta el flujo completo."""
        self._read_dxf()
        self._cluster_endpoints()
        self._merge_lines()
        return self

    def to_array(self, include_breaks: bool = True) -> np.ndarray:
        """Devuelve un ndarray (N, 3) con columnas trayectoria, X, Y."""
        self._require_merged()
        rows = [(t, x, y) for t, x, y in self._iter_rows(include_breaks)]
        return np.array(rows, dtype=float)

    def to_dataframe(self, include_breaks: bool = True):
        """Devuelve un DataFrame con columnas trayectoria, X, Y (requiere pandas)."""
        try:
            import pandas as pd  # type: ignore
        except Exception as exc:  # pragma: no cover - fallback para entornos sin pandas
            raise ImportError("Instala pandas para usar to_dataframe()") from exc

        rows = [
            {"trayectoria": t, "X": x, "Y": y}
            for t, x, y in self._iter_rows(include_breaks)
        ]
        return pd.DataFrame(rows, columns=["trayectoria", "X", "Y"])

    def export_txt(self, output_path: str | Path | None = None) -> Path:
        """Exporta la trayectoria a TXT (X Y + separadores NaN)."""
        self._require_merged()
        out_path = (
            Path(output_path)
            if output_path is not None
            else self.dxf_path.with_name("trayectoria_XY_robusta.txt")
        )
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            f.write("X Y\n")
            for geom in self._merged:
                x, y = geom.xy
                for xi, yi in zip(x, y):
                    f.write(f"{xi:.6f} {yi:.6f}\n")
                f.write("NaN NaN\n")
        return out_path

    def plot(self, show: bool = True):
        """Grafica las trayectorias resultantes."""
        self._require_merged()
        fig, ax = plt.subplots(figsize=(8, 8))
        for idx, geom in enumerate(self._merged, start=1):
            x, y = geom.xy
            ax.plot(x, y, linewidth=1.2, label=f"Trayectoria {idx}")
        ax.set_aspect("equal", adjustable="box")
        ax.set_title("Figura reconstruida (DBSCAN robusto)")
        ax.set_xlabel("X [mm]")
        ax.set_ylabel("Y [mm]")
        ax.grid(True)
        ax.legend()
        if show:
            plt.show()
        return fig, ax

    def _read_dxf(self) -> None:
        doc = ezdxf.readfile(self.dxf_path)
        msp = doc.modelspace()
        geoms: List[LineString] = []
        for e in msp:
            geom = self._entity_to_linestring(e)
            if geom is not None:
                geoms.append(geom)
        if not geoms:
            raise ValueError("No se detectaron entidades validas en el DXF.")
        self._raw_geoms = geoms

    def _cluster_endpoints(self) -> None:
        if not self._raw_geoms:
            raise ValueError("No hay geometria cargada para agrupar endpoints.")

        endpoints = []
        for geom in self._raw_geoms:
            coords = list(geom.coords)
            endpoints.append(coords[0])
            endpoints.append(coords[-1])

        endpoints_arr = np.array(endpoints)
        cl = DBSCAN(eps=self.endpoint_tolerance, min_samples=1, metric="euclidean")
        labels = cl.fit_predict(endpoints_arr)
        n_clusters = labels.max() + 1

        centroids = np.zeros((n_clusters, 2))
        for k in range(n_clusters):
            pts = endpoints_arr[labels == k]
            centroids[k] = pts.mean(axis=0)

        geoms_sanitized: List[LineString] = []
        for gi, geom in enumerate(self._raw_geoms):
            coords = list(geom.coords)
            label_start = labels[2 * gi]
            label_end = labels[2 * gi + 1]
            coords[0] = tuple(centroids[label_start])
            coords[-1] = tuple(centroids[label_end])
            geoms_sanitized.append(LineString(coords))

        self._raw_geoms = geoms_sanitized

    def _merge_lines(self) -> None:
        union = unary_union(self._raw_geoms)
        merged = linemerge(union)
        if isinstance(merged, LineString):
            merged_list = [merged]
        elif isinstance(merged, MultiLineString):
            merged_list = list(merged.geoms)
        else:
            merged_list = []
        self._merged = merged_list

    @staticmethod
    def _entity_to_linestring(e) -> LineString | None:
        dtype = e.dxftype()
        puntos: Iterable[Sequence[float]] | None = None
        try:
            if dtype == "LINE":
                start, end = e.dxf.start, e.dxf.end
                puntos = [[start.x, start.y], [end.x, end.y]]
            elif dtype == "LWPOLYLINE":
                puntos = np.array(e.get_points())[:, :2]
            elif dtype == "POLYLINE":
                pts = [v.dxf.location[:2] for v in e.vertices]
                puntos = np.array(pts)
            elif dtype == "CIRCLE":
                c, r = e.dxf.center, e.dxf.radius
                t = np.linspace(0, 2 * np.pi, 200)
                puntos = np.column_stack([c.x + r * np.cos(t), c.y + r * np.sin(t)])
            elif dtype == "ARC":
                c, r = e.dxf.center, e.dxf.radius
                a1, a2 = np.deg2rad(e.dxf.start_angle), np.deg2rad(e.dxf.end_angle)
                t = np.linspace(a1, a2, 120)
                puntos = np.column_stack([c.x + r * np.cos(t), c.y + r * np.sin(t)])
            elif dtype == "SPLINE":
                fit = np.array(getattr(e, "fit_points", []))
                if len(fit) >= 2:
                    tck, _ = splprep([fit[:, 0], fit[:, 1]], s=0)
                    u = np.linspace(0, 1, 200)
                    x, y = splev(u, tck)
                    puntos = np.column_stack([x, y])
                else:
                    ctrl = np.array(getattr(e, "control_points", []))
                    if len(ctrl) >= 2:
                        tck, _ = splprep([ctrl[:, 0], ctrl[:, 1]], s=0)
                        u = np.linspace(0, 1, 200)
                        x, y = splev(u, tck)
                        puntos = np.column_stack([x, y])
        except Exception as exc:
            print(f"No se pudo procesar {dtype}: {exc}")
            return None

        if puntos is None:
            return None
        puntos_arr = np.array(puntos)
        if len(puntos_arr) < 2:
            return None
        return LineString(puntos_arr)

    def _iter_rows(self, include_breaks: bool):
        """Generador comun para exportar trayectorias."""
        for idx, geom in enumerate(self._merged, start=1):
            x, y = geom.xy
            for xi, yi in zip(x, y):
                yield idx, xi, yi
            if include_breaks:
                yield idx, np.nan, np.nan

    def _require_merged(self) -> None:
        if not self._merged:
            raise RuntimeError("Ejecuta process() antes de acceder a las trayectorias.")


if __name__ == "__main__":
    # Ajusta esta ruta a un DXF existente en tu entorno
    
    demo_path_load = Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\dxf_files\corte_especial.dxf")
    demo_path_out = Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\trayectorias\corte_especial.txt")
    
    
    if not demo_path_load.is_file():
        raise FileNotFoundError(
            f"No se encontró el DXF de demo en {demo_path_load}. "
            "Actualiza la ruta a tu archivo DXF."
        )

    converter = RobustDxfConverter(demo_path_load, endpoint_tolerance=0.05).process()

    try:
        df_trayectoria = converter.to_dataframe()
        print(df_trayectoria.head())
    except ImportError:
        arr_trayectoria = converter.to_array()
        print(arr_trayectoria[:5])

    # export file
    converter.export_txt(demo_path_out)
    converter.plot()
