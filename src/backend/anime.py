from PySide6.QtCore import QObject, Slot, Signal

from .utils import AsyncFunctionWorker
from .net import BASE_URL

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend


class EpisodeWorker(AsyncFunctionWorker):
    finished = Signal(list)
    error = Signal(str)

    def __init__(self, episode_id: int, settings: "SettingsBackend"):
        super().__init__(self.perform_get_episode_operation)
        self.episode_id = episode_id
        self.api = settings.api

    @staticmethod
    def _create_episode_result(item: dict) -> dict:
        authors: list[str] = item["authorsList"]
        authors_string = ", ".join(authors) or "—"

        return dict(
            id=item["id"],
            authors=authors,
            authors_string=authors_string,
            language=item["typeLang"],
            kind=item["typeKind"],
            quality_type=item["qualityType"],
            height=item["height"],
        )

    @staticmethod
    def _sort_translations(translation: dict) -> int:
        language_weight = {"ru": 4, "en": 3, "jp": 2}
        kind_weight = {"sub": 3, "dub": 2}
        quality_type_weight = {"bd": 4, "dvd": 3, "tv": 2}

        return (
            language_weight.get(translation["language"], 1) * 10_000_000
            + kind_weight.get(translation["kind"], 1) * 1_000_000
            + quality_type_weight.get(translation["quality_type"], 1) * 100_000
            + translation["height"]
        )

    async def perform_get_episode_operation(self):
        try:
            result = await self.api.get_translations(self.episode_id)
            result = sorted(
                (self._create_episode_result(item) for item in result),
                key=self._sort_translations,
                reverse=True,
            )
            self.finished.emit(result)
        except Exception as e:
            self.error.emit(str(e))


class StreamsWorker(AsyncFunctionWorker):
    finished = Signal(list)
    error = Signal(str)

    def __init__(self, translation_id: int, settings: "SettingsBackend"):
        super().__init__(self.perform_get_streams_operation)
        self.translation_id = translation_id
        self.api = settings.api

    @staticmethod
    def _create_stream_result(item: dict, subs_url: str | None) -> dict:
        if subs_url:
            if subs_url.startswith("/"):
                subs_url = BASE_URL + subs_url
            subs_url = subs_url.removesuffix("?willcache")
        return dict(
            url=item["urls"][0],
            height=item["height"],
            subs_url=subs_url,
        )

    async def perform_get_streams_operation(self):
        try:
            result = await self.api.get_streams(self.translation_id)
            result = sorted(
                (
                    self._create_stream_result(item, result["subtitlesUrl"])
                    for item in result["stream"]
                ),
                key=lambda x: x["height"],
                reverse=True,
            )
            self.finished.emit(result)
        except Exception as e:
            self.error.emit(str(e))


class Backend(QObject):
    translations_got = Signal(list)
    streams_got = Signal(list)

    def __init__(self, settings: "SettingsBackend"):
        super().__init__()
        self.settings = settings
        self.worker = None
        self.api = settings.api

    @Slot(int)
    def select_episode(self, episode_id: int):
        self.worker = EpisodeWorker(episode_id, self.settings)
        self.worker.finished.connect(self.translations_got.emit)
        self.worker.error.connect(self.translations_got.emit)
        self.worker.start()

    @Slot(int)
    def get_streams(self, translation_id: int):
        self.worker = StreamsWorker(translation_id, self.settings)
        self.worker.finished.connect(self.streams_got.emit)
        self.worker.error.connect(self.streams_got.emit)
        self.worker.start()
