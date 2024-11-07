import subprocess
from PySide6.QtCore import QObject, Slot

from .search import Backend as SearchBackend
from .settings import Backend as SettingsBackend


settings = SettingsBackend()


class Backend(QObject):
    def __init__(self, settings):
        super().__init__()
        self.settings = settings

    @Slot()
    def open_uget(self):
        subprocess.Popen([self.settings.uget_path])


backends = {
    "settingsBackend": settings,
    "searchBackend": SearchBackend(settings),
    "backend": Backend(settings),
}
