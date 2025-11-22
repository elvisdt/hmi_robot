"""
Trayectoria: interpolación y planificación estilo MATLAB.

Entradas típicas en mm (X, Y, Z) y flags:
 - FLAG 1: Corte (Z forzada a Z_cut)
 - FLAG 2: Reposo (Z_home)
 - FLAG 3: Traslado seguro (Z_home)

PlanificarTrayectoria devuelve coordenadas en metros y velocidades en m/s,
siguiendo la lógica original de PlanificarTrayectoria.m.
"""

from __future__ import annotations

import math
from typing import Iterable, List, Sequence, Tuple

Point4 = Sequence[float]  # [x, y, z, flag]
Point5 = Sequence[float]  # [x, y, z, flag, v]


def _is_nan_row(row: Sequence[float]) -> bool:
    return any(r is None or (isinstance(r, float) and math.isnan(r)) for r in row)


def _interp_linear(xs: List[float], ys: List[float], targets: List[float]) -> List[float]:
    """Simple 1D linear interpolation assuming xs sorted ascending."""
    out = []
    for t in targets:
        if t <= xs[0]:
            out.append(ys[0])
            continue
        if t >= xs[-1]:
            out.append(ys[-1])
            continue
        # binary search
        lo, hi = 0, len(xs) - 1
        while hi - lo > 1:
            mid = (hi + lo) // 2
            if xs[mid] <= t:
                lo = mid
            else:
                hi = mid
        x0, x1 = xs[lo], xs[hi]
        y0, y1 = ys[lo], ys[hi]
        ratio = (t - x0) / (x1 - x0) if x1 != x0 else 0.0
        out.append(y0 + ratio * (y1 - y0))
    return out


def interpolar_trayectoria(
    tray_bruta: Iterable[Iterable[Point4]],
    paso: float = 1.0,
    z_cut: float | None = None,
) -> List[List[float]]:
    """
    Replica InterpolarTrayectoria.m.

    tray_bruta: iterable de grupos; cada grupo es iterable de [X,Y,Z,FLAG] (mm).
    paso: mm entre puntos interpolados.
    z_cut: mm de corte obligatorio (requerido).
    Retorna: lista de puntos [X,Y,Z,FLAG] con NaN separando bloques.
    """
    if z_cut is None:
        raise ValueError("z_cut es requerido")

    tray_int: List[List[float]] = []

    # 1) filtrar grupos con todos los flags = 0
    grupos_validos: List[List[List[float]]] = []
    for g in tray_bruta:
        g_list = [list(p) for p in g if p is not None]
        if not g_list:
            continue
        flags = [p[3] for p in g_list]
        if all(f == 0 for f in flags):
            continue
        grupos_validos.append(g_list)

    # 2) interpolar cada grupo
    for idx, g in enumerate(grupos_validos):
        xs = [p[0] for p in g]
        ys = [p[1] for p in g]
        zs = [p[2] for p in g]
        flags = [p[3] for p in g]

        flag_bloque = flags[0]
        # Z handling
        if flag_bloque == 1:
            zs = [z_cut for _ in zs]

        # limpiar NaN
        clean = [
            (x, y, z, f)
            for x, y, z, f in zip(xs, ys, zs, flags)
            if not (math.isnan(x) or math.isnan(y))
        ]
        if not clean:
            continue
        xs, ys, zs, flags = zip(*clean)

        z_initial = zs[0]
        zs = [z_initial for _ in zs]

        dist = [0.0]
        for i in range(1, len(xs)):
            dx = xs[i] - xs[i - 1]
            dy = ys[i] - ys[i - 1]
            dist.append(dist[-1] + math.hypot(dx, dy))
        L = dist[-1]

        if L < paso or len(xs) < 2:
            x_int, y_int, z_int, f_int = list(xs), list(ys), list(zs), list(flags)
        else:
            s_int = [i * paso for i in range(int(math.floor(L / paso)) + 1)]
            if s_int[-1] < L:
                s_int.append(L)
            x_int = _interp_linear(dist, list(xs), s_int)
            y_int = _interp_linear(dist, list(ys), s_int)
            z_int = [z_initial] * len(s_int)
            f_int = [flag_bloque] * len(s_int)

        tray_int.extend([[x, y, z, f] for x, y, z, f in zip(x_int, y_int, z_int, f_int)])
        if idx < len(grupos_validos) - 1:
            tray_int.append([math.nan, math.nan, math.nan, math.nan])

    return tray_int


def _split_blocks(tray_int: Sequence[Sequence[float]]) -> List[List[List[float]]]:
    blocks: List[List[List[float]]] = []
    current: List[List[float]] = []
    for row in tray_int:
        if _is_nan_row(row):
            if current:
                blocks.append(current)
                current = []
            continue
        current.append(list(row))
    if current:
        blocks.append(current)
    return blocks


def planificar_trayectoria(
    tray_int: Sequence[Sequence[float]],
    z_home: float,
    z_cut: float,
    paso: float = 1.0,
    speed_cut: float = 5000.0,
    speed_traslado: float = 15000.0,
    a_max_cart: float = 2000.0,
) -> List[List[float]]:
    """
    Replica PlanificarTrayectoria.m (versión simplificada y sin gráficos).

    Entradas:
        tray_int: lista de [x,y,z,flag] en mm, con NaN como separadores.
        z_home: altura de reposo (mm).
        z_cut: altura de corte (mm).
        paso: paso en mm para interpolación vertical/XY.
        speed_cut: mm/min (para FLAG=1).
        speed_traslado: mm/min (para FLAG=3).
        a_max_cart: mm/s^2 (aceleración máx).
    Salida:
        Lista de [x,y,z,flag,v] en metros y m/s con perfil trapezoidal.
    """
    V_cut_ms = (speed_cut / 1000.0) / 60.0
    V_tras_ms = (speed_traslado / 1000.0) / 60.0
    A_max_ms2 = a_max_cart / 1000.0
    dL_cart = paso / 1000.0

    blocks = _split_blocks(tray_int)
    tray_final: List[List[float]] = []

    def add_block_with_vel(block: List[List[float]], v_value: float, flag_override: int | None = None):
        for i, row in enumerate(block):
            x, y, z, f = row
            f_out = flag_override if flag_override is not None else f
            v_out = v_value
            tray_final.append([x, y, z, f_out, v_out])

    for b_idx, block in enumerate(blocks):
        nb = len(block)
        if nb == 0:
            continue
        flag_block = int(block[0][3])

        if not tray_final:
            # Inicio: V traslado en bloque, V=0 en reposo
            V_deseada = [V_tras_ms] * nb
            if flag_block == 2:
                V_deseada = [0.0] * nb
            bloque_vel = [
                [x, y, z, f, v]
                for (x, y, z, f), v in zip(block, V_deseada)
            ]
            # plunge a z_cut si es corte
            p_end_safe = block[-1][0:3]
            nZ = max(2, int(math.ceil(abs(z_cut - p_end_safe[2]) / paso)))
            Z_down = [p_end_safe[2] + i * (z_cut - p_end_safe[2]) / (nZ - 1) for i in range(nZ)]
            trans_plunge = [
                [p_end_safe[0], p_end_safe[1], z, 3, V_tras_ms] for z in Z_down[1:]
            ]
            if trans_plunge:
                trans_plunge[-1][3] = 1
                trans_plunge[-1][4] = 0.0
            tray_final.extend(bloque_vel)
            tray_final.extend(trans_plunge)
        else:
            p_prev = tray_final[-1][0:3]
            p_ini = block[0][0:3]
            z_cut_prev = p_prev[2]
            z_cut_next = p_ini[2]

            # transición: punto de ruptura
            tray_final.append([p_prev[0], p_prev[1], z_cut_prev, 3, V_tras_ms])

            # subida a z_home
            if abs(z_home - z_cut_prev) > 1e-6:
                n1 = max(2, int(math.ceil(abs(z_home - z_cut_prev) / paso)))
                Z_up = [z_cut_prev + i * (z_home - z_cut_prev) / (n1 - 1) for i in range(n1)]
                tray_final.extend([[p_prev[0], p_prev[1], z, 3, V_tras_ms] for z in Z_up[1:]])

            # XY a z_home
            dist_xy = math.hypot(p_ini[0] - p_prev[0], p_ini[1] - p_prev[1])
            n2 = max(2, int(math.ceil(dist_xy / paso))) if dist_xy > 1e-9 else 0
            if n2 > 0:
                X_lin = [p_prev[0] + i * (p_ini[0] - p_prev[0]) / n2 for i in range(1, n2 + 1)]
                Y_lin = [p_prev[1] + i * (p_ini[1] - p_prev[1]) / n2 for i in range(1, n2 + 1)]
                tray_final.extend([[x, y, z_home, 3, V_tras_ms] for x, y in zip(X_lin, Y_lin)])

            # bajada a z_cut_next
            if abs(z_home - z_cut_next) > 1e-6:
                n3 = max(2, int(math.ceil(abs(z_cut_next - z_home) / paso)))
                Z_down = [z_home + i * (z_cut_next - z_home) / (n3 - 1) for i in range(n3)]
                down_rows = [[p_ini[0], p_ini[1], z, 3, V_tras_ms] for z in Z_down[1:]]
                if down_rows:
                    down_rows[-1][3] = 1
                    down_rows[-1][4] = 0.0
                tray_final.extend(down_rows)

            # bloque principal
            if flag_block == 1:
                V_deseada = [V_tras_ms] * nb
                V_deseada[-1] = 0.0
            elif flag_block == 2:
                V_deseada = [0.0] * nb
            elif flag_block == 3:
                V_deseada = [V_tras_ms] * nb
            else:
                V_deseada = [V_tras_ms] * nb
            tray_final.extend([[x, y, z, f, v] for (x, y, z, f), v in zip(block, V_deseada)])

    # subida final a z_home
    if tray_final:
        p_fin = tray_final[-1][0:3]
        if abs(p_fin[2] - z_home) > 1e-9 and int(tray_final[-1][3]) != 2:
            n_end = max(2, int(math.ceil(abs(z_home - p_fin[2]) / paso)))
            Z_end = [p_fin[2] + i * (z_home - p_fin[2]) / (n_end - 1) for i in range(n_end)]
            tray_final.extend([[p_fin[0], p_fin[1], z, 3, V_tras_ms] for z in Z_end[1:]])
        if int(tray_final[-1][3]) != 2:
            tray_final.append([tray_final[-1][0], tray_final[-1][1], z_home, 2, 0.0])

    # Perfil trapezoidal sobre la distancia acumulada (igual a la versión MATLAB)
    if not tray_final:
        return []

    # Iteración hacia adelante (aceleración)
    V_perfilada = [0.0] * len(tray_final)
    for i in range(1, len(tray_final)):
        flag_i = int(tray_final[i][3])
        flag_prev = int(tray_final[i - 1][3])
        V_target = tray_final[i][4]
        if flag_i == 2 or flag_prev == 2 or (flag_i == 1 and flag_prev != 1) or (flag_i == 3 and flag_prev == 1):
            V_target = 0.0
            V_prev = 0.0
        else:
            V_prev = V_perfilada[i - 1]

        V_max_acel_sq = V_prev * V_prev + 2 * A_max_ms2 * dL_cart
        V_max_acel = math.sqrt(max(0.0, V_max_acel_sq))
        V_perfilada[i] = min(V_target, V_max_acel)

    # Iteración hacia atrás (desaceleración)
    V_perfilada[-1] = 0.0
    for i in range(len(tray_final) - 2, -1, -1):
        flag_i = int(tray_final[i][3])
        flag_next = int(tray_final[i + 1][3])
        if flag_i == 2 or flag_next == 2 or (flag_i == 1 and flag_next != 1) or (flag_i == 1 and flag_next == 3):
            V_perfilada[i] = 0.0
            continue
        V_next = V_perfilada[i + 1]
        V_limit_decel_sq = V_next * V_next + 2 * A_max_ms2 * dL_cart
        V_limit_decel = math.sqrt(max(0.0, V_limit_decel_sq))
        V_perfilada[i] = min(V_perfilada[i], V_limit_decel)

    # Construir salida en metros
    tray_out: List[List[float]] = []
    vmin = 1e-6
    for row, v in zip(tray_final, V_perfilada):
        x, y, z, f, _ = row
        v_out = v if math.isfinite(v) and v >= vmin else vmin
        tray_out.append([x / 1000.0, y / 1000.0, z / 1000.0, f, v_out])

    return tray_out
