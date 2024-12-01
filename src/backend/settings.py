import json
import os
import shutil
from PySide6.QtCore import QObject, Slot, Signal

from constants import SETTINGS_FILE

from .net import Api
from .utils import AsyncFunctionWorker


class Backend(QObject):
    EmptyValue = object()

    token_checked = Signal(bool)
    shiki_token_checked = Signal(bool)

    def __init__(self):
        super().__init__()
        self._settings = None
        self.worker = None
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
            self._settings = {}

        return self._settings

    @Slot(result=dict)
    def get_defaults(self):
        return {
            # behavior
            # binary paths
            "mpv_path": shutil.which("mpv") or "",
            "uget_path": shutil.which("uget-gtk") or shutil.which("uget") or "",
            # tokens
            "anime365_token": "",
            "shikimori_token": "",
            # not in UI
            "proxy": "",
            "anime365_site": "https://anime365.ru",
            "hentai365_site": "https://hentai365.ru",
            "shikimori_site": "https://shikimori.one",
        }

    @Slot(dict)
    def save_settings(self, settings: dict[str, str]):
        self._settings = settings

        settings["mpv_path"] = shutil.which(settings["mpv_path"])
        settings["uget_path"] = shutil.which(settings["uget_path"])

        with SETTINGS_FILE.open("w") as file:
            json.dump(settings, file, indent=4, ensure_ascii=False)

    @Slot(str, result=bool)
    def is_valid_binary(self, path: str) -> bool:
        shutil_path = shutil.which(path)
        is_executable = shutil_path and os.access(shutil_path, os.X_OK) or False

        return is_executable

    @Slot(str)
    def is_valid_token(self, token):
        self.worker = AsyncFunctionWorker(self.api.check_token, token)
        self.worker.result_bool.connect(self.token_checked.emit)
        self.worker.start()

    @Slot(str)
    def is_valid_shiki_token(self, token):
        self.worker = AsyncFunctionWorker(self.api.shiki_check_token, token)
        self.worker.result_bool.connect(self.shiki_token_checked.emit)
        self.worker.start()
