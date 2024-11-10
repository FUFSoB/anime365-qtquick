from pathlib import Path

# TODO: add extra checks for pyinstaller
SRC_DIR = Path(__file__).parent  # src/
QML_DIR = SRC_DIR / "qml"
LOG_DIR = SRC_DIR.parent / "logs"
DOWNLOADS_DIR = SRC_DIR.parent / "downloads"
SETTINGS_FILE = SRC_DIR.parent / "settings.json"


def create_dirs():
    if not LOG_DIR.exists():
        LOG_DIR.mkdir()
    if not DOWNLOADS_DIR.exists():
        DOWNLOADS_DIR.mkdir()
