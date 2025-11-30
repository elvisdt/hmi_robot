from __future__ import annotations

import numpy as np


def cinematica_directa(Q_art, L1, L2):
    """
    Cinematica directa SCARA P-R-R.
    Q_art: iterable [d1, th2, th3], angulos en rad.
    L1, L2 en metros. Retorna np.array [X, Y, Z].
    """
    d1, th2, th3 = Q_art
    x_codo = L1 * np.cos(th2)
    y_codo = L1 * np.sin(th2)
    x = x_codo + L2 * np.cos(th2 + th3)
    y = y_codo + L2 * np.sin(th2 + th3)
    z = d1
    return np.array([x, y, z], dtype=float)


def cinematica_inversa(tray_cart_pos: np.ndarray, L1: float, L2: float, tray_cart_aux: np.ndarray):
    """
    Cinematica inversa para trayectoria cartesiana -> articular (P-R-R).
    tray_cart_pos: Nx3 [X Y Z] (m)
    tray_cart_aux: Nx2 [flag, v]
    Retorna Nx5 [d1, th2, th3, flag, v]
    """
    n = tray_cart_pos.shape[0]
    out = np.zeros((n, 5), dtype=float)
    for i in range(n):
        x, y, z = tray_cart_pos[i]
        r_sq = x**2 + y**2
        r = np.sqrt(r_sq)
        cos_th3 = (r_sq - L1**2 - L2**2) / (2 * L1 * L2)
        cos_th3 = np.clip(cos_th3, -1.0, 1.0)
        th3 = np.arctan2(np.sqrt(1 - cos_th3**2), cos_th3)  # codo abajo
        th2_offset = np.arctan2(L2 * np.sin(th3), L1 + L2 * np.cos(th3))
        th2 = np.arctan2(y, x) - th2_offset
        flag, v = tray_cart_aux[i]
        out[i] = [z, th2, th3, flag, v]
    return out


def jacobiano(d1: float, th2: float, th3: float, L1: float, L2: float) -> np.ndarray:
    """
    Jacobiano 3x3 para SCARA P-R-R.
    """
    C2 = np.cos(th2)
    S2 = np.sin(th2)
    C23 = np.cos(th2 + th3)
    S23 = np.sin(th2 + th3)
    J = np.zeros((3, 3))
    J[0, 0] = 0
    J[1, 0] = 0
    J[2, 0] = 1
    J[0, 1] = -L1 * S2 - L2 * S23
    J[1, 1] = L1 * C2 + L2 * C23
    J[2, 1] = 0
    J[0, 2] = -L2 * S23
    J[1, 2] = L2 * C23
    J[2, 2] = 0
    return J


__all__ = ["cinematica_directa", "cinematica_inversa", "jacobiano"]
