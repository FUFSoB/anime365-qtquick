import subprocess
from PySide6.QtCore import QObject, Slot

from .settings import Backend as SettingsBackend
from .database import Backend as DatabaseBackend
from .search import Backend as SearchBackend
from .anime import Backend as AnimeBackend
from .image_cache import Backend as ImageCacheBackend


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
    "databaseBackend": DatabaseBackend(),
    "searchBackend": SearchBackend(settings),
    "animeBackend": AnimeBackend(settings),
    "imageCacheBackend": ImageCacheBackend(settings),
    "backend": Backend(settings),
}
