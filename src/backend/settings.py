import json
import os
import shutil

from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtGui import QColor, QPalette
from PySide6.QtWidgets import QApplication


def _dark_palette() -> QPalette:
    p = QPalette()
    p.setColor(QPalette.ColorRole.Window, QColor(38, 38, 38))  # main surface
    p.setColor(QPalette.ColorRole.WindowText, QColor(228, 228, 228))  # primary text
    p.setColor(QPalette.ColorRole.Base, QColor(24, 24, 24))  # input / list bg
    p.setColor(
        QPalette.ColorRole.AlternateBase, QColor(50, 50, 50)
    )  # alternate rows / strips
    p.setColor(QPalette.ColorRole.Text, QColor(228, 228, 228))
    p.setColor(QPalette.ColorRole.Button, QColor(60, 60, 60))  # raised button bg
    p.setColor(QPalette.ColorRole.ButtonText, QColor(228, 228, 228))
    p.setColor(QPalette.ColorRole.BrightText, QColor(255, 100, 100))
    p.setColor(QPalette.ColorRole.Highlight, QColor(42, 130, 218))
    p.setColor(
        QPalette.ColorRole.HighlightedText, QColor(255, 255, 255)
    )  # white on blue (was black)
    p.setColor(QPalette.ColorRole.Link, QColor(80, 160, 240))
    p.setColor(QPalette.ColorRole.ToolTipBase, QColor(50, 50, 50))
    p.setColor(QPalette.ColorRole.ToolTipText, QColor(228, 228, 228))
    p.setColor(QPalette.ColorRole.PlaceholderText, QColor(140, 140, 140))
    p.setColor(QPalette.ColorRole.Mid, QColor(75, 75, 75))  # borders / separators
    p.setColor(QPalette.ColorRole.Midlight, QColor(95, 95, 95))  # hover surfaces
    p.setColor(QPalette.ColorRole.Dark, QColor(28, 28, 28))
    p.setColor(QPalette.ColorRole.Shadow, QColor(12, 12, 12))
    for role in (
        QPalette.ColorRole.WindowText,
        QPalette.ColorRole.Text,
        QPalette.ColorRole.ButtonText,
    ):
        p.setColor(QPalette.ColorGroup.Disabled, role, QColor(105, 105, 105))
    return p


def _light_palette() -> QPalette:
    p = QPalette()
    p.setColor(QPalette.ColorRole.Window, QColor(242, 242, 242))  # main surface
    p.setColor(
        QPalette.ColorRole.WindowText, QColor(15, 15, 15)
    )  # primary text (near-black)
    p.setColor(QPalette.ColorRole.Base, QColor(255, 255, 255))
    p.setColor(
        QPalette.ColorRole.AlternateBase, QColor(232, 232, 236)
    )  # alternate rows
    p.setColor(QPalette.ColorRole.Text, QColor(15, 15, 15))
    p.setColor(
        QPalette.ColorRole.Button, QColor(218, 218, 218)
    )  # visibly distinct from Window
    p.setColor(QPalette.ColorRole.ButtonText, QColor(15, 15, 15))
    p.setColor(QPalette.ColorRole.BrightText, QColor(200, 0, 0))
    p.setColor(QPalette.ColorRole.Highlight, QColor(0, 110, 205))
    p.setColor(QPalette.ColorRole.HighlightedText, QColor(255, 255, 255))
    p.setColor(QPalette.ColorRole.Link, QColor(0, 90, 200))
    p.setColor(QPalette.ColorRole.ToolTipBase, QColor(255, 255, 210))
    p.setColor(QPalette.ColorRole.ToolTipText, QColor(15, 15, 15))
    p.setColor(QPalette.ColorRole.PlaceholderText, QColor(148, 148, 148))
    p.setColor(QPalette.ColorRole.Mid, QColor(145, 145, 145))  # borders
    p.setColor(QPalette.ColorRole.Midlight, QColor(196, 196, 196))  # hover
    p.setColor(
        QPalette.ColorRole.Dark, QColor(110, 110, 110)
    )  # actually darker than Mid
    p.setColor(QPalette.ColorRole.Shadow, QColor(68, 68, 68))  # deeper shadow
    for role in (
        QPalette.ColorRole.WindowText,
        QPalette.ColorRole.Text,
        QPalette.ColorRole.ButtonText,
    ):
        p.setColor(QPalette.ColorGroup.Disabled, role, QColor(148, 148, 148))
    return p


from constants import IS_ANDROID, LEGACY_SETTINGS_FILE, SETTINGS_FILE

from .net import Api
from .utils import AsyncFunctionWorker


class Backend(QObject):
    EmptyValue = object()

    token_checked = Signal(bool)
    proxy_checked = Signal(bool)

    def __init__(self):
        super().__init__()
        self._settings = None
        self._workers = []
        self.api = Api(self)

    def __getattr__(self, item):
        value = self.get_settings().get(item, self.EmptyValue)
        if value is self.EmptyValue:
            raise AttributeError(f"Attribute {item} not found")
        if item in ("mpv_path", "vlc_path", "aria2c_path") and not value:
            return shutil.which(item.split("_")[0]) or ""
        return value

    @Slot(str, result=str)
    def get(self, key: str) -> str:
        value = self.get_settings().get(key, "")
        if key in ("mpv_path", "vlc_path", "aria2c_path") and not value:
            return shutil.which(key.split("_")[0]) or ""
        return value

    @Slot(result=dict)
    def get_settings(self):
        if self._settings is not None:
            return self._settings

        try:
            with SETTINGS_FILE.open() as file:
                loaded = json.load(file)
            self._settings = self.get_defaults() | loaded
            if loaded != self._settings:
                self.save_settings(self._settings)
        except FileNotFoundError:
            self._settings = self.get_defaults()
            self._migrate_legacy_settings()

        return self._settings

    @Slot(result=dict)
    def get_defaults(self):
        return {
            # binary paths
            "mpv_path": shutil.which("mpv") or "",
            "vlc_path": shutil.which("vlc") or "",
            "aria2c_path": shutil.which("aria2c") or "",
            # extra command line arguments
            "mpv_args": "",
            "vlc_args": "",
            "aria2c_args": "",
            # behavior
            "discord_rpc": True,
            "check_updates": True,
            "download_threads": 4,
            # tokens
            "anime365_token": "",
            # not in UI
            "theme": "",
            "proxy": "",
            "anime365_site": "https://smotret-anime.org",
            "hentai365_site": "https://h365-art.org",
        }

    def _migrate_legacy_settings(self):
        if LEGACY_SETTINGS_FILE.exists():
            try:
                with LEGACY_SETTINGS_FILE.open() as f:
                    legacy = json.load(f)
                self._settings = self.get_defaults() | legacy
                self.save_settings(self._settings)
                LEGACY_SETTINGS_FILE.rename(
                    LEGACY_SETTINGS_FILE.with_suffix(".json.migrated")
                )
            except Exception:
                pass

    @Slot(dict)
    def save_settings(self, settings: dict[str, str]):
        self._settings = settings

        if not IS_ANDROID:
            for key, binary in (
                ("mpv_path", "mpv"),
                ("vlc_path", "vlc"),
                ("aria2c_path", "aria2c"),
            ):
                val = settings.get(key, "")
                if val == (shutil.which(binary) or ""):
                    settings[key] = ""
                else:
                    settings[key] = shutil.which(val) or val

        with SETTINGS_FILE.open("w") as file:
            json.dump(settings, file, indent=4, ensure_ascii=False)

    @Slot(str, result=bool)
    def is_valid_binary(self, path: str) -> bool:
        if IS_ANDROID:
            return True
        shutil_path = shutil.which(path)
        is_executable = shutil_path and os.access(shutil_path, os.X_OK) or False

        return is_executable

    def _run_worker(self, worker):
        self._workers.append(worker)
        worker.finished.connect(
            lambda w=worker: self._workers.remove(w) if w in self._workers else None
        )
        worker.start()

    @Slot(str)
    def is_valid_proxy(self, proxy_url):
        worker = AsyncFunctionWorker(self.api.check_proxy, proxy_url)
        worker.result_bool.connect(self.proxy_checked.emit)
        self._run_worker(worker)

    @Slot(str)
    def is_valid_token(self, token):
        worker = AsyncFunctionWorker(self.api.check_token, token)
        worker.result_bool.connect(self.token_checked.emit)
        self._run_worker(worker)

    @Slot(str)
    def apply_theme(self, theme: str):
        if theme == "dark":
            QApplication.setPalette(_dark_palette())
        elif theme == "light":
            QApplication.setPalette(_light_palette())
        else:
            # "auto" — restore the default palette derived from the system/style
            QApplication.setPalette(QApplication.style().standardPalette())
