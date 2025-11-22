from PySide6.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget
from PySide6.QtQuickWidgets import QQuickWidget
from PySide6.QtCore import QObject


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("Robot 3D")
        container = QWidget()
        layout = QVBoxLayout(container)

        self.view = QQuickWidget()
        self.view.setResizeMode(QQuickWidget.ResizeMode.SizeRootObjectToView)
        self.view.setSource("../assets/robot.qml")

        self.robot = self.view.rootObject().findChild(QObject, "robot")

        layout.addWidget(self.view)
        self.setCentralWidget(container)

    def mover(self, r1, m1, r2):
        self.robot.setProperty("rotation1", r1)
        self.robot.setProperty("movement1", m1)
        self.robot.setProperty("rotation2", r2)

app = QApplication([])
w = MainWindow()
w.show()
app.exec()
