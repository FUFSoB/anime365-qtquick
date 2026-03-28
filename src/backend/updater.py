from typing import TYPE_CHECKING

import aiohttp
from PySide6.QtCore import QObject, Signal, Slot

from constants import APP_VERSION, FROZEN

from .utils import AsyncFunctionWorker

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend

RELEASES_URL = "https://api.github.com/repos/FUFSoB/anime365-qtquick/releases/latest"


def _parse_version(tag: str) -> tuple:
    clean = tag.lstrip("v")
    try:
        return tuple(int(x) for x in clean.split("."))
    except ValueError:
        return (0,)


class Backend(QObject):
    update_found = Signal(str, str, str)  # new_version_tag, release_url, current_version

    def __init__(self, settings: "SettingsBackend"):
        super().__init__()
        self.settings = settings
        self._worker = None

    @Slot()
    def check(self):
        if not FROZEN:
            return

        async def _do_check():
            headers = {"User-Agent": "anime365-qtquick"}
            connector = await self.settings.api.get_connector()
            async with aiohttp.ClientSession(connector=connector) as session:
                async with session.get(RELEASES_URL, headers=headers) as response:
                    if response.status != 200:
                        return {}
                    return await response.json()

        self._worker = AsyncFunctionWorker(_do_check)
        self._worker.result_dict.connect(self._on_result)
        self._worker.start()

    def _on_result(self, data: dict):
        tag = data.get("tag_name", "")
        html_url = data.get("html_url", "")
        if not tag:
            return
        if _parse_version(tag) > _parse_version(APP_VERSION):
            self.update_found.emit(tag, html_url, APP_VERSION)
