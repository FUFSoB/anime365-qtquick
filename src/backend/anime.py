import re
import subprocess
import sys
from pathlib import Path
from typing import TYPE_CHECKING

import aiohttp
from PySide6.QtCore import QObject, Signal, Slot

from constants import CACHE_DIR

from .utils import (
    AsyncFunctionWorker,
    find_free_port,
    get_subtitle_fonts,
    monitor_mpc_status,
    monitor_mpv_status,
    monitor_vlc_status,
)

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


class BatchStreamsWorker(AsyncFunctionWorker):
    batch_item_ready = Signal(dict)  # {url, subs_url, episode_name, episode_index}
    batch_progress = Signal(int, int)  # (current, total)
    batch_unavailable = Signal(
        str
    )  # episode_name that lacks the requested team/quality

    def __init__(
        self,
        episode_ids: list[int],
        episode_names: list[str],
        preferred_translation: str,
        preferred_quality: str,
        settings: "SettingsBackend",
    ):
        super().__init__(self.perform_batch)
        self.episode_ids = episode_ids
        self.episode_names = episode_names
        self.preferred_translation = preferred_translation
        self.preferred_quality = preferred_quality
        self.api = settings.api

    async def perform_batch(self):
        results = []
        total = len(self.episode_ids)
        preferred_height = 0
        if self.preferred_quality:
            q = self.preferred_quality.rstrip("p")
            preferred_height = int(q) if q.isdigit() else 0

        for i, (ep_id, ep_name) in enumerate(zip(self.episode_ids, self.episode_names)):
            self.batch_progress.emit(i + 1, total)
            try:
                translations_raw = await self.api.get_translations(ep_id)
                translations = [
                    EpisodeWorker._create_episode_result(t) for t in translations_raw
                ]
                translations.sort(key=EpisodeWorker._sort_translations, reverse=True)

                # Require exact translation match when one is specified; stop on miss
                if self.preferred_translation:
                    chosen = next(
                        (
                            t
                            for t in translations
                            if t["full_title"] == self.preferred_translation
                        ),
                        None,
                    )
                    if chosen is None:
                        self.batch_unavailable.emit(ep_name)
                        return results
                else:
                    chosen = translations[0] if translations else None

                if not chosen:
                    self.batch_unavailable.emit(ep_name)
                    return results

                stream_data = await self.api.get_streams(chosen["id"])
                streams = sorted(
                    stream_data["stream"], key=lambda x: x["height"], reverse=True
                )
                if not streams:
                    self.batch_unavailable.emit(ep_name)
                    return results

                # Require exact quality match when one is specified; stop on miss
                if preferred_height:
                    chosen_stream = next(
                        (s for s in streams if s["height"] == preferred_height),
                        None,
                    )
                    if chosen_stream is None:
                        self.batch_unavailable.emit(ep_name)
                        return results
                else:
                    chosen_stream = streams[0]

                subs_url = stream_data.get("subtitlesUrl") or None
                if subs_url and subs_url.startswith("/"):
                    subs_url = self.api.anime365_url + subs_url
                if subs_url:
                    subs_url = subs_url.removesuffix("?willcache")

                item = dict(
                    url=chosen_stream["urls"][0],
                    subs_url=subs_url,
                    episode_name=ep_name,
                    episode_index=i,
                )
                self.batch_item_ready.emit(item)
                results.append(item)
            except Exception:
                continue  # transient network error – keep going
        return results


class Backend(QObject):
    episodes_got = Signal(dict)
    translations_got = Signal(list)
    streams_got = Signal(list, bool)
    subtitle_fonts_got = Signal(dict)
    font_status = Signal(str, str)   # (font_name, "downloading"|"done"|"failed")
    fonts_downloaded = Signal(dict)  # {"downloaded": [...], "not_found": [...]}
    batch_progress = Signal(int, int)
    batch_item_ready = Signal(dict)
    batch_unavailable = Signal(
        str
    )  # episode name that lacks the requested team/quality
    batch_complete = Signal()
    playback_finished = Signal(bool)  # True = episode completed (>85% watched)

    def __init__(self, settings: "SettingsBackend"):
        super().__init__()
        self.settings = settings
        self.workers: list[AsyncFunctionWorker] = []
        self.mpv_worker = None
        self.vlc_worker = None
        self.mpc_worker = None
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
        worker.completed.connect(
            lambda *_, w=worker: self.workers.remove(w) if w in self.workers else None
        )
        worker.start()

    @Slot(int)
    def select_episode(self, episode_id: int):
        self._clear_workers()
        worker = EpisodeWorker(episode_id, self.settings)
        self.workers.append(worker)
        worker.result_list.connect(self.translations_got.emit)
        worker.completed.connect(
            lambda *_, w=worker: self.workers.remove(w) if w in self.workers else None
        )
        worker.start()

    @Slot(int, bool)
    def get_streams(self, translation_id: int, is_for_other_video: bool):
        self._clear_workers()
        worker = StreamsWorker(translation_id, self.settings)
        self.workers.append(worker)
        worker.result_list.connect(
            lambda result: self.streams_got.emit(result, is_for_other_video)
        )
        worker.completed.connect(
            lambda *_, w=worker: self.workers.remove(w) if w in self.workers else None
        )
        worker.start()

    @Slot(str)
    def get_subtitle_fonts(self, url: str):
        worker = AsyncFunctionWorker(get_subtitle_fonts, url)
        self.workers.append(worker)
        worker.result_dict.connect(self.subtitle_fonts_got)
        worker.completed.connect(
            lambda *_, w=worker: self.workers.remove(w) if w in self.workers else None
        )
        worker.start()

    @Slot(list, list)
    def download_missing_fonts(self, fonts: list, scripts: list):
        from .fonts import search_and_download_fonts

        worker = AsyncFunctionWorker(
            search_and_download_fonts, fonts, scripts,
            status_cb=self.font_status.emit,
        )
        self.workers.append(worker)

        def _on_result(result: dict) -> None:
            from PySide6.QtGui import QFontDatabase

            paths = result.get("downloaded", [])
            for p in paths:
                QFontDatabase.addApplicationFont(str(p))
            self.fonts_downloaded.emit({
                "downloaded": [str(p) for p in paths],
                "not_found": result.get("not_found", []),
            })

        worker.result_dict.connect(_on_result)
        worker.completed.connect(
            lambda *_, w=worker: self.workers.remove(w) if w in self.workers else None
        )
        worker.start()

    @Slot(result=str)
    def get_fonts_dir(self) -> str:
        from .fonts import FONTS_DIR
        return str(FONTS_DIR)

    @Slot(str, str, str, str)
    def launch_mpv(self, url: str, subs_url: str, title: str, cover_url: str = ""):
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

        from .fonts import FONTS_DIR
        if FONTS_DIR.exists():
            command.append(f"--sub-font-dir={FONTS_DIR}")

        extra_args = self.settings.get("mpv_args") or ""
        if extra_args:
            import shlex

            command.extend(shlex.split(extra_args, posix=(sys.platform != "win32")))

        process = subprocess.Popen(command)
        if self.mpv_worker:
            self.mpv_worker.terminate()
        # Parse title/episode from the title string "Anime Title — Episode N"
        parts = title.split(" \u2014 ", 1)
        anime_title = parts[0] if parts else title
        episode_str = parts[1] if len(parts) > 1 else ""
        discord_rpc_enabled = self.settings.get("discord_rpc") is not False
        self.mpv_worker = AsyncFunctionWorker(
            monitor_mpv_status,
            process,
            ipc_path,
            anime_title,
            episode_str,
            cover_url,
            discord_rpc_enabled,
        )
        self.mpv_worker.result_bool.connect(self.playback_finished.emit)
        self.mpv_worker.start()

    @Slot(str, str, str, str)
    def launch_vlc(self, url: str, subs_url: str, title: str, cover_url: str = ""):
        import secrets

        port = find_free_port(41365)  # 4n1m3 + 65 (leet "anime365")
        http_password = secrets.token_hex(16)

        command = [
            self.settings.vlc_path,
            url,
            "--meta-title",
            title,
            "--no-video-title-show",
            "--extraintf",
            "http",
            "--http-host",
            "localhost",
            f"--http-port={port}",
            f"--http-password={http_password}",
        ]

        extra_args = self.settings.get("vlc_args") or ""
        if extra_args:
            import shlex

            command.extend(shlex.split(extra_args, posix=(sys.platform != "win32")))

        parts = title.split(" \u2014 ", 1)
        anime_title = parts[0] if parts else title
        episode_str = parts[1] if len(parts) > 1 else ""

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

            process = subprocess.Popen(command)
            discord_rpc_enabled = self.settings.get("discord_rpc") is not False
            return await monitor_vlc_status(
                process,
                port,
                http_password,
                anime_title,
                episode_str,
                cover_url,
                discord_rpc_enabled,
            )

        if self.vlc_worker:
            self.vlc_worker.terminate()
        self.vlc_worker = AsyncFunctionWorker(_run_vlc)
        self.vlc_worker.result_bool.connect(self.playback_finished.emit)
        self.vlc_worker.start()

    @Slot(str, str, str, str)
    def launch_mpc(self, url: str, subs_url: str, title: str, cover_url: str = ""):
        port = int(self.settings.get("mpc_port") or 13579)

        command = [self.settings.mpc_path, url]

        extra_args = self.settings.get("mpc_args") or ""
        if extra_args:
            import shlex

            command.extend(shlex.split(extra_args, posix=(sys.platform != "win32")))

        parts = title.split(" \u2014 ", 1)
        anime_title = parts[0] if parts else title
        episode_str = parts[1] if len(parts) > 1 else ""

        async def _run_mpc():
            if subs_url:
                subs_file = CACHE_DIR / ".mpc_subtitles.ass"
                async with aiohttp.ClientSession(
                    connector=await self.api.get_connector()
                ) as session:
                    async with session.get(subs_url) as response:
                        if response.status != 200:
                            raise Exception("Subtitles unavailable")
                        subtitle_bytes = await response.read()
                        with subs_file.open("wb") as file:
                            file.write(subtitle_bytes)
                command.extend(["/sub", str(subs_file)])

            process = subprocess.Popen(command)
            discord_rpc_enabled = self.settings.get("discord_rpc") is not False
            return await monitor_mpc_status(
                process,
                port,
                anime_title,
                episode_str,
                cover_url,
                discord_rpc_enabled,
            )

        if self.mpc_worker:
            self.mpc_worker.terminate()
        self.mpc_worker = AsyncFunctionWorker(_run_mpc)
        self.mpc_worker.result_bool.connect(self.playback_finished.emit)
        self.mpc_worker.start()

    @Slot(str, str, str, str)
    def batch_download(
        self,
        episode_ids_str: str,
        episode_names_str: str,
        preferred_translation: str,
        preferred_quality: str,
    ):
        ep_ids = [int(x) for x in episode_ids_str.split(";") if x]
        ep_names = episode_names_str.split(";")
        worker = BatchStreamsWorker(
            ep_ids, ep_names, preferred_translation, preferred_quality, self.settings
        )
        self.workers.append(worker)
        worker.batch_progress.connect(self.batch_progress.emit)
        worker.batch_item_ready.connect(self.batch_item_ready.emit)
        worker.batch_unavailable.connect(self.batch_unavailable.emit)
        worker.completed.connect(self.batch_complete.emit)
        worker.completed.connect(
            lambda *_: self.workers.remove(worker) if worker in self.workers else None
        )
        worker.start()

    @Slot(str, int, str, result=str)
    def title_to_filename(self, title: str, episodes_total: int, ext: str) -> str:
        name, episode = title.split(" \u2014 ", 1)
        name = re.sub(r"[^\w\d\-_]", "_", name).strip("_")
        pad = len(str(max(episodes_total, 1)))
        parts = episode.rsplit(" ", 1)
        if len(parts) == 2 and parts[-1].isdigit():
            # e.g. "ONA 1", "OVA 2", "Серия 5"
            prefix = re.sub(r"[^\w\d\-_]", "_", parts[0]).strip("_")
            num = parts[-1].rjust(pad, "0")
            ep_part = f"{prefix}_{num}" if prefix else num
        elif parts[0].isdigit():
            # bare number e.g. "5"
            ep_part = parts[0].rjust(pad, "0")
        else:
            ep_part = re.sub(r"[^\w\d\-_]", "_", episode).strip("_")
        return f"{name}-{ep_part}.{ext}"
