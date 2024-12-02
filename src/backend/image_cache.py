from pathlib import Path

import aiohttp
from PySide6.QtCore import QObject, Slot, Signal, QUrl

from constants import IMG_CACHE_DIR
from .utils import AsyncFunctionWorker

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend


class DownloadImageWorker(AsyncFunctionWorker):
    def __init__(self, url: str, save_path: Path, settings: "SettingsBackend"):
        super().__init__(self.download_image)
        self.url = url
        self.save_path = save_path
        self.api = settings.api

    async def download_image(self):
        try:
            async with aiohttp.ClientSession(
                connector=await self.api.get_connector()
            ) as session:
                async with session.get(self.url) as response:
                    if response.status != 200:
                        raise Exception(f"Failed to download image: {response.status}")
                    image_bytes = await response.read()
                    with self.save_path.open("wb") as file:
                        file.write(image_bytes)
                    return QUrl.fromLocalFile(self.save_path).toString()
        except Exception:
            return self.url


class Backend(QObject):
    # TODO: Signal is not used
    image_downloaded = Signal(str)

    def __init__(self, settings):
        super().__init__()
        self.settings = settings
        self.workers = []

    @Slot(str, result=str)
    def cache_image(self, url: str) -> str:
        filename = url.split("/")[-1]
        save_path = IMG_CACHE_DIR / filename
        if save_path.exists():
            return QUrl.fromLocalFile(str(save_path)).toString()

        worker = DownloadImageWorker(url, save_path, self.settings)
        self.workers.append(worker)
        worker.start()
        worker.result_str.connect(self.image_downloaded.emit)
        worker.completed.connect(lambda *_: self.workers.remove(worker))

        return url
