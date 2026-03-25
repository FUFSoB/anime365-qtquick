import subprocess
import sys
import re
import aiohttp
from PySide6.QtCore import QObject, Slot, Signal, QUrl
from PySide6.QtGui import QDesktopServices

from constants import DOWNLOADS_DIR, CACHE_DIR
from .utils import AsyncFunctionWorker, get_subtitle_fonts, monitor_mpv_status

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend

IS_ANDROID = hasattr(sys, "getandroidapilevel")


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


class BatchStreamsWorker(AsyncFunctionWorker):
    batch_item_ready = Signal(dict)  # {url, subs_url, episode_name, episode_index}
    batch_progress = Signal(int, int)  # (current, total)

    def __init__(
        self,
        episode_ids: list[int],
        episode_names: list[str],
        preferred_translation: str,
        settings: "SettingsBackend",
    ):
        super().__init__(self.perform_batch)
        self.episode_ids = episode_ids
        self.episode_names = episode_names
        self.preferred_translation = preferred_translation
        self.api = settings.api

    async def perform_batch(self):
        results = []
        total = len(self.episode_ids)
        for i, (ep_id, ep_name) in enumerate(zip(self.episode_ids, self.episode_names)):
            self.batch_progress.emit(i + 1, total)
            try:
                translations_raw = await self.api.get_translations(ep_id)
                translations = [
                    EpisodeWorker._create_episode_result(t) for t in translations_raw
                ]
                translations.sort(key=EpisodeWorker._sort_translations, reverse=True)

                # Try to match the preferred translation
                chosen = translations[0] if translations else None
                if self.preferred_translation:
                    for t in translations:
                        if t["full_title"] == self.preferred_translation:
                            chosen = t
                            break

                if not chosen:
                    continue

                stream_data = await self.api.get_streams(chosen["id"])
                streams = sorted(
                    stream_data["stream"], key=lambda x: x["height"], reverse=True
                )
                if not streams:
                    continue

                subs_url = stream_data.get("subtitlesUrl") or None
                if subs_url and subs_url.startswith("/"):
                    subs_url = self.api.anime365_url + subs_url
                if subs_url:
                    subs_url = subs_url.removesuffix("?willcache")

                item = dict(
                    url=streams[0]["urls"][0],
                    subs_url=subs_url,
                    episode_name=ep_name,
                    episode_index=i,
                )
                self.batch_item_ready.emit(item)
                results.append(item)
            except Exception:
                continue
        return results


class Backend(QObject):
    episodes_got = Signal(dict)
    translations_got = Signal(list)
    streams_got = Signal(list, bool)
    subtitle_fonts_got = Signal(list)
    batch_progress = Signal(int, int)
    batch_item_ready = Signal(dict)
    batch_complete = Signal()
    playback_finished = Signal(bool)  # True = episode completed (>85% watched)

    def __init__(self, settings: "SettingsBackend"):
        super().__init__()
        self.settings = settings
        self.workers: list[AsyncFunctionWorker] = []
        self.mpv_worker = None
        self.vlc_worker = None
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

    @Slot(str, str, str, str)
    def launch_mpv(self, url: str, subs_url: str, title: str, cover_url: str = ""):
        if IS_ANDROID:
            self._launch_android_player(url, subs_url, title, "is.xyz.mpv")
            return

        import tempfile

        if sys.platform == "win32":
            ipc_path = r"\\.\pipe\anime365-mpv-ipc"
        else:
            ipc_path = str(Path(tempfile.gettempdir()) / "anime365-mpv-ipc")

        command = [
            self.settings.mpv_path,
            url,
            f"--title={title}",
            f"--input-ipc-server={ipc_path}",
        ]

        if subs_url:
            command.append(f"--sub-file={subs_url}")

        process = subprocess.Popen(command)
        if self.mpv_worker:
            self.mpv_worker.terminate()
        # Parse title/episode from the title string "Anime Title — Episode N"
        parts = title.split(" \u2014 ", 1)
        anime_title = parts[0] if parts else title
        episode_str = parts[1] if len(parts) > 1 else ""
        self.mpv_worker = AsyncFunctionWorker(
            monitor_mpv_status, process, ipc_path, anime_title, episode_str, cover_url
        )
        self.mpv_worker.result_bool.connect(self.playback_finished.emit)
        self.mpv_worker.start()

    @Slot(str, str, str)
    def launch_vlc(self, url: str, subs_url: str, title: str):
        if IS_ANDROID:
            self._launch_android_player(url, subs_url, title, "org.videolan.vlc")
            return

        command = [
            self.settings.vlc_path,
            url,
            "--meta-title",
            title,
            "--no-video-title-show",
        ]

        async def _run_vlc():
            if subs_url:
                subs_file = CACHE_DIR / ".vlc_subtitles.ass"
                async with aiohttp.ClientSession(
                    connector=await self.api.get_connector()
                ) as session:
                    async with session.get(subs_url) as response:
                        if response.status != 200:
                            raise Exception("Subtitles unavailable")

                        subtitle_bytes = await response.read()
                        with subs_file.open("wb") as file:
                            file.write(subtitle_bytes)

                command.extend(["--sub-file", str(subs_file)])

            subprocess.Popen(command)

        if self.vlc_worker:
            self.vlc_worker.terminate()
        self.vlc_worker = AsyncFunctionWorker(_run_vlc)
        self.vlc_worker.start()

    @staticmethod
    def _launch_android_player(url: str, subs_url: str, title: str, package: str):
        extras = f";S.title={title}"

        if subs_url:
            if package == "is.xyz.mpv":
                extras += f";S.subs={subs_url};S.subs.enable={subs_url}"
            else:
                # VLC and generic players
                extras += f";S.subtitles_location={subs_url}"

        intent_url = (
            f"intent:{url}"
            f"#Intent;action=android.intent.action.VIEW"
            f";type=video/*"
            f"{extras}"
            f";package={package}"
            f";end"
        )
        QDesktopServices.openUrl(QUrl(intent_url))

    @staticmethod
    def _title_to_filename(title: str, episodes_total: int, ext: str) -> str:
        title, episode = title.split(" — ")

        title = re.sub(r"[^\w\d\-_]", "_", title).strip("_")

        episode = episode.split(" ")[0].rjust(len(str(episodes_total)), "0")

        return f"{title}-{episode}.{ext}"

    @Slot(str, str, int, bool)
    def launch_uget(self, url: str, title: str, episodes_total: int, is_subs: bool):
        if IS_ANDROID:
            self._android_download(url, title, episodes_total, is_subs)
            return

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

    @Slot()
    def open_uget(self):
        if IS_ANDROID:
            return
        subprocess.Popen([self.settings.uget_path])

    @staticmethod
    def _android_download(
        url: str, title: str, episodes_total: int, is_subs: bool
    ):
        """Open a download URL in the Android browser / download manager."""
        QDesktopServices.openUrl(QUrl(url))
