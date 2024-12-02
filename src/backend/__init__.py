import subprocess
from PySide6.QtCore import QObject, Slot

from .settings import Backend as SettingsBackend
from .database import Backend as DatabaseBackend
from .search import Backend as SearchBackend
from .anime import Backend as AnimeBackend
from .image_cache import Backend as ImageCacheBackend


settings = SettingsBackend()


backends = {
    "settingsBackend": settings,
    "databaseBackend": DatabaseBackend(),
    "searchBackend": SearchBackend(settings),
    "animeBackend": AnimeBackend(settings),
    "imageCacheBackend": ImageCacheBackend(settings),
}
