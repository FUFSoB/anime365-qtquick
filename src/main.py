import sys
import subprocess
from pathlib import Path
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickItem


def open_uget():
    subprocess.run(["uget-gtk"])
    print("uget opened")


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    qml_file = Path(__file__).resolve().parent / "main.qml"

    engine.addImportPath(qml_file.parent.as_posix())

    engine.load(QUrl.fromLocalFile("main.qml"))

    if not engine.rootObjects():
        sys.exit(-1)

    uget = engine.rootObjects()[0].findChild(QQuickItem, "openUgetButton")

    sys.exit(app.exec())
