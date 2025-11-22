import os
import sys
from pathlib import Path

from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication


def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    here = Path(__file__).resolve().parent
    qml_file = here / "ControlsPanelDemo.qml"

    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(here.parent / "qml"))
    engine.load(str(qml_file))

    if not engine.rootObjects():
        print("ERROR: no se pudo cargar ControlsPanelDemo.qml")
        sys.exit(-1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
