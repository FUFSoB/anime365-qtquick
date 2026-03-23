import os
import sys
from pathlib import Path

APP_NAME = "anime365"

from importlib.metadata import version, PackageNotFoundError
try:
    APP_VERSION = version("anime365-qtquick")
except PackageNotFoundError:
    APP_VERSION = "0.0.0"
FROZEN = getattr(sys, "frozen", False)
IS_ANDROID = hasattr(sys, "getandroidapilevel")

# --- Resource paths (QML, bundled assets) ---

if FROZEN:
    SRC_DIR = Path(sys._MEIPASS)
else:
    SRC_DIR = Path(__file__).parent  # src/

QML_DIR = SRC_DIR / "qml"

# --- User data paths: always OS-standard, dev or packaged ---


def _get_config_dir() -> Path:
    """Settings / config files."""
    if IS_ANDROID:
        return _get_data_dir()
    if sys.platform == "win32":
        return Path(os.environ.get("APPDATA", Path.home())) / APP_NAME
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Preferences" / APP_NAME
    else:
        return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / APP_NAME


def _get_data_dir() -> Path:
    """Database and other persistent data."""
    if IS_ANDROID:
        # External app-specific dir: accessible via file manager / ADB without root.
        # $EXTERNAL_STORAGE is typically /storage/emulated/0 or /sdcard.
        ext = os.environ.get("EXTERNAL_STORAGE", "/storage/emulated/0")
        return Path(ext) / "Android" / "data" / f"org.{APP_NAME}.app" / "files"
    if sys.platform == "win32":
        return Path(os.environ.get("APPDATA", Path.home())) / APP_NAME
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / APP_NAME
    else:
        return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / APP_NAME


def _get_cache_dir() -> Path:
    if IS_ANDROID:
        return _get_data_dir() / "cache"
    if sys.platform == "win32":
        return Path(os.environ.get("LOCALAPPDATA", Path.home())) / APP_NAME / "cache"
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Caches" / APP_NAME
    else:
        return Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / APP_NAME


CONFIG_DIR = _get_config_dir()
DATA_DIR = _get_data_dir()
CACHE_DIR = _get_cache_dir()

SETTINGS_FILE = CONFIG_DIR / "settings.json"
DATABASE_FILE = DATA_DIR / "anime.db"

# Legacy paths (project-root dev layout) — used only for one-time migration
_PROJECT_ROOT = Path(__file__).parent.parent
LEGACY_SETTINGS_FILE = _PROJECT_ROOT / "settings.json"
LEGACY_DATABASE_FILE = _PROJECT_ROOT / "database.json"

DOWNLOADS_DIR = DATA_DIR / "downloads"
IMG_CACHE_DIR = CACHE_DIR / "images"


def create_dirs():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    DOWNLOADS_DIR.mkdir(exist_ok=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    IMG_CACHE_DIR.mkdir(exist_ok=True)
