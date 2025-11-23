import os
import sys
from pathlib import Path

from PySide6.QtCore import QObject, QUrl, Signal, Slot

class Backend(QObject):
    pointsReady = Signal(list)
    statusMessage = Signal(str)

    def __init__(self):
        super().__init__()
        self.chord_tol = 1.5  # mm equivalent for curve flattening
        self.world_x_min = 0.0
        self.world_x_max = 600.0
        self.world_y_min = -600.0
        self.world_y_max = 600.0
        self.margin_ratio = 0.08  # 8% del lado menor para no tocar bordes

    def _entity_points(self, entity, tol):
        """Convert supported entities to a list of (x, y) points."""
        try:
            from ezdxf import path as ezpath
            path = ezpath.make_path(entity)
        except Exception:
            return []

        verts = list(path.flattening(distance=tol, segments=400))
        if not verts:
            return []

        pts = [(v.x, v.y) for v in verts]
        is_closed = getattr(path, "is_closed", False)
        if is_closed and len(pts) > 2 and pts[0] != pts[-1]:
            pts.append(pts[0])
        return pts

    @Slot(str, float, float)
    def loadDxf(self, url: str, viewport_w: float = 520.0, viewport_h: float = 520.0) -> None:
        """Load DXF and emit a list of {x,y} points scaled to viewer area."""
        try:
            import ezdxf
        except ImportError:
            self.statusMessage.emit("ezdxf no disponible. Instala dependencias.")
            return

        # Resolve URL to filesystem path
        if not url:
            self.statusMessage.emit("Ruta DXF vacía.")
            return
        qurl = QUrl(url)
        path = Path(qurl.toLocalFile() if qurl.isLocalFile() else url)
        if not path.exists():
            self.statusMessage.emit(f"DXF no encontrado: {path}")
            return

        try:
            doc = ezdxf.readfile(str(path))
        except Exception as exc:  # pragma: no cover - best effort
            self.statusMessage.emit(f"Error leyendo DXF: {exc}")
            return

        msp = doc.modelspace()
        all_polys = []

        supported = {"LINE", "LWPOLYLINE", "POLYLINE", "SPLINE", "CIRCLE", "ARC", "ELLIPSE"}
        for e in msp:
            if e.dxftype() not in supported:
                continue
            pts = self._entity_points(e, self.chord_tol)
            if len(pts) >= 2:
                all_polys.append(pts)

        # If nothing collected, notify
        if not all_polys:
            self.statusMessage.emit("DXF sin geometría soportada (LINE/LWPOLYLINE/CIRCLE/ARC/ELLIPSE/SPLINE).")
            return

        # Escala fija al espacio de trabajo definido (mm)
        range_x = max(self.world_x_max - self.world_x_min, 1e-6)
        range_y = max(self.world_y_max - self.world_y_min, 1e-6)
        target_w = viewport_w if viewport_w and viewport_w > 0 else 520
        target_h = viewport_h if viewport_h and viewport_h > 0 else 520
        margin = self.margin_ratio * min(target_w, target_h)
        inner_w = target_w - 2 * margin
        inner_h = target_h - 2 * margin
        scale = min(inner_w / range_x, inner_h / range_y)
        extra_x = max(0.0, (inner_w - range_x * scale) / 2)
        extra_y = max(0.0, (inner_h - range_y * scale) / 2)

        # Scale each poly separately and insert breaks between them
        qpoints = []
        for idx, poly in enumerate(all_polys):
            if idx > 0:
                qpoints.append({"break": True})
            for x, y in poly:
                qx = margin + extra_x + (x - self.world_x_min) * scale
                qy = margin + extra_y + (self.world_y_max - y) * scale  # invert Y to avoid mirror
                qpoints.append({"x": qx, "y": qy})

        self.pointsReady.emit(qpoints)
        self.statusMessage.emit(f"Cargado DXF ({len(qpoints)} puntos): {path.name}")
