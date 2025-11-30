from __future__ import annotations

from typing import List, Tuple

import numpy as np


def planificar_trayectoria(
    tray_int: np.ndarray,
    z_home: float,
    z_cut: float,
    paso: float = 1.0,
    speed_cut: float = 5000.0,
    speed_traslado: float = 15000.0,
) -> np.ndarray:
    """
    Genera trayectoria 3D con perfiles trapezoidales básicos (distancia uniforme).
    Basado en PlanificarTrayectoria.m (simplificado: sin aceleración explícita).
    Retorna [X Y Z FLAG V].
    FLAG: 1 corte, 2 reposo, 3 traslado seguro.
    Velocidades en mm/s (speed_cut, speed_traslado), paso en mm.
    """
    if tray_int.ndim != 2 or tray_int.shape[1] < 4:
        raise ValueError("tray_int debe ser Nx4 [X Y Z FLAG]")

    V_cut_ms = (speed_cut / 1000.0) / 60.0  # m/s (siguiendo nota original)
    V_tras_ms = (speed_traslado / 1000.0) / 60.0
    TrayFinal = []

    idx_nan = np.where(np.isnan(tray_int[:, 0]))[0]
    idx_nan = np.concatenate(([ -1 ], idx_nan, [ tray_int.shape[0] ]))

    for b in range(len(idx_nan) - 1):
        ini = idx_nan[b] + 1
        fin = idx_nan[b + 1]
        if fin <= ini:
            continue
        bloque = tray_int[ini:fin, :]
        nb = bloque.shape[0]
        flag_bloque = bloque[0, 3]

        if len(TrayFinal) == 0:
            # Inicio absoluto: usar traslado (3) a Z_home y plunge a Z_cut
            p_end_safe = bloque[-1, 0:3]
            trans_ini_plunge = _build_plunge(p_end_safe, z_cut, paso, V_tras_ms)
            bloque_vel = _apply_speed_flag(bloque, flag_bloque, V_cut_ms, V_tras_ms)
            TrayFinal.extend(bloque_vel.tolist())
            if trans_ini_plunge.size:
                # omite primer punto para no duplicar
                TrayFinal.extend(trans_ini_plunge[1:, :].tolist())
        else:
            p_prev = np.array(TrayFinal[-1][0:3])
            p_ini = bloque[0, 0:3]
            z_prev = p_prev[2]
            z_next = p_ini[2]

            # Punto de transición marcado como FLAG=3
            p_trans = [p_prev[0], p_prev[1], z_prev, 3, V_tras_ms]

            trans_up = _build_lift(p_prev, z_home, paso, V_tras_ms)
            trans_xy = _build_xy(p_prev, p_ini, z_home, paso, V_tras_ms)
            trans_down = _build_plunge(p_ini, z_next, paso, V_tras_ms, end_flag=1, end_v=0.0)

            TrayFinal.append(p_trans)
            if trans_up.size:
                TrayFinal.extend(trans_up.tolist())
            if trans_xy.size:
                TrayFinal.extend(trans_xy.tolist())
            if trans_down.size:
                TrayFinal.extend(trans_down.tolist())

        # Bloque principal
        bloque_vel = _apply_speed_flag(bloque, flag_bloque, V_cut_ms, V_tras_ms)
        TrayFinal.extend(bloque_vel.tolist())

    if not TrayFinal:
        return np.empty((0, 5))
    return np.array(TrayFinal, dtype=float)


def _apply_speed_flag(bloque: np.ndarray, flag_bloque: float, v_cut: float, v_tras: float) -> np.ndarray:
    nb = bloque.shape[0]
    if flag_bloque == 1:
        v_des = np.full(nb, v_cut, dtype=float)
        v_des[-1] = 0.0
    elif flag_bloque == 2:
        v_des = np.zeros(nb, dtype=float)
    else:
        v_des = np.full(nb, v_tras, dtype=float)
    return np.column_stack([bloque[:, 0:4], v_des])


def _build_plunge(p, z_target, paso, v, end_flag: int = 3, end_v: float = None) -> np.ndarray:
    n = max(2, int(np.ceil(abs(z_target - p[2]) / paso)))
    if n < 2:
        return np.empty((0, 5))
    z_lin = np.linspace(p[2], z_target, n)
    res = np.column_stack(
        [
            np.full(n, p[0], dtype=float),
            np.full(n, p[1], dtype=float),
            z_lin,
            np.full(n, 3, dtype=float),
            np.full(n, v, dtype=float),
        ]
    )
    res[-1, 3] = end_flag
    res[-1, 4] = 0.0 if end_v is None else end_v
    return res


def _build_lift(p, z_home, paso, v) -> np.ndarray:
    if abs(z_home - p[2]) < 1e-9:
        return np.empty((0, 5))
    n = max(2, int(np.ceil(abs(z_home - p[2]) / paso)))
    z_lin = np.linspace(p[2], z_home, n)
    return np.column_stack(
        [
            np.full(n, p[0], dtype=float),
            np.full(n, p[1], dtype=float),
            z_lin,
            np.full(n, 3, dtype=float),
            np.full(n, v, dtype=float),
        ]
    )


def _build_xy(p_prev, p_ini, z_home, paso, v) -> np.ndarray:
    dist_xy = np.linalg.norm(p_ini[0:2] - p_prev[0:2])
    n = max(2, int(np.ceil(dist_xy / paso)))
    x_lin = np.linspace(p_prev[0], p_ini[0], n)
    y_lin = np.linspace(p_prev[1], p_ini[1], n)
    return np.column_stack(
        [
            x_lin,
            y_lin,
            np.full(n, z_home, dtype=float),
            np.full(n, 3, dtype=float),
            np.full(n, v, dtype=float),
        ]
    )


__all__ = ["planificar_trayectoria"]
