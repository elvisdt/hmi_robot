from __future__ import annotations

from typing import List

import numpy as np


def interpolar_trayectoria(tray_bruta: List[np.ndarray], paso: float, z_cut: float) -> np.ndarray:
    """
    Interpola trayectoria forzando Z=z_cut si FLAG=1, excluyendo grupos con FLAG=0.
    Basado en InterpolarTrayectoria.m.
    Retorna ndarray con separadores NaN entre grupos.
    FLAG: 1 corte, 2 reposo, 3 traslado seguro.
    """
    if paso <= 0:
        raise ValueError("paso debe ser > 0")
    tray_int = []
    grupos_validos: List[np.ndarray] = []
    for g in tray_bruta:
        if g.size == 0 or np.all(np.isnan(g)):
            continue
        flags = g[:, 3]
        if not np.all(flags == 0):
            grupos_validos.append(g)

    for idx, g in enumerate(grupos_validos):
        X, Y, Zg, C = g[:, 0], g[:, 1], g[:, 2], g[:, 3]
        flag_bloque = C[0]
        if flag_bloque == 1:
            Z = np.full_like(X, z_cut, dtype=float)
        else:
            Z = Zg.copy()

        mask = ~(np.isnan(X) | np.isnan(Y))
        X, Y, Z, C = X[mask], Y[mask], Z[mask], C[mask]
        if X.size == 0:
            continue

        Z_initial = Z[0]
        Z = np.full_like(Z, Z_initial, dtype=float)
        dist = np.concatenate([[0.0], np.cumsum(np.sqrt(np.diff(X) ** 2 + np.diff(Y) ** 2))])
        L = dist[-1]
        if L < paso or X.size < 2:
            X_int, Y_int, Z_int, C_int = X, Y, Z, C
        else:
            s_int = np.arange(0, L + 1e-9, paso)
            X_int = np.interp(s_int, dist, X)
            Y_int = np.interp(s_int, dist, Y)
            Z_int = np.full_like(X_int, Z_initial, dtype=float)
            C_int = np.full_like(X_int, flag_bloque, dtype=float)
        tray_int.append(np.column_stack([X_int, Y_int, Z_int, C_int]))
        if idx < len(grupos_validos) - 1:
            tray_int.append(np.array([[np.nan, np.nan, np.nan, np.nan]]))
    if not tray_int:
        return np.empty((0, 4))
    return np.vstack(tray_int)


__all__ = ["interpolar_trayectoria"]
