import sys
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from backend import Backend

if __name__ == "__main__":
    app = QApplication(sys.argv)

    # Cargar QML
    engine = QQmlApplicationEngine()

    # Instancia del backend REAL
    backend = Backend()

    # Exponer backend al QML
    engine.rootContext().setContextProperty("backend", backend)

    # Cargar ventana principal
    engine.load("qml/Main.qml")

    if not engine.rootObjects():
        print("Error: No se pudo cargar Main.qml")
        sys.exit(-1)

    sys.exit(app.exec())
