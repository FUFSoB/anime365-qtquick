# main.py
import sys
import signal
from pathlib import Path
from PySide6.QtCore import QUrl, QTimer
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication
from backend import Backend


class Anime365:
    def __init__(self):
        signal.signal(signal.SIGINT, lambda *args: self.handle_sigint())

        self.app = QApplication(sys.argv)
        self.engine = QQmlApplicationEngine()

        # Create backend instance
        self.backend = Backend()

        # Register the backend to QML
        self.engine.rootContext().setContextProperty("backend", self.backend)

        # Set up QML file paths
        qml_dir = Path(__file__).parent / "qml"
        main_qml = qml_dir / "main.qml"

        # Load main QML file
        self.engine.load(QUrl.fromLocalFile(str(main_qml)))

        if not self.engine.rootObjects():
            sys.exit(-1)

    def handle_sigint(self):
        print("\nClosing application...")
        self.app.quit()

    def run(self):
        # Process SIGINT events
        timer = QTimer()
        timer.timeout.connect(lambda: None)  # Let Python process signals
        timer.start(100)

        return self.app.exec()


if __name__ == "__main__":
    app = Anime365()
    sys.exit(app.run())
