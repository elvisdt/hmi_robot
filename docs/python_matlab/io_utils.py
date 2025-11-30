from __future__ import annotations

from pathlib import Path
from typing import List

import numpy as np


def leer_trayectoria(filepath: str | Path) -> List[np.ndarray]:
    """
    Lee archivo TXT/CSV con columnas [X Y Z C] y devuelve lista de grupos (separados por NaN).
    Equivale a LeerTrayectoria.m.
    """
    path = Path(filepath)
    if not path.is_file():
        raise FileNotFoundError(f"Archivo no encontrado: {path}")

    data = np.genfromtxt(path, delimiter=None)
    if data.ndim == 1:
        data = np.reshape(data, (1, -1))
    if data.shape[1] < 4:
        raise ValueError("Archivo inválido: requiere 4 columnas [X Y Z C].")

    X, Y, Z, C = data[:, 0], data[:, 1], data[:, 2], data[:, 3]
    is_nan = np.isnan(X) | np.isnan(Y) | np.isnan(Z) | np.isnan(C)
    idx_nan = np.where(is_nan)[0]
    idx_nan = np.concatenate(([ -1 ], idx_nan, [len(X)]))

    grupos: List[np.ndarray] = []
    for k in range(len(idx_nan) - 1):
        ini = idx_nan[k] + 1
        fin = idx_nan[k + 1]
        if fin > ini:
            grupos.append(np.column_stack([X[ini:fin], Y[ini:fin], Z[ini:fin], C[ini:fin]]))
    return grupos


__all__ = ["leer_trayectoria"]
