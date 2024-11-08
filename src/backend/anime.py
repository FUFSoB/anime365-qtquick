import asyncio
import json
import os
import shutil
from PySide6.QtCore import QObject, Slot, Signal

from constants import SETTINGS_FILE

from .net import Api
from .utils import AsyncFunctionWorker


class Backend(QObject):
    token_checked = Signal(bool)

    def __init__(self, settings):
        super().__init__()
        self.settings = settings
        self.worker = None
        self.api = Api(self)

    @Slot(str)
    def select_episode(self, episode_id: str):
        print(episode_id)
