from typing import TYPE_CHECKING

from PySide6.QtCore import QObject, Signal, Slot

from .utils import AsyncFunctionWorker

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend


class Worker(AsyncFunctionWorker):
    def __init__(self, query: str, settings: "SettingsBackend"):
        super().__init__(self.perform_search_operation)
        self.query = query
        self.api = settings.api

    @staticmethod
    def _create_search_result(item: dict) -> dict:
        titles = item.get("titles") or {}
        title = (
            titles.get("romaji")
            or titles.get("en")
            or titles.get("ru")
            or titles.get("ja")
            or item.get("title")
            or "Unknown"
        )

        score = item.get("myAnimeListScore")
        if score == "-1":
            score = "N/A"

        description = ""
        descriptions = item.get("descriptions") or []
        if descriptions:
            description = (
                f"{descriptions[0]['value']}\n\nSource: {descriptions[0]['source']}"
            )

        genres = ", ".join(i["title"] for i in (item.get("genres") or []))

        episodes = item.get("episodes") or []
        episode_list = ";".join(i["episodeFull"] for i in episodes)
        episode_ids = ";".join(str(i["id"]) for i in episodes)

        return dict(
            id=str(item["id"]),
            title=title,
            titles=titles,
            total_episodes=item["numberOfEpisodes"],
            episode_list=episode_list,
            episode_ids=episode_ids,
            image_url=item["posterUrl"],
            type=item["type"],
            score=score,
            year=int(item["year"]),
            hentai=bool(item["isHentai"]),
            h_type="hentai" if item["isHentai"] else item["type"],
            description=description,
            genres=genres,
            mal_id=item.get("myAnimeListId", 0) or 0,
            world_art_id=item.get("worldArtId", 0) or 0,
            anidb_id=item.get("aniDbId", 0) or 0,
            ann_id=item.get("animeNewsNetworkId", 0) or 0,
            anime365_url=item.get("url", ""),
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
    search_cancelled = Signal()

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

    @Slot()
    def cancel_search(self):
        if self.search_worker and self.search_worker.isRunning():
            self.search_worker.terminate()
            self.search_worker = None
            self.search_cancelled.emit()
