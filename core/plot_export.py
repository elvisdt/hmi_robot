"""
Pequeño helper para visualizar el archivo TXT/CSV exportado y validar
que coincide con el gráfico de dxf_converter.plot.
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path
from typing import List, Tuple

import matplotlib.pyplot as plt


def _parse_line(raw: str) -> Tuple[float, float, float, int] | None:
    raw = raw.strip()
    if not raw or raw.startswith("#"):
        return None
    # Soporta separadores coma o espacios
    parts = [p for p in raw.replace(",", " ").split() if p]
    if len(parts) < 2:
        return None
    try:
        x = float(parts[0])
        y = float(parts[1])
        z = float(parts[2]) if len(parts) > 2 else 0.0
        flag = int(float(parts[3])) if len(parts) > 3 else 0
    except Exception:
        return None
    # Trata NaN como separador de polilíneas
    if any(math.isnan(v) for v in (x, y, z)):
        return None
    return (x, y, z, flag)


def load_segments(file_path: Path) -> List[Tuple[List[float], List[float], int]]:
    """Devuelve lista de segmentos (xs, ys, flag)."""
    text = file_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    segs: List[Tuple[List[float], List[float], int]] = []
    cur_x: List[float] = []
    cur_y: List[float] = []
    cur_flag = 0
    for line in text:
        parsed = _parse_line(line)
        if parsed is None:
            if cur_x and cur_y:
                segs.append((cur_x, cur_y, cur_flag))
            cur_x, cur_y = [], []
            cur_flag = 0
            continue
        x, y, _z, flag = parsed
        cur_x.append(x)
        cur_y.append(y)
        cur_flag = flag
    if cur_x and cur_y:
        segs.append((cur_x, cur_y, cur_flag))
    return segs


def plot_file(file_path: Path, save_path: Path | None = None) -> None:
    segs = load_segments(file_path)
    if not segs:
        print("No se encontraron puntos para trazar.")
        return
    fig, ax = plt.subplots(figsize=(9, 5))
    for xs, ys, flag in segs:
        color = "g" if flag == 1 else "orange"
        ax.fill(xs, ys, color=color, alpha=0.25)
        ax.plot(xs, ys, color=color, lw=1.5 if flag == 1 else 1.0)
    ax.set_aspect("equal", adjustable="box")
    ax.set_xlabel("X (mm)")
    ax.set_ylabel("Y (mm)")
    ax.grid(True)
    ax.set_title(file_path.name)
    ax.autoscale(True)
    if save_path:
        fig.savefig(save_path, dpi=200, bbox_inches="tight")
        print(f"Guardado en {save_path}")
    else:
        plt.show()


def main() -> None:
    parser = argparse.ArgumentParser(description="Graficar TXT/CSV exportado para validación rápida.")
    parser.add_argument(
        "file",
        type=str,
        nargs="?",
        default=str(DEFAULT_EXPORT_PATH),
        help=f"Ruta al TXT/CSV exportado (X,Y[,Z,C]). Por defecto: {DEFAULT_EXPORT_PATH}",
    )
    parser.add_argument("--save", type=str, default=None, help="Ruta opcional para guardar PNG.")
    args = parser.parse_args()
    file_path = Path(args.file)
    if not file_path.exists():
        raise SystemExit(f"No existe el archivo: {file_path}")
    save_path = Path(args.save) if args.save else None
    plot_file(file_path, save_path)


DEFAULT_EXPORT_PATH = Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\trayectorias\UPC-30_ESPECIAL_3D.csv")
if __name__ == "__main__":
    main()

