# backend.py
import subprocess
import asyncio
import aiohttp
from dataclasses import dataclass, asdict
from PySide6.QtCore import QObject, Slot, Signal, QThread


@dataclass
class AnimeSearchResult:
    id: int
    title: str
    episodes: int
    image_url: str
    type: str
    score: float
    year: int


class Worker(QThread):
    finished = Signal(list)
    error = Signal(str)

    def __init__(self, query: str):
        super().__init__()
        self.query = query

    def run(self):
        try:
            results = self.perform_search_operation()
            # Convert dataclass objects to dictionaries
            results_dict = [asdict(result) for result in results]
            self.finished.emit(results_dict)
        except Exception as e:
            self.error.emit(str(e))

    async def fetch_anime_data(self, query: str) -> list[dict]:
        print(123)
        async with aiohttp.ClientSession() as session:
            # Example using an anime API
            url = f"https://anime365.ru/api/series"
            async with session.get(
                url, params={"query": query, "limit": 100, "offset": 0, "isHentai": 0}
            ) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    raise Exception(f"API error: {response.status}")

    def perform_search_operation(self) -> list[AnimeSearchResult]:
        # Run async code in sync context
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            raw_results = loop.run_until_complete(self.fetch_anime_data(self.query))
            print(raw_results)
            # Convert API results to AnimeSearchResult objects
            results = [
                AnimeSearchResult(
                    id=item["id"],
                    title=item["titles"].get("en")
                    or item["titles"].get("romaji")
                    or item["titles"].get("ru")
                    or item["titles"].get("ja"),
                    episodes=item["numberOfEpisodes"],
                    image_url=item["posterUrl"],
                    type=item["type"],
                    score=float(item.get("myAnimeListScore") or 0),
                    year=int(item["year"]),
                )
                for item in raw_results["data"]
            ]
            return results
        except Exception as e:
            raise e
        finally:
            loop.close()


class Backend(QObject):
    search_started = Signal()
    search_completed = Signal(list)
    search_error = Signal(str)

    def __init__(self):
        super().__init__()
        self.search_worker = None

    @Slot(str)
    def perform_search(self, query: str):
        self.search_started.emit()
        # Create new worker for the search
        self.search_worker = Worker(query)
        self.search_worker.finished.connect(self.handle_search_completed)
        self.search_worker.error.connect(self.handle_search_error)
        self.search_worker.start()

    def handle_search_completed(self, results):
        self.search_completed.emit(results)

    def handle_search_error(self, error_message):
        self.search_error.emit(error_message)

    @Slot()
    def open_uget(self):
        subprocess.Popen(["uget-gtk"])
