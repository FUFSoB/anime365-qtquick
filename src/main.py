# main.py
import signal
import sys
from pathlib import Path

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication

from constants import IS_ANDROID, create_dirs

create_dirs()

from backend import backends


class Anime365:
    def __init__(self):
        signal.signal(signal.SIGINT, lambda *args: self.handle_sigint())

        QQuickStyle.setStyle("Fusion")

        self.app = QApplication(sys.argv)
        self.engine = QQmlApplicationEngine()

        self.app.setApplicationName("Anime365")
        self.app.setDesktopFileName(
            "anime365"
        )  # must match the .desktop filename for Wayland app-id
        self.app.aboutToQuit.connect(lambda: backends["downloaderBackend"].shutdown())

        backends["settingsBackend"].apply_theme(
            backends["settingsBackend"].get("theme")
        )

        for name, backend in backends.items():
            self.engine.rootContext().setContextProperty(name, backend)

        self.engine.rootContext().setContextProperty("isAndroid", IS_ANDROID)

        qml_dir = Path(__file__).parent / "qml"
        main_qml = qml_dir / "main.qml"

        self.engine.load(QUrl.fromLocalFile(str(main_qml)))

        if not self.engine.rootObjects():
            sys.exit(-1)

    def handle_sigint(self):
        print("\nClosing application...")
        backends["downloaderBackend"].shutdown()
        self.app.quit()

    def run(self):
        timer = QTimer()
        timer.timeout.connect(lambda: None)
        timer.start(100)

        return self.app.exec()


if __name__ == "__main__":
    app = Anime365()
    sys.exit(app.run())
