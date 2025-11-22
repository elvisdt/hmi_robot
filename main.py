import os
import sys
from pathlib import Path

from PySide6.QtCore import QObject, QUrl, Signal, Slot
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine

HERE = Path(__file__).resolve().parent

from core.backend import Backend

def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()

    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)

    qml_path = QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml"))
    engine.load(qml_path)

    if not engine.rootObjects():
        print("ERROR: No se pudo cargar Main.qml. Revisa la ruta.")
        sys.exit(-1)

    # Connect on-demand references (optional)
    root = engine.rootObjects()[0]
    _ = root.findChild(QObject, "viewer2d")

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
