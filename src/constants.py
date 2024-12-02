from pathlib import Path

# TODO: add extra checks for pyinstaller
SRC_DIR = Path(__file__).parent  # src/
QML_DIR = SRC_DIR / "qml"
LOG_DIR = SRC_DIR.parent / "logs"
DOWNLOADS_DIR = SRC_DIR.parent / "downloads"
SETTINGS_FILE = SRC_DIR.parent / "settings.json"
DATABASE_FILE = SRC_DIR.parent / "database.json"

CACHE_DIR = SRC_DIR.parent / "cache"
IMG_CACHE_DIR = CACHE_DIR / "images"
# Path(QStandardPaths.writableLocation(QStandardPaths.CacheLocation)) / "Anime365" / "images"


def create_dirs():
    LOG_DIR.mkdir(exist_ok=True)
    DOWNLOADS_DIR.mkdir(exist_ok=True)
    CACHE_DIR.mkdir(exist_ok=True)
    IMG_CACHE_DIR.mkdir(exist_ok=True)
