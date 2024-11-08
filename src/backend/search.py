import asyncio
import aiohttp
from aiohttp_socks import ProxyConnector
import json
from dataclasses import dataclass, asdict
from PySide6.QtCore import QObject, Slot, Signal, QThread

from constants import LOG_DIR
from typing import TYPE_CHECKING


@dataclass
class AnimeSearchResult:
    id: int
    title: str
    episodes: int
    episode_list: str
    episode_ids: str
    image_url: str
    type: str
    score: str
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
        params = (
            ("https://anime365.ru/api/series", query, False),
            # ("https://hentai365.ru/api/series", query, True),
        )
        tasks = []
        async with asyncio.TaskGroup() as tg:
            for param in params:
                tasks.append(tg.create_task(self._fetch_from_source(*param)))
        result = []
        for task in tasks:
            result.extend(task.result())
        return result

    async def _fetch_from_source(
        self, url: str, query: str, is_hentai: bool
    ) -> list[dict]:
        # connector = ProxyConnector.from_url("socks5://127.0.0.1:12345")
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

    @staticmethod
    def _create_search_result(item: dict) -> AnimeSearchResult:
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

        return AnimeSearchResult(
            id=item["id"],
            title=title,
            episodes=item["numberOfEpisodes"],
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

    def perform_search_operation(self) -> list[AnimeSearchResult]:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            raw_results = loop.run_until_complete(self.fetch_anime_data(self.query))
            with open(LOG_DIR / "results.json", "w") as f:
                json.dump(raw_results, f, indent=4, ensure_ascii=False)
            results = [
                self._create_search_result(item)
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

    def __init__(self, settings):
        super().__init__()
        self.search_worker = None
        self.settings = settings

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
