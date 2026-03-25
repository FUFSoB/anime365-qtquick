import os
import sys
from pathlib import Path

APP_NAME = "anime365"

from importlib.metadata import PackageNotFoundError, version

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
    if IS_ANDROID:
        return _get_data_dir()
    if sys.platform == "win32":
        return Path(os.environ.get("APPDATA", Path.home())) / APP_NAME
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Preferences" / APP_NAME
    else:
        return (
            Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / APP_NAME
        )


def _get_data_dir() -> Path:
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
        return (
            Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
            / APP_NAME
        )


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


def _get_downloads_dir() -> Path:
    if IS_ANDROID:
        ext = os.environ.get("EXTERNAL_STORAGE", "/storage/emulated/0")
        return Path(ext) / "Download"
    if sys.platform == "win32":
        # Windows: use the known folder, fallback to ~/Downloads
        import ctypes.wintypes

        CSIDL_PROFILE = 0x0028
        buf = ctypes.create_unicode_buffer(ctypes.wintypes.MAX_PATH)
        ctypes.windll.shell32.SHGetFolderPathW(None, CSIDL_PROFILE, None, 0, buf)
        return Path(buf.value) / "Downloads" if buf.value else Path.home() / "Downloads"
    elif sys.platform == "darwin":
        return Path.home() / "Downloads"
    else:
        # Linux: read XDG user dirs
        xdg_dirs = Path.home() / ".config" / "user-dirs.dirs"
        if xdg_dirs.exists():
            import re

            text = xdg_dirs.read_text()
            m = re.search(r'XDG_DOWNLOAD_DIR="(.+?)"', text)
            if m:
                return Path(m.group(1).replace("$HOME", str(Path.home())))
        return Path.home() / "Downloads"


DOWNLOADS_DIR = _get_downloads_dir() / "Anime365"
IMG_CACHE_DIR = CACHE_DIR / "images"


def create_dirs():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    IMG_CACHE_DIR.mkdir(exist_ok=True)
