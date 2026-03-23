import json
import os
import shutil
from PySide6.QtCore import QObject, Slot, Signal
from PySide6.QtGui import QColor, QPalette
from PySide6.QtWidgets import QApplication


def _dark_palette() -> QPalette:
    p = QPalette()
    p.setColor(QPalette.ColorRole.Window,          QColor(45,  45,  45))
    p.setColor(QPalette.ColorRole.WindowText,      QColor(220, 220, 220))
    p.setColor(QPalette.ColorRole.Base,            QColor(30,  30,  30))
    p.setColor(QPalette.ColorRole.AlternateBase,   QColor(45,  45,  45))
    p.setColor(QPalette.ColorRole.Text,            QColor(220, 220, 220))
    p.setColor(QPalette.ColorRole.Button,          QColor(53,  53,  53))
    p.setColor(QPalette.ColorRole.ButtonText,      QColor(220, 220, 220))
    p.setColor(QPalette.ColorRole.BrightText,      QColor(255, 100, 100))
    p.setColor(QPalette.ColorRole.Highlight,       QColor(42,  130, 218))
    p.setColor(QPalette.ColorRole.HighlightedText, QColor(0,   0,   0))
    p.setColor(QPalette.ColorRole.Link,            QColor(42,  130, 218))
    p.setColor(QPalette.ColorRole.ToolTipBase,     QColor(30,  30,  30))
    p.setColor(QPalette.ColorRole.ToolTipText,     QColor(220, 220, 220))
    p.setColor(QPalette.ColorRole.PlaceholderText, QColor(127, 127, 127))
    p.setColor(QPalette.ColorRole.Mid,             QColor(80,  80,  80))
    p.setColor(QPalette.ColorRole.Midlight,        QColor(90,  90,  90))
    p.setColor(QPalette.ColorRole.Dark,            QColor(35,  35,  35))
    p.setColor(QPalette.ColorRole.Shadow,          QColor(20,  20,  20))
    for role in (QPalette.ColorRole.WindowText, QPalette.ColorRole.Text,
                 QPalette.ColorRole.ButtonText):
        p.setColor(QPalette.ColorGroup.Disabled, role, QColor(127, 127, 127))
    return p


def _light_palette() -> QPalette:
    p = QPalette()
    p.setColor(QPalette.ColorRole.Window,          QColor(240, 240, 240))
    p.setColor(QPalette.ColorRole.WindowText,      QColor(0,   0,   0))
    p.setColor(QPalette.ColorRole.Base,            QColor(255, 255, 255))
    p.setColor(QPalette.ColorRole.AlternateBase,   QColor(233, 231, 227))
    p.setColor(QPalette.ColorRole.Text,            QColor(0,   0,   0))
    p.setColor(QPalette.ColorRole.Button,          QColor(240, 240, 240))
    p.setColor(QPalette.ColorRole.ButtonText,      QColor(0,   0,   0))
    p.setColor(QPalette.ColorRole.BrightText,      QColor(255, 0,   0))
    p.setColor(QPalette.ColorRole.Highlight,       QColor(0,   120, 215))
    p.setColor(QPalette.ColorRole.HighlightedText, QColor(255, 255, 255))
    p.setColor(QPalette.ColorRole.Link,            QColor(0,   0,   255))
    p.setColor(QPalette.ColorRole.ToolTipBase,     QColor(255, 255, 220))
    p.setColor(QPalette.ColorRole.ToolTipText,     QColor(0,   0,   0))
    p.setColor(QPalette.ColorRole.PlaceholderText, QColor(160, 160, 160))
    p.setColor(QPalette.ColorRole.Mid,             QColor(160, 160, 160))
    p.setColor(QPalette.ColorRole.Midlight,        QColor(200, 200, 200))
    p.setColor(QPalette.ColorRole.Dark,            QColor(160, 160, 160))
    p.setColor(QPalette.ColorRole.Shadow,          QColor(105, 105, 105))
    for role in (QPalette.ColorRole.WindowText, QPalette.ColorRole.Text,
                 QPalette.ColorRole.ButtonText):
        p.setColor(QPalette.ColorGroup.Disabled, role, QColor(120, 120, 120))
    return p

from constants import SETTINGS_FILE, LEGACY_SETTINGS_FILE, IS_ANDROID

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
        return value

    @Slot(str, result=str)
    def get(self, key: str) -> str:
        return self.get_settings().get(key, "")

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
            # behavior
            # binary paths
            "mpv_path": shutil.which("mpv") or "",
            "vlc_path": shutil.which("vlc") or "",
            "uget_path": shutil.which("uget-gtk") or shutil.which("uget") or "",
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
                LEGACY_SETTINGS_FILE.rename(LEGACY_SETTINGS_FILE.with_suffix(".json.migrated"))
            except Exception:
                pass

    @Slot(dict)
    def save_settings(self, settings: dict[str, str]):
        self._settings = settings

        if not IS_ANDROID:
            settings["mpv_path"] = shutil.which(settings.get("mpv_path", "")) or ""
            settings["vlc_path"] = shutil.which(settings.get("vlc_path", "")) or ""
            settings["uget_path"] = shutil.which(settings.get("uget_path", "")) or ""

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
        worker.finished.connect(lambda w=worker: self._workers.remove(w) if w in self._workers else None)
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

