from pathlib import Path

# TODO: add extra checks for pyinstaller
SRC_DIR = Path(__file__).parent
QML_DIR = SRC_DIR / "qml"
LOG_DIR = SRC_DIR.parent / "logs"


def create_dirs():
    if not LOG_DIR.exists():
        LOG_DIR.mkdir()
