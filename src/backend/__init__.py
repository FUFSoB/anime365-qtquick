import subprocess
from PySide6.QtCore import QObject, Slot

from .search import Backend as SearchBackend


class Backend(QObject):
    def __init__(self):
        super().__init__()

    @Slot()
    def open_uget(self):
        subprocess.Popen(["uget-gtk"])


backends = {
    "searchBackend": SearchBackend(),
    "backend": Backend(),
}
