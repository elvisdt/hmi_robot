"""
Visualizador 3D para trayectorias exportadas (X Y Z V C).
Colorea corte (C=1) en rojo y no-corte (C=0) en verde, con animación punto a punto.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import List

import matplotlib.pyplot as plt
import numpy as np
from matplotlib import animation
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401 - needed for 3D plot


def load_segments(txt_path: Path) -> List[np.ndarray]:
    """Lee el archivo y devuelve segmentos (sin NaN) preservando la columna C."""
    data = np.genfromtxt(txt_path, skip_header=1, dtype=float)
    segments: List[np.ndarray] = []
    if data.ndim == 1 and data.size == 0:
        return segments

    is_nan = np.isnan(data).any(axis=1)
    start = 0
    for idx in range(len(is_nan) + 1):
        end = idx
        if idx == len(is_nan) or is_nan[idx]:
            if end - start > 0:
                seg = data[start:end]
                segments.append(seg)
            start = idx + 1
    return segments


def plot_segments(
    segments: List[np.ndarray],
    show: bool = True,
    animate: bool = True,
    interval_ms: int = 50,
):
    """Grafica segmentos 3D con colores por bandera C. Animación opcional punto a punto."""
    fig = plt.figure(figsize=(10, 6))
    ax = fig.add_subplot(111, projection="3d")

    flat_points = []
    flat_colors: List[str] = []

    for seg in segments:
        if seg.size == 0:
            continue
        coords = seg[:, :3]
        cs = seg[:, 4]
        # Pintar tramos con mismo C
        start = 0
        for i in range(1, len(cs) + 1):
            change = i == len(cs) or cs[i] != cs[i - 1]
            if change:
                sub = coords[start:i]
                c_val = cs[start]
                color = "#ff0000" if c_val >= 0.5 else "#00aa00"
                ax.plot(sub[:, 0], sub[:, 1], sub[:, 2], color=color, linewidth=0.8, alpha=0.4)
                start = i
        flat_points.append(coords)
        flat_colors.extend("#ff0000" if c >= 0.5 else "#00aa00" for c in cs)

    flat = np.vstack(flat_points) if flat_points else np.empty((0, 3))
    scatter = ax.scatter([], [], [], s=20)
    anim = None

    def init():
        scatter._offsets3d = ([], [], [])
        return (scatter,)

    def update(frame):
        if flat.size == 0:
            return (scatter,)
        p = flat[frame]
        scatter._offsets3d = ([p[0]], [p[1]], [p[2]])
        scatter.set_color(flat_colors[frame])
        return (scatter,)

    ax.set_xlabel("X")
    ax.set_ylabel("Y")
    ax.set_zlabel("Z")
    ax.set_title("Simulación 3D de trayectoria (rojo=corte, verde=no-corte)")

    # Ajuste de aspecto básico
    try:
        xs = np.concatenate([s[:, 0] for s in segments if s.size])
        ys = np.concatenate([s[:, 1] for s in segments if s.size])
        zs = np.concatenate([s[:, 2] for s in segments if s.size])
        minx, maxx = xs.min(), xs.max()
        miny, maxy = ys.min(), ys.max()
        minz, maxz = zs.min(), zs.max()
        max_range = max(maxx - minx, maxy - miny, maxz - minz) or 1.0
        midx = (maxx + minx) / 2
        midy = (maxy + miny) / 2
        midz = (maxz + minz) / 2
        ax.set_xlim(midx - max_range / 2, midx + max_range / 2)
        ax.set_ylim(midy - max_range / 2, midy + max_range / 2)
        ax.set_zlim(midz - max_range / 2, midz + max_range / 2)
    except Exception:
        pass

    if animate and flat.size:
        frames = flat.shape[0]
        anim = animation.FuncAnimation(
            fig, update, init_func=init, frames=frames, interval=interval_ms, blit=False
        )

    if show:
        plt.show()
    return fig, ax, anim


def main():
    default_path = Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\trayectorias\logo7_especial_3d.txt")

    parser = argparse.ArgumentParser(description="Visualizador 3D de trayectorias exportadas.")
    parser.add_argument(
        "archivo",
        type=str,
        nargs="?",
        default=str(default_path),
        help="Ruta del TXT con columnas X Y Z V C (por defecto: archivo demo).",
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=50,
        help="Intervalo de animación en ms (punto a punto).",
    )
    args = parser.parse_args()
    txt_path = Path(args.archivo)
    if not txt_path.is_file():
        raise FileNotFoundError(f"No se encontró el archivo: {txt_path}")

    segments = load_segments(txt_path)
    if not segments:
        print("No se detectaron segmentos válidos.")
        return
    _, _, anim = plot_segments(segments, show=True, animate=True, interval_ms=args.interval)
    # evitar que se libere la animacion antes de mostrar/guardar
    _ = anim


if __name__ == "__main__":
    main()
