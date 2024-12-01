import json
from PySide6.QtCore import QObject, Slot, Signal

from constants import LOG_DIR
from .utils import AsyncFunctionWorker

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend


class Worker(AsyncFunctionWorker):
    def __init__(self, query: str, settings: "SettingsBackend"):
        super().__init__(self.perform_search_operation)
        self.query = query
        self.api = settings.api

    @staticmethod
    def _create_search_result(item: dict) -> dict:
        title = (
            item["titles"].get("romaji")
            or item["titles"].get("en")
            or item["titles"].get("ru")
            or item["titles"].get("ja")
        )

        score = item.get("myAnimeListScore")
        if score == "-1":
            score = "N/A"

        description = ""
        if item.get("descriptions"):
            description = (
                f"{item['descriptions'][0]['value']}\n\n"
                f"Source: {item['descriptions'][0]['source']}"
            )

        genres = ", ".join(i["title"] for i in item.get("genres", []))

        episode_list = ";".join(i["episodeFull"] for i in item.get("episodes", []))
        episode_ids = ";".join(str(i["id"]) for i in item.get("episodes", []))

        return dict(
            id=item["id"],
            title=title,
            titles=item["titles"],
            total_episodes=item["numberOfEpisodes"],
            episode_list=episode_list,
            episode_ids=episode_ids,
            image_url=item["posterUrl"],
            type=item["type"],
            score=score,
            year=int(item["year"]),
            hentai=item["isHentai"],
            h_type="hentai" if item["isHentai"] else item["type"],
            description=description,
            genres=genres,
        )

    async def perform_search_operation(self):
        raw_results = await self.api.find_anime(self.query)
        return [
            self._create_search_result(item)
            for item in sorted(raw_results, key=lambda x: x["year"], reverse=True)
            if item["isActive"] != -1
        ]


class Backend(QObject):
    search_completed = Signal(list)
    search_error = Signal(str)

    def __init__(self, settings: "SettingsBackend"):
        super().__init__()
        self.search_worker = None
        self.settings = settings

    @Slot(str)
    def perform_search(self, query: str):
        if self.search_worker and self.search_worker.isRunning():
            self.search_worker.terminate()
        self.search_worker = Worker(query, self.settings)
        self.search_worker.result_list.connect(self.search_completed.emit)
        self.search_worker.error.connect(self.search_error.emit)
        self.search_worker.start()
