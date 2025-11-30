"""
Puente Python de utilidades originalmente en MATLAB (SCARA/CNC).
Incluye IO de trayectorias, cinemática directa/inversa, jacobiano e interpolación.
"""

from .io_utils import leer_trayectoria
from .kinematics import cinematica_directa, cinematica_inversa, jacobiano
from .interpolation import interpolar_trayectoria
from .planning import planificar_trayectoria
from .differentiation import diferenciar_trayectoria_articular
from .animation import animar_trayectoria

__all__ = [
    "leer_trayectoria",
    "cinematica_directa",
    "cinematica_inversa",
    "jacobiano",
    "interpolar_trayectoria",
    "planificar_trayectoria",
    "diferenciar_trayectoria_articular",
    "animar_trayectoria",
]
