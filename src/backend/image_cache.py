from pathlib import Path
from typing import TYPE_CHECKING

import aiohttp
from PySide6.QtCore import QObject, QUrl, Signal, Slot

from constants import IMG_CACHE_DIR

from .utils import AsyncFunctionWorker

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
                        return ""  # Don't try to load failed URLs
                    image_bytes = await response.read()
                    with self.save_path.open("wb") as file:
                        file.write(image_bytes)
                    return QUrl.fromLocalFile(str(self.save_path)).toString()
        except Exception:
            return ""  # Don't try to load failed URLs


class Backend(QObject):
    image_downloaded = Signal(str, str)  # (original_url, local_url)

    def __init__(self, settings):
        super().__init__()
        self.settings = settings
        self.workers = []

    @Slot(str, result=str)
    def cache_image(self, url: str) -> str:
        if not url:
            return ""
        filename = url.split("/")[-1]
        save_path = IMG_CACHE_DIR / filename
        if save_path.exists():
            return QUrl.fromLocalFile(str(save_path)).toString()

        worker = DownloadImageWorker(url, save_path, self.settings)
        self.workers.append(worker)

        def on_result(local_url, orig=url):
            if local_url:  # Only emit if download succeeded
                self.image_downloaded.emit(orig, local_url)

        def on_completed(w=worker):
            if w in self.workers:
                self.workers.remove(w)

        worker.result_str.connect(on_result)
        worker.completed.connect(on_completed)
        worker.start()

        return ""
