import subprocess
import re
from PySide6.QtCore import QObject, Slot, Signal

from constants import DOWNLOADS_DIR
from .utils import AsyncFunctionWorker, get_subtitle_fonts

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend


class GetEpisodesWorker(AsyncFunctionWorker):
    def __init__(self, anime_id: int, settings: "SettingsBackend"):
        super().__init__(self.perform_get_episodes_operation)
        self.anime_id = anime_id
        self.api = settings.api

    async def perform_get_episodes_operation(self):
        try:
            result = await self.api.get_episodes(self.anime_id)
            return dict(
                episode_list=";".join(i["episodeFull"] for i in result),
                episode_ids=";".join(str(i["id"]) for i in result),
            )
        except Exception as e:
            self.error.emit(str(e))


class EpisodeWorker(AsyncFunctionWorker):
    def __init__(self, episode_id: int, settings: "SettingsBackend"):
        super().__init__(self.perform_get_episode_operation)
        self.episode_id = episode_id
        self.api = settings.api

    @staticmethod
    def _create_episode_result(item: dict) -> dict:
        authors: list[str] = item["authorsList"]
        authors_string = ", ".join(authors) or "—"

        language = item["typeLang"]
        kind = item["typeKind"]
        quality_type = item["qualityType"]
        height = item["height"]

        full_title = f"[{language}, {kind}, {quality_type}, {height}p] {authors_string}"

        return dict(
            id=item["id"],
            authors=authors,
            authors_string=authors_string,
            language=language,
            kind=kind,
            quality_type=quality_type,
            height=height,
            full_title=full_title,
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
            + translation["height"],
            translation["authors_string"],
        )

    async def perform_get_episode_operation(self):
        result = await self.api.get_translations(self.episode_id)
        return sorted(
            (self._create_episode_result(item) for item in result),
            key=self._sort_translations,
            reverse=True,
        )


class StreamsWorker(AsyncFunctionWorker):
    def __init__(self, translation_id: int, settings: "SettingsBackend"):
        super().__init__(self.perform_get_streams_operation)
        self.translation_id = translation_id
        self.api = settings.api

    def _create_stream_result(self, item: dict, subs_url: str | None) -> dict:
        if subs_url:
            if subs_url.startswith("/"):
                subs_url = self.api.anime365_url + subs_url
            subs_url = subs_url.removesuffix("?willcache")
        return dict(
            url=item["urls"][0],
            height=item["height"],
            subs_url=subs_url,
        )

    async def perform_get_streams_operation(self):
        result = await self.api.get_streams(self.translation_id)
        return sorted(
            (
                self._create_stream_result(item, result["subtitlesUrl"])
                for item in result["stream"]
            ),
            key=lambda x: x["height"],
            reverse=True,
        )


class Backend(QObject):
    episodes_got = Signal(dict)
    translations_got = Signal(list)
    streams_got = Signal(list, bool)
    subtitle_fonts_got = Signal(list)

    def __init__(self, settings: "SettingsBackend"):
        super().__init__()
        self.settings = settings
        self.workers: list[AsyncFunctionWorker] = []
        self.api = settings.api

    def _clear_workers(self):
        for worker in self.workers:
            worker.terminate()
        self.workers.clear()

    @Slot(int)
    def get_episodes(self, anime_id: int):
        self._clear_workers()
        worker = GetEpisodesWorker(anime_id, self.settings)
        self.workers.append(worker)
        worker.result_dict.connect(self.episodes_got.emit)
        worker.completed.connect(lambda *_: self.workers.remove(worker))
        worker.start()

    @Slot(int)
    def select_episode(self, episode_id: int):
        self._clear_workers()
        worker = EpisodeWorker(episode_id, self.settings)
        self.workers.append(worker)
        worker.result_list.connect(self.translations_got.emit)
        worker.completed.connect(lambda *_: self.workers.remove(worker))
        worker.start()

    @Slot(int, bool)
    def get_streams(self, translation_id: int, is_for_other_video: bool):
        self._clear_workers()
        worker = StreamsWorker(translation_id, self.settings)
        self.workers.append(worker)
        worker.result_list.connect(
            lambda result: self.streams_got.emit(result, is_for_other_video)
        )
        worker.completed.connect(lambda *_: self.workers.remove(worker))
        worker.start()

    @Slot(str)
    def get_subtitle_fonts(self, url: str):
        worker = AsyncFunctionWorker(get_subtitle_fonts, url)
        self.workers.append(worker)
        worker.result_list.connect(self.subtitle_fonts_got)
        worker.completed.connect(lambda *_: self.workers.remove(worker))
        worker.start()

    @Slot(str, str, str)
    def launch_mpv(self, url: str, subs_url: str, title: str):
        command = [self.settings.mpv_path, url, "-title", title]

        if subs_url:
            command.extend(["-sub-file", subs_url])

        subprocess.Popen(command)

    @staticmethod
    def _title_to_filename(title: str, episodes_total: int, ext: str) -> str:
        title, episode = title.split(" — ")

        title = re.sub(r"[^\w\d\-_]", "_", title).strip("_")

        episode = episode.split(" ")[0].rjust(len(str(episodes_total)), "0")

        return f"{title}-{episode}.{ext}"

    @Slot(str, str, int, bool)
    def launch_uget(self, url: str, title: str, episodes_total: int, is_subs: bool):
        name = self._title_to_filename(
            title, episodes_total, "ass" if is_subs else "mp4"
        )
        command = [
            self.settings.uget_path,
            "--quiet",
            f"--folder={DOWNLOADS_DIR}",
            f"--filename={name}",
            url,
        ]
        subprocess.Popen(
            command,
            shell=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
