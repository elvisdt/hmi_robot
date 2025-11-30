from __future__ import annotations

import numpy as np


def diferenciar_trayectoria_articular(
    tray_art: np.ndarray,
    paso: float = 1.0,
    Fs: float = 200.0,
    qdot_max: np.ndarray | None = None,
    qddot_max: np.ndarray | None = None,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Diferencia numérica de trayectorias articulares (Q_dot y Q_ddot) con límites y suavizado.
    tray_art: Nx5 [d1, th2, th3, flag, V] (V en m/s)
    paso: mm (para dL_cart); Fs: frecuencia de muestreo mínima.
    Retorna (Q_dot, Q_ddot, Tiempos)
    """
    if tray_art.ndim != 2 or tray_art.shape[1] < 5:
        raise ValueError("tray_art debe ser Nx5 [d1 th2 th3 flag V]")
    Q = tray_art[:, 0:3]
    V_ms = tray_art[:, 4]
    num_puntos = Q.shape[0]
    Q_dot = np.zeros_like(Q)
    Q_ddot = np.zeros_like(Q)
    Tiempos = np.zeros(num_puntos)

    dL_cart = paso / 1000.0
    dt_min = 1.0 / Fs
    dL_min = dL_cart * 0.01

    for i in range(1, num_puntos):
        dt = dt_min
        if dL_cart < dL_min and V_ms[i] < 1e-6:
            dt = dt_min
        elif V_ms[i] < 1e-6:
            dt = dt_min
        else:
            V_prom = (V_ms[i] + V_ms[i - 1]) / 2.0
            if V_prom > 1e-6:
                dt = dL_cart / V_prom
            else:
                dt = dt_min
        Tiempos[i] = Tiempos[i - 1] + max(dt, 1e-9)

    for j in range(3):
        dt_ini = Tiempos[1] - Tiempos[0]
        Q_dot[0, j] = (Q[1, j] - Q[0, j]) / dt_ini
        for i in range(1, num_puntos - 1):
            dt_span = Tiempos[i + 1] - Tiempos[i - 1]
            Q_dot[i, j] = (Q[i + 1, j] - Q[i - 1, j]) / dt_span
        dt_fin = Tiempos[-1] - Tiempos[-2]
        Q_dot[-1, j] = (Q[-1, j] - Q[-2, j]) / dt_fin

        Q_ddot[0, j] = (Q_dot[1, j] - Q_dot[0, j]) / dt_ini
        for i in range(1, num_puntos - 1):
            dt_span = Tiempos[i + 1] - Tiempos[i - 1]
            Q_ddot[i, j] = (Q_dot[i + 1, j] - Q_dot[i - 1, j]) / dt_span
        Q_ddot[-1, j] = (Q_dot[-1, j] - Q_dot[-2, j]) / dt_fin

    if qdot_max is not None:
        qdot_max = np.asarray(qdot_max)
        for j in range(3):
            Q_dot[:, j] = np.clip(Q_dot[:, j], -qdot_max[j], qdot_max[j])
    if qddot_max is not None:
        qddot_max = np.asarray(qddot_max)
        for j in range(3):
            Q_ddot[:, j] = np.clip(Q_ddot[:, j], -qddot_max[j], qddot_max[j])

    # suavizado de Q_ddot (media móvil ~5% del total)
    window = max(3, 2 * (int(num_puntos * 0.05) // 2) + 1)
    Q_ddot = _smooth_moving_mean(Q_ddot, window)

    Q_dot[~np.isfinite(Q_dot)] = 0
    Q_ddot[~np.isfinite(Q_ddot)] = 0
    Q_dot[np.abs(Q_dot) < 1e-9] = 0
    Q_ddot[np.abs(Q_ddot) < 1e-6] = 0
    return Q_dot, Q_ddot, Tiempos


def _smooth_moving_mean(arr: np.ndarray, window: int) -> np.ndarray:
    if window < 3:
        return arr
    out = np.zeros_like(arr)
    pad = window // 2
    for j in range(arr.shape[1]):
        padded = np.pad(arr[:, j], (pad, pad), mode="edge")
        kernel = np.ones(window) / window
        sm = np.convolve(padded, kernel, mode="valid")
        out[:, j] = sm
    return out


__all__ = ["diferenciar_trayectoria_articular"]
