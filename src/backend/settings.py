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

    @Slot(result=dict)
    def get_settings(self):
        if self._settings is not None:
            return self._settings

        try:
            with SETTINGS_FILE.open() as file:
                self._settings = json.load(file)
        except FileNotFoundError:
            self._settings = {}

        return self._settings

    @Slot(result=dict)
    def get_defaults(self):
        return {
            "mpv_path": shutil.which("mpv") or "",
            "uget_path": shutil.which("uget-gtk") or shutil.which("uget") or "",
            "anime365_token": "",
        }

    @Slot(dict)
    def save_settings(self, settings: dict[str, str]):
        self._settings = settings

        settings["mpv_path"] = shutil.which(settings["mpv_path"])
        settings["uget_path"] = shutil.which(settings["uget_path"])

        with SETTINGS_FILE.open("w") as file:
            json.dump(settings, file, indent=4, ensure_ascii=False)

    @Slot(str, result=bool)
    def is_valid_binary(self, path):
        shutil_path = shutil.which(path) or False
        return shutil_path and os.access(shutil_path, os.X_OK)

    @Slot(str)
    def is_valid_token(self, token):
        self.worker = AsyncFunctionWorker(self.api.check_token, token)
        self.worker.result_bool.connect(self.handle_token_checked)
        self.worker.start()

    def handle_token_checked(self, result):
        self.token_checked.emit(result)
