import asyncio
import json
import os
import shutil
from PySide6.QtCore import QObject, Slot, QThread, Signal

from constants import SETTINGS_FILE

from .net import Api


class Worker(QThread):
    result = Signal(bool)

    def __init__(self, func, *args, **kwargs):
        super().__init__()
        self.func = func
        self.args = args
        self.kwargs = kwargs

    def run(self):
        self.result.emit(asyncio.run(self.func(*self.args, **self.kwargs)))


class Backend(QObject):
    EmptyValue = object()

    token_checked = Signal(bool)

    def __init__(self):
        super().__init__()
        self.settings = None
        self.worker = None
        self.api = Api(self)

    def __getattr__(self, item):
        value = self.get_settings().get(item, self.EmptyValue)
        if value is self.EmptyValue:
            raise AttributeError(f"Attribute {item} not found")
        return value

    @Slot(result=dict)
    def get_settings(self):
        if self.settings is not None:
            return self.settings

        try:
            with SETTINGS_FILE.open() as file:
                self.settings = json.load(file)
        except FileNotFoundError:
            self.settings = {}

        return self.settings

    @Slot(result=dict)
    def get_defaults(self):
        return {
            "mpv_path": shutil.which("mpv") or "",
            "uget_path": shutil.which("uget-gtk") or shutil.which("uget") or "",
            "anime365_token": "",
        }

    @Slot(dict)
    def save_settings(self, settings: dict[str, str]):
        self.settings = settings

        settings["mpv_path"] = shutil.which(settings["mpv_path"])
        settings["uget_path"] = shutil.which(settings["uget_path"])

        with SETTINGS_FILE.open("w") as file:
            json.dump(settings, file, indent=4, ensure_ascii=False)

    @Slot(str, result=bool)
    def is_valid_binary(self, path):
        shutil_path = shutil.which(path) or False
        return shutil_path and os.access(shutil_path, os.X_OK)

    @Slot(str, result=bool)
    def is_valid_token(self, token):
        self.worker = Worker(self.api.check_token, token)
        self.worker.result.connect(self.handle_token_checked)
        self.worker.start()

    def handle_token_checked(self, result):
        self.token_checked.emit(result)
