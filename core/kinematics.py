"""
Kinematics utilities for the SCARA P-R-R robot.

Units:
- Distances in meters.
- Angles in radians.
"""

from __future__ import annotations

import math
from typing import Iterable, List, Sequence, Tuple


def forward(q_art: Sequence[float], l1: float, l2: float) -> Tuple[float, float, float]:
    """
    Cinemática directa: [d1, th2, th3] -> (x, y, z).
    d1 es prismatic (Z), th2 y th3 rotacionales (rad).
    """
    d1, th2, th3 = q_art

    x_codo = l1 * math.cos(th2)
    y_codo = l1 * math.sin(th2)

    x = x_codo + l2 * math.cos(th2 + th3)
    y = y_codo + l2 * math.sin(th2 + th3)
    z = d1
    return x, y, z


def inverse(
    tray_cart_pos: Iterable[Sequence[float]],
    l1: float,
    l2: float,
    tray_cart_aux: Iterable[Sequence[float]],
) -> List[Tuple[float, float, float, float, float]]:
    """
    Cinemática inversa para trayectorias cartesianas.

    Entradas:
        tray_cart_pos: iterable de (x, y, z) en metros.
        l1, l2: longitudes de los brazos (m).
        tray_cart_aux: iterable de (flag, v) por punto.
    Salida:
        Lista de tuplas (d1, th2, th3, flag, v).
    """
    pos_list = list(tray_cart_pos)
    aux_list = list(tray_cart_aux)
    if len(pos_list) != len(aux_list):
        raise ValueError("tray_cart_pos y tray_cart_aux deben tener la misma longitud")

    def _clamp(x: float) -> float:
        return max(-1.0, min(1.0, x))

    tray_art = []
    for (x, y, z), (flag, v) in zip(pos_list, aux_list):
        d1 = z

        r_sq = x * x + y * y
        r = math.sqrt(r_sq)
        cos_th3 = _clamp((r_sq - l1 * l1 - l2 * l2) / (2 * l1 * l2))
        th3 = math.atan2(math.sqrt(max(0.0, 1.0 - cos_th3 * cos_th3)), cos_th3)  # elbow-down

        th2_offset = math.atan2(l2 * math.sin(th3), l1 + l2 * math.cos(th3))
        th2 = math.atan2(y, x) - th2_offset

        tray_art.append((d1, th2, th3, flag, v))

    return tray_art
