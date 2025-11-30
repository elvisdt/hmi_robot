from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QObject, QUrl, Signal, Slot

from core.dxf_converter import DxfTopologyConverter


class Backend(QObject):
    pointsReady = Signal(list)
    boundsReady = Signal(float, float, float, float)
    imageReady = Signal(str)
    statusMessage = Signal(str)

    def __init__(self):
        super().__init__()
        self.chord_tol = 1.5  # mm

    @Slot(str, float, float)
    def loadDxf(self, url: str, viewport_w: float = 520.0, viewport_h: float = 520.0) -> None:
        """Procesa DXF y emite puntos sin escalar (x,y en mm) con flags y breaks."""
        if not url:
            self.statusMessage.emit("Ruta DXF vacia.")
            return
        qurl = QUrl(url)
        path = Path(qurl.toLocalFile() if qurl.isLocalFile() else url)
        if not path.exists():
            self.statusMessage.emit(f"DXF no encontrado: {path}")
            return
        try:
            conv = DxfTopologyConverter(path, tol_topo=self.chord_tol).process()
        except Exception as exc:
            self.statusMessage.emit(f"Error procesando DXF: {exc}")
            return

        shapes = []
        for geom, flag in conv._geoms_final:  # noqa: SLF001
            if geom is None:
                continue
            if geom.geom_type == "Polygon":
                rings = [geom.exterior] + list(geom.interiors)
                for r in rings:
                    shapes.append((list(r.coords), flag))
            else:
                shapes.append((list(geom.coords), flag))

        if not shapes:
            self.statusMessage.emit("DXF sin geometria procesada.")
            return

        qpoints = []
        for idx, (poly, flag) in enumerate(shapes):
            if idx > 0:
                qpoints.append({"break": True})
            for x, y in poly:
                qpoints.append({"x": x, "y": y, "flag": int(flag)})

        self._emit_bounds(qpoints)
        self._emit_preview_png(qpoints, path)
        self.pointsReady.emit(qpoints)
        self.statusMessage.emit(f"Cargado DXF topo ({len(qpoints)} puntos): {path.name}")

    @Slot(str, float, float)
    def loadCsvXY(self, url: str, viewport_w: float = 520.0, viewport_h: float = 520.0) -> None:
        """Lee CSV/TXT con columnas X,Y y emite puntos sin escalar."""
        if not url:
            self.statusMessage.emit("Ruta CSV vacia.")
            return
        qurl = QUrl(url)
        path = Path(qurl.toLocalFile() if qurl.isLocalFile() else url)
        if not path.exists():
            self.statusMessage.emit(f"CSV no encontrado: {path}")
            return

        lines = path.read_text(encoding="utf-8").splitlines()
        raw_pts = []
        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.replace(",", " ").split()
            try:
                vals = [float(p) if p.lower() != "nan" else float("nan") for p in parts]
            except Exception:
                continue
            if len(vals) < 2:
                continue
            x, y = vals[0], vals[1]
            if any(v != v for v in (x, y)):
                raw_pts.append(None)
            else:
                raw_pts.append((x, y))

        valid = [(x, y) for p in raw_pts if p is not None for x, y in [p]]
        if not valid:
            self.statusMessage.emit("CSV sin puntos numericos.")
            return

        qpoints = []
        first = True
        for p in raw_pts:
            if p is None:
                first = True
                continue
            x, y = p
            if not first:
                pass
            else:
                if qpoints:
                    qpoints.append({"break": True})
                first = False
            qpoints.append({"x": x, "y": y})

        self._emit_bounds(qpoints)
        self._emit_preview_png(qpoints, path)
        self.pointsReady.emit(qpoints)
        self.statusMessage.emit(f"Cargado CSV ({len(qpoints)} puntos): {path.name}")

    # Internos
    def _emit_bounds(self, qpoints: list) -> None:
        xs = []
        ys = []
        for p in qpoints:
            if not isinstance(p, dict):
                continue
            x = p.get("x")
            y = p.get("y")
            if x is None or y is None:
                continue
            xs.append(x)
            ys.append(y)
        if not xs or not ys:
            return
        self.boundsReady.emit(float(min(xs)), float(max(xs)), float(min(ys)), float(max(ys)))

    def _emit_preview_png(self, qpoints: list, src_path: Path) -> None:
        try:
            import matplotlib

            matplotlib.use("Agg")  # backend sin GUI
            import matplotlib.pyplot as plt
        except Exception as exc:  # pragma: no cover - fallback si no hay matplotlib
            self.statusMessage.emit(f"Matplotlib no disponible: {exc}")
            return

        segs = []
        cur_x = []
        cur_y = []
        cur_flag = 0
        for p in qpoints:
            if p.get("break"):
                if cur_x and cur_y:
                    segs.append((cur_x, cur_y, cur_flag))
                cur_x, cur_y, cur_flag = [], [], 0
                continue
            x = p.get("x")
            y = p.get("y")
            if x is None or y is None:
                continue
            cur_flag = int(p.get("flag", 0))
            cur_x.append(x)
            cur_y.append(y)
        if cur_x and cur_y:
            segs.append((cur_x, cur_y, cur_flag))
        if not segs:
            return

        fig, ax = plt.subplots(figsize=(9, 5))
        for xs, ys, flag in segs:
            color = "#22c55e" if flag == 1 else "#f59e0b"
            ax.fill(xs, ys, color=color, alpha=0.25)
            ax.plot(xs, ys, color=color, lw=1.6 if flag == 1 else 1.2)
        ax.set_aspect("equal", adjustable="box")
        ax.set_xlabel("X (mm)")
        ax.set_ylabel("Y (mm)")
        ax.grid(True, alpha=0.35)
        ax.set_title(src_path.name)

        out_dir = Path("docs/tmp")
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / "preview.png"
        fig.savefig(out_path, dpi=180, bbox_inches="tight")
        plt.close(fig)
        self.imageReady.emit(str(out_path.resolve()))
