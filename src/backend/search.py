import asyncio
import aiohttp
import json
from dataclasses import dataclass, asdict
from PySide6.QtCore import QObject, Slot, Signal, QThread

from constants import LOG_DIR


@dataclass
class AnimeSearchResult:
    id: int
    title: str
    episodes: int
    episode_list: list[dict]
    image_url: str
    type: str
    score: float
    year: int
    hentai: bool
    h_type: str
    description: str
    genres: str


class Worker(QThread):
    finished = Signal(list)
    error = Signal(str)

    def __init__(self, query: str):
        super().__init__()
        self.query = query

    def run(self):
        try:
            results = self.perform_search_operation()
            results_dict = [asdict(result) for result in results]
            self.finished.emit(results_dict)
        except Exception as e:
            self.error.emit(str(e))

    async def fetch_anime_data(self, query: str) -> list[dict]:
        async with asyncio.TaskGroup() as tg:
            anime_results = tg.create_task(
                self._fetch_from_source("https://anime365.ru/api/series", query, False)
            )
            hentai_results = tg.create_task(
                self._fetch_from_source("https://hentai365.ru/api/series", query, True)
            )
        return anime_results.result() + hentai_results.result()

    async def _fetch_from_source(
        self, url: str, query: str, is_hentai: bool
    ) -> list[dict]:
        async with aiohttp.ClientSession() as session:
            async with session.get(
                url,
                params={
                    "query": query,
                    "limit": 100,
                    "offset": 0,
                    "isHentai": int(is_hentai),
                },
            ) as response:
                return (await response.json())["data"]

    def perform_search_operation(self) -> list[AnimeSearchResult]:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            raw_results = loop.run_until_complete(self.fetch_anime_data(self.query))
            with open(LOG_DIR / "results.json", "w") as f:
                json.dump(raw_results, f, indent=4, ensure_ascii=False)
            results = [
                AnimeSearchResult(
                    id=item["id"],
                    title=item["titles"].get("romaji")
                    or item["titles"].get("en")
                    or item["titles"].get("ru")
                    or item["titles"].get("ja"),
                    episodes=item["numberOfEpisodes"],
                    episode_list=item.get("episodes", []),
                    image_url=item["posterUrl"],
                    type=item["type"],
                    score=float(item.get("myAnimeListScore") or 0),
                    year=int(item["year"]),
                    hentai=item["isHentai"],
                    h_type="hentai" if item["isHentai"] else item["type"],
                    description=item.get("descriptions")
                    and item["descriptions"][0]["value"]
                    + "\n\nSource: "
                    + item["descriptions"][0]["source"]
                    or "",
                    genres=", ".join(i["title"] for i in item.get("genres", [])),
                )
                for item in sorted(raw_results, key=lambda x: x["year"], reverse=True)
            ]
            return results
        except Exception as e:
            raise e
        finally:
            loop.close()


class Backend(QObject):
    search_completed = Signal(list)
    search_error = Signal(str)

    def __init__(self):
        super().__init__()
        self.search_worker = None

    @Slot(str)
    def perform_search(self, query: str):
        if self.search_worker and self.search_worker.isRunning():
            self.search_worker.terminate()
        self.search_worker = Worker(query)
        self.search_worker.finished.connect(self.handle_search_completed)
        self.search_worker.error.connect(self.handle_search_error)
        self.search_worker.start()

    def handle_search_completed(self, results):
        self.search_completed.emit(results)

    def handle_search_error(self, error_message):
        self.search_error.emit(error_message)
