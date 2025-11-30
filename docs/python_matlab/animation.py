from __future__ import annotations

from typing import Optional

import matplotlib.pyplot as plt
import numpy as np
from matplotlib import animation

from .kinematics import cinematica_directa


def animar_trayectoria(
    tray_art: np.ndarray,
    L1: float,
    L2: float,
    tiempos: np.ndarray,
    speedup: float = 1.0,
    show: bool = True,
    interval_target_hz: float = 25.0,
) -> tuple[plt.Figure, plt.Axes, Optional[animation.FuncAnimation]]:
    """
    Anima trayectoria articular [d1 th2 th3 flag V] en 3D.
    FLAG: 1 corte (amarillo), 2/3 traslado (blanco).
    tiempos: vector acumulado en segundos.
    """
    if tray_art.ndim != 2 or tray_art.shape[1] < 5:
        raise ValueError("tray_art debe ser Nx5 [d1 th2 th3 flag V]")
    num_puntos = tray_art.shape[0]
    fig = plt.figure(figsize=(8, 6))
    ax = fig.add_subplot(111, projection="3d")
    ax.set_xlim(-0.3, 1.0)
    ax.set_ylim(-0.3, 1.0)
    ax.set_zlim(0.0, 0.3)
    ax.set_xlabel("X (m)")
    ax.set_ylabel("Y (m)")
    ax.set_zlabel("Z (m)")
    ax.set_title(f"Animación SCARA (x{speedup:.1f})")
    ax.view_init(elev=30, azim=45)
    h_prism, = ax.plot([], [], [], color=[0.5, 0.5, 0.5], linewidth=6)
    h_brazo1, = ax.plot([], [], [], color=[0, 0, 1], linewidth=4)
    h_brazo2, = ax.plot([], [], [], color=[0, 1, 0], linewidth=4)
    h_eff, = ax.plot([], [], [], "o", markersize=9, markerfacecolor="r", markeredgecolor="r")
    h_tray_corte, = ax.plot([], [], [], "y-", linewidth=1.5, label="Corte")
    h_tray_tras, = ax.plot([], [], [], "w--", linewidth=1.0, label="Traslado")
    ax.legend(loc="best")

    tray_corte = []
    tray_tras = []
    flag_anterior = tray_art[0, 3]

    # determinar salto de frames para target Hz
    Fs_sim = 500.0
    skip_rate = max(1, int(np.floor(Fs_sim / interval_target_hz)))
    anim_obj = None

    def init():
        h_prism.set_data([], [])
        h_prism.set_3d_properties([])
        h_brazo1.set_data([], [])
        h_brazo1.set_3d_properties([])
        h_brazo2.set_data([], [])
        h_brazo2.set_3d_properties([])
        h_eff.set_data([], [])
        h_eff.set_3d_properties([])
        h_tray_corte.set_data([], [])
        h_tray_corte.set_3d_properties([])
        h_tray_tras.set_data([], [])
        h_tray_tras.set_3d_properties([])
        return (h_prism, h_brazo1, h_brazo2, h_eff, h_tray_corte, h_tray_tras)

    def update(i):
        nonlocal flag_anterior
        if i >= num_puntos:
            return ()
        q = tray_art[i, 0:3]
        flag = tray_art[i, 3]
        if np.any(np.isnan(q)):
            return ()
        p_cart = cinematica_directa(q, L1, L2)
        X, Y, Z = p_cart
        p_base0 = np.array([0, 0, 0])
        p_base1 = np.array([0, 0, Z])
        p_codo = np.array([L1 * np.cos(q[1]), L1 * np.sin(q[1]), Z])
        p_mano = np.array([X, Y, Z])

        if flag == 1:
            if flag_anterior >= 2 and len(tray_corte) > 0:
                tray_corte.append([np.nan, np.nan, np.nan])
            tray_corte.append(p_mano.tolist())
            if flag_anterior >= 2:
                tray_tras.append([np.nan, np.nan, np.nan])
            h_eff.set_data([X], [Y])
            h_eff.set_3d_properties([Z])
        else:
            if flag_anterior == 1 and len(tray_tras) > 0:
                tray_tras.append([np.nan, np.nan, np.nan])
            tray_tras.append(p_mano.tolist())
            if flag_anterior == 1:
                tray_corte.append([np.nan, np.nan, np.nan])
            h_eff.set_data([], [])
            h_eff.set_3d_properties([])

        flag_anterior = flag

        h_prism.set_data([p_base0[0], p_base1[0]], [p_base0[1], p_base1[1]])
        h_prism.set_3d_properties([p_base0[2], p_base1[2]])
        h_brazo1.set_data([p_base1[0], p_codo[0]], [p_base1[1], p_codo[1]])
        h_brazo1.set_3d_properties([p_base1[2], p_codo[2]])
        h_brazo2.set_data([p_codo[0], p_mano[0]], [p_codo[1], p_mano[1]])
        h_brazo2.set_3d_properties([p_codo[2], p_mano[2]])

        if tray_corte:
            arr_c = np.array(tray_corte)
            h_tray_corte.set_data(arr_c[:, 0], arr_c[:, 1])
            h_tray_corte.set_3d_properties(arr_c[:, 2])
        if tray_tras:
            arr_t = np.array(tray_tras)
            h_tray_tras.set_data(arr_t[:, 0], arr_t[:, 1])
            h_tray_tras.set_3d_properties(arr_t[:, 2])
        return (h_prism, h_brazo1, h_brazo2, h_eff, h_tray_corte, h_tray_tras)

    if show:
        intervals_ms = []
        for i in range(1, num_puntos):
            dt_real = (tiempos[i] - tiempos[i - 1]) / max(speedup, 1e-6)
            intervals_ms.append(max(dt_real * 1000.0, 1.0))
        interval_default = intervals_ms[0] if intervals_ms else 40.0
        anim_obj = animation.FuncAnimation(
            fig,
            update,
            init_func=init,
            frames=range(0, num_puntos, skip_rate),
            interval=interval_default,
            blit=False,
        )
        plt.show()
    return fig, ax, anim_obj


__all__ = ["animar_trayectoria"]
