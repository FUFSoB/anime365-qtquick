# main.py
import sys
import signal
from pathlib import Path
from PySide6.QtCore import QUrl, QTimer
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from backend import backends
from constants import create_dirs


class Anime365:
    def __init__(self):
        signal.signal(signal.SIGINT, lambda *args: self.handle_sigint())

        self.app = QApplication(sys.argv)
        self.engine = QQmlApplicationEngine()

        for name, backend in backends.items():
            self.engine.rootContext().setContextProperty(name, backend)

        qml_dir = Path(__file__).parent / "qml"
        main_qml = qml_dir / "main.qml"

        self.engine.load(QUrl.fromLocalFile(str(main_qml)))

        if not self.engine.rootObjects():
            sys.exit(-1)

    def handle_sigint(self):
        print("\nClosing application...")
        self.app.quit()

    def run(self):
        timer = QTimer()
        timer.timeout.connect(lambda: None)
        timer.start(100)

        return self.app.exec()


if __name__ == "__main__":
    create_dirs()
    app = Anime365()
    sys.exit(app.run())
