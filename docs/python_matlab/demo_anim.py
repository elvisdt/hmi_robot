"""
Demo rapido de pipeline y animacion SCARA con datos sinteticos.
Usa los modulos portados desde MATLAB.
"""

from __future__ import annotations
from pathlib import Path
import argparse
import numpy as np

try:
    # Ejecutado como modulo: python -m docs.python_matlab.demo_anim
    from . import (
        animar_trayectoria,
        cinematica_inversa,
        diferenciar_trayectoria_articular,
        interpolar_trayectoria,
        leer_trayectoria,
        planificar_trayectoria,
    )
except ImportError:
    # Ejecutado directo: python docs/python_matlab/demo_anim.py
    import sys
    from pathlib import Path

    pkg_root = Path(__file__).resolve().parent
    sys.path.append(str(pkg_root.parent))
    from python_matlab import (  # type: ignore
        animar_trayectoria,
        cinematica_inversa,
        diferenciar_trayectoria_articular,
        interpolar_trayectoria,
        leer_trayectoria,
        planificar_trayectoria,
    )


def build_demo_cart() -> list[np.ndarray]:
    """Genera una trayectoria cartesiana sintetica con un cuadrado de corte."""
    # cuadrado en el plano z_cut con FLAG=1 (corte)
    square = np.array(
        [
            [0.2, 0.2, 0.15, 1],
            [0.4, 0.2, 0.15, 1],
            [0.4, 0.4, 0.15, 1],
            [0.2, 0.4, 0.15, 1],
            [0.2, 0.2, 0.15, 1],
        ],
        dtype=float,
    )
    return [square]


def main():
    parser = argparse.ArgumentParser(description="Demo de animacion SCARA con trayectoria sintetica.")
    parser.add_argument(
        "--file",
        type=str,
        default=str(
            Path(r"D:\ELVIS\PYTHON\RoboticHMI\docs\trayectorias\TrayectoriaScaraCnc_Ordenada.txt")
        ),
        help="Ruta a TXT/CSV con columnas X Y Z C (por defecto: trayectoria de demo exportada).",
    )
    parser.add_argument("--paso", type=float, default=1.0, help="Paso de interpolacion (mm)")
    parser.add_argument("--z_home", type=float, default=0.25, help="Z home (m)")
    parser.add_argument("--z_cut", type=float, default=0.15, help="Z de corte (m)")
    parser.add_argument("--speed_cut", type=float, default=5000.0, help="Velocidad de corte (mm/min)")
    parser.add_argument("--speed_travel", type=float, default=15000.0, help="Velocidad de traslado (mm/min)")
    parser.add_argument("--L1", type=float, default=0.5, help="Longitud brazo 1 (m)")
    parser.add_argument("--L2", type=float, default=0.45, help="Longitud brazo 2 (m)")
    parser.add_argument("--fs", type=float, default=200.0, help="Frecuencia de muestreo para diferenciacion (Hz)")
    parser.add_argument("--no-anim", action="store_true", help="No mostrar animacion (solo probar pipeline)")
    args = parser.parse_args()

    if args.file:
        grupos = leer_trayectoria(args.file)
    else:
        grupos = build_demo_cart()
    tray_int = interpolar_trayectoria(grupos, paso=args.paso, z_cut=args.z_cut)
    tray_plan = planificar_trayectoria(
        tray_int,
        z_home=args.z_home,
        z_cut=args.z_cut,
        paso=args.paso,
        speed_cut=args.speed_cut,
        speed_traslado=args.speed_travel,
    )

    # Cinematica inversa (usa flags/vel en columnas 3 y 4 de tray_plan)
    tray_cart_pos = tray_plan[:, 0:3]
    tray_cart_aux = tray_plan[:, 3:5]
    tray_art = cinematica_inversa(tray_cart_pos, args.L1, args.L2, tray_cart_aux)

    Q_dot, Q_ddot, tiempos = diferenciar_trayectoria_articular(
        tray_art, paso=args.paso, Fs=args.fs
    )

    print(f"Puntos cart (plan): {tray_plan.shape[0]}")
    print(f"Puntos articulares: {tray_art.shape[0]}")
    print(f"Tiempo total simulado: {tiempos[-1]:.3f} s")
    print(f"Q_dot max: {np.max(np.abs(Q_dot), axis=0)}")
    print(f"Q_ddot max: {np.max(np.abs(Q_ddot), axis=0)}")

    if not args.no_anim:
        animar_trayectoria(tray_art, args.L1, args.L2, tiempos, speedup=1.0, show=True)


if __name__ == "__main__":
    main()
