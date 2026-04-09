import asyncio
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING

import aiohttp
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from constants import DATA_DIR, DOWNLOADS_DIR

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend

_METADATA_FILE = DOWNLOADS_DIR / ".metadata.json"
_HISTORY_FILE = DATA_DIR / "download_history.json"


class DownloadMetadata:
    def __init__(self):
        self._data: dict[str, dict] = {}
        self._load()

    def _load(self):
        try:
            if _METADATA_FILE.exists():
                self._data = json.loads(_METADATA_FILE.read_text())
        except Exception:
            self._data = {}

    def _save(self):
        try:
            _METADATA_FILE.write_text(
                json.dumps(self._data, indent=2, ensure_ascii=False), encoding="utf-8"
            )
        except Exception:
            pass

    def record(self, filename: str, meta: dict):
        self._data[filename] = meta
        self._save()

    def remove(self, filename: str):
        self._data.pop(filename, None)
        self._save()

    def get(self, filename: str) -> dict:
        return self._data.get(filename, {})

    def find(self, **match) -> list[tuple[str, dict]]:
        results = []
        for fname, meta in self._data.items():
            if all(meta.get(k) == v for k, v in match.items()):
                results.append((fname, meta))
        return results


class DownloadHistory:
    def __init__(self):
        self._entries: list[dict] = []
        self._load()

    def _load(self):
        try:
            if _HISTORY_FILE.exists():
                self._entries = json.loads(_HISTORY_FILE.read_text())
        except Exception:
            self._entries = []

    def _save(self):
        try:
            _HISTORY_FILE.write_text(
                json.dumps(self._entries, indent=2, ensure_ascii=False),
                encoding="utf-8",
            )
        except Exception:
            pass

    def add(self, filename: str, size: int, meta: dict):
        from time import time

        self._entries.insert(
            0,
            {
                "filename": filename,
                "size": size,
                "timestamp": int(time()),
                **meta,
            },
        )
        self._save()

    def get_all(self) -> list[dict]:
        return list(self._entries)

    def remove(self, index: int):
        if 0 <= index < len(self._entries):
            self._entries.pop(index)
            self._save()

    def clear(self):
        self._entries.clear()
        self._save()


@dataclass
class DownloadItem:
    gid: str
    filename: str
    url: str
    status: str = "waiting"  # waiting, active, complete, muxing, error, paused
    progress: float = 0.0
    speed: int = 0
    total_size: int = 0
    downloaded: int = 0
    error_message: str = ""
    pausable: bool = True
    subs_filename: str = ""

    def to_dict(self) -> dict:
        return {
            "gid": self.gid,
            "filename": self.filename,
            "url": self.url,
            "status": self.status,
            "progress": self.progress,
            "speed": self.speed,
            "total_size": self.total_size,
            "downloaded": self.downloaded,
            "error_message": self.error_message,
            "pausable": self.pausable,
        }


async def _embed_subs(video_path: Path, subs_path: Path, ffmpeg: str = "") -> str:
    """Mux subs (and all required fonts) into MKV with ffmpeg (-c copy).
    Returns new filename, or '' on failure/skip."""
    if not ffmpeg:
        ffmpeg = shutil.which("ffmpeg") or ""
    if not ffmpeg or not subs_path.exists() or not video_path.exists():
        return ""

    # Gather font files for the subtitle
    font_paths: list[Path] = []
    if subs_path.suffix.lower() == ".ass":
        try:
            from .fonts import get_fonts_for_subs
            font_paths = await get_fonts_for_subs(subs_path)
        except Exception as exc:
            print(f"[fonts] Font gathering failed: {exc}")

    out_path = video_path.with_suffix(".mkv")
    same_file = out_path == video_path
    if same_file:
        out_path = video_path.with_name(video_path.stem + "._mux.mkv")

    cmd = [ffmpeg, "-i", str(video_path), "-i", str(subs_path)]

    for font_path in font_paths:
        cmd += ["-attach", str(font_path)]

    for i, font_path in enumerate(font_paths):
        mime = (
            "application/vnd.ms-opentype"
            if font_path.suffix.lower() == ".otf"
            else "application/x-truetype-font"
        )
        cmd += [f"-metadata:s:t:{i}", f"mimetype={mime}"]

    cmd += ["-c", "copy", "-y", str(out_path)]

    kwargs: dict = {}
    if sys.platform == "win32":
        kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW

    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
            **kwargs,
        )
        await proc.wait()
    except Exception:
        out_path.unlink(missing_ok=True)
        return ""

    if proc.returncode != 0:
        out_path.unlink(missing_ok=True)
        return ""

    video_path.unlink(missing_ok=True)
    subs_path.unlink(missing_ok=True)

    if same_file:
        out_path.rename(video_path)
        return video_path.name

    return out_path.name


class Aria2Daemon:
    def __init__(
        self, aria2c_path: str, extra_args: str = "", download_threads: int = 4,
        proxy: str = "",
    ):
        self.aria2c_path = aria2c_path
        self.extra_args = extra_args
        self.download_threads = max(1, min(download_threads, 16))
        self.proxy = proxy
        self.process: subprocess.Popen | None = None
        self.rpc_url = "http://127.0.0.1:6800/jsonrpc"
        self._id_counter = 0

    def start(self):
        if self.process and self.process.poll() is None:
            return

        session_file = DATA_DIR / "aria2.session"
        if not session_file.exists():
            session_file.touch()

        cmd = [
            self.aria2c_path,
            "--enable-rpc",
            "--rpc-listen-port=6800",
            "--rpc-listen-all=false",
            "--dir",
            str(DOWNLOADS_DIR),
            "--continue=true",
            f"--split={self.download_threads}",
            f"--max-connection-per-server={self.download_threads}",
            "--auto-file-renaming=false",
            "--max-concurrent-downloads=3",
            f"--save-session={session_file}",
            f"--input-file={session_file}",
            "--save-session-interval=10",
            "--quiet",
        ]
        if self.proxy:
            cmd.append(f"--all-proxy={self.proxy}")
        if self.extra_args:
            import shlex

            cmd.extend(shlex.split(self.extra_args, posix=(sys.platform != "win32")))
        kwargs: dict = dict(stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if sys.platform == "win32":
            kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
        self.process = subprocess.Popen(cmd, **kwargs)

    def stop(self):
        if self.process and self.process.poll() is None:
            try:
                asyncio.run(self._rpc_call("aria2.shutdown"))
            except Exception:
                self.process.terminate()
            self.process.wait()

    async def _rpc_call(self, method: str, params: list | None = None):
        self._id_counter += 1
        payload = {
            "jsonrpc": "2.0",
            "id": str(self._id_counter),
            "method": method,
            "params": params or [],
        }
        last_err = None
        for attempt in range(10):
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.post(
                        self.rpc_url,
                        json=payload,
                        timeout=aiohttp.ClientTimeout(total=5),
                    ) as resp:
                        data = await resp.json()
                        if "error" in data:
                            raise Exception(data["error"]["message"])
                        return data.get("result")
            except (aiohttp.ClientConnectorError, ConnectionRefusedError, OSError) as e:
                last_err = e
                await asyncio.sleep(0.3)
        raise last_err or Exception("aria2 RPC not reachable")

    async def add_uri(self, url: str, filename: str) -> str:
        result = await self._rpc_call(
            "aria2.addUri",
            [[url], {"out": filename}],
        )
        return result

    async def pause(self, gid: str):
        await self._rpc_call("aria2.pause", [gid])

    async def unpause(self, gid: str):
        await self._rpc_call("aria2.unpause", [gid])

    async def remove(self, gid: str):
        try:
            await self._rpc_call("aria2.remove", [gid])
        except Exception:
            pass
        try:
            await self._rpc_call("aria2.removeDownloadResult", [gid])
        except Exception:
            pass

    async def tell_active(self) -> list[dict]:
        return (
            await self._rpc_call(
                "aria2.tellActive",
                [
                    [
                        "gid",
                        "status",
                        "totalLength",
                        "completedLength",
                        "downloadSpeed",
                        "files",
                        "errorMessage",
                    ]
                ],
            )
            or []
        )

    async def tell_waiting(self, offset: int = 0, num: int = 100) -> list[dict]:
        return (
            await self._rpc_call(
                "aria2.tellWaiting",
                [
                    offset,
                    num,
                    [
                        "gid",
                        "status",
                        "totalLength",
                        "completedLength",
                        "downloadSpeed",
                        "files",
                        "errorMessage",
                    ],
                ],
            )
            or []
        )

    async def tell_stopped(self, offset: int = 0, num: int = 100) -> list[dict]:
        return (
            await self._rpc_call(
                "aria2.tellStopped",
                [
                    offset,
                    num,
                    [
                        "gid",
                        "status",
                        "totalLength",
                        "completedLength",
                        "downloadSpeed",
                        "files",
                        "errorCode",
                        "errorMessage",
                    ],
                ],
            )
            or []
        )


class AiohttpDownloader:
    def __init__(self, settings: "SettingsBackend"):
        self.settings = settings
        self._downloads: dict[str, DownloadItem] = {}
        self._tasks: dict[str, asyncio.Task] = {}
        self._counter = 0
        self._loop: asyncio.AbstractEventLoop | None = None
        self._num_threads = max(1, min(int(settings.get("download_threads") or 4), 16))

    def _get_loop(self):
        if self._loop is None or self._loop.is_closed():
            self._loop = asyncio.new_event_loop()
        return self._loop

    def add_download(self, url: str, filename: str) -> str:
        self._counter += 1
        gid = f"aio-{self._counter}"
        item = DownloadItem(
            gid=gid, filename=filename, url=url, status="active", pausable=False
        )
        self._downloads[gid] = item
        return gid

    async def _download_chunk(
        self,
        session: aiohttp.ClientSession,
        url: str,
        filepath: Path,
        start: int,
        end: int,
        item: DownloadItem,
    ):
        headers = {"Range": f"bytes={start}-{end}"}
        async with session.get(url, headers=headers) as resp:
            if resp.status not in (200, 206):
                raise Exception(f"HTTP {resp.status} for chunk {start}-{end}")
            with filepath.open("r+b") as f:
                f.seek(start)
                async for chunk in resp.content.iter_chunked(65536):
                    f.write(chunk)
                    item.downloaded += len(chunk)
                    if item.total_size > 0:
                        item.progress = item.downloaded / item.total_size

    async def run_download(self, gid: str):
        item = self._downloads.get(gid)
        if not item:
            return

        filepath = DOWNLOADS_DIR / item.filename

        try:
            connector = await self.settings.api.get_connector()
            async with aiohttp.ClientSession(connector=connector) as session:
                # Probe for size and range support
                async with session.head(item.url) as head_resp:
                    total = int(head_resp.headers.get("Content-Length", 0))
                    accept_ranges = head_resp.headers.get("Accept-Ranges", "none")

                supports_ranges = accept_ranges != "none" and total > 0
                n = self._num_threads if supports_ranges and total > 1024 * 1024 else 1

                # Resume support: if file exists and is partially downloaded
                existing_size = filepath.stat().st_size if filepath.exists() else 0

                if n > 1 and existing_size == 0:
                    # Multithreaded: pre-allocate file and download chunks in parallel
                    item.total_size = total
                    item.downloaded = 0
                    item._multithreaded = True
                    with filepath.open("wb") as f:
                        f.seek(total - 1)
                        f.write(b"\0")

                    chunk_size = total // n
                    tasks = []
                    for i in range(n):
                        start = i * chunk_size
                        end = (start + chunk_size - 1) if i < n - 1 else (total - 1)
                        tasks.append(
                            self._download_chunk(
                                session, item.url, filepath, start, end, item
                            )
                        )
                    await asyncio.gather(*tasks)
                else:
                    # Single-connection (with resume support)
                    headers = {}
                    if existing_size and supports_ranges:
                        headers["Range"] = f"bytes={existing_size}-"

                    async with session.get(item.url, headers=headers) as resp:
                        if resp.status == 416:
                            item.status = "complete"
                            item.progress = 1.0
                            return

                        if resp.status not in (200, 206):
                            item.status = "error"
                            item.error_message = f"HTTP {resp.status}"
                            return

                        content_len = int(resp.headers.get("Content-Length", 0))
                        if resp.status == 206:
                            item.total_size = existing_size + content_len
                            item.downloaded = existing_size
                        else:
                            item.total_size = content_len
                            existing_size = 0

                        mode = "ab" if resp.status == 206 else "wb"
                        with filepath.open(mode) as f:
                            async for chunk in resp.content.iter_chunked(65536):
                                f.write(chunk)
                                item.downloaded += len(chunk)
                                if item.total_size > 0:
                                    item.progress = item.downloaded / item.total_size

                item.status = "complete"
                item.progress = 1.0
        except Exception as e:
            item.status = "error"
            item.error_message = str(e)

    def get_all_items(self) -> list[DownloadItem]:
        return list(self._downloads.values())

    def remove(self, gid: str):
        self._downloads.pop(gid, None)


class Backend(QObject):
    downloads_updated = Signal(list)  # list of dicts
    history_updated = Signal(list)  # list of history entry dicts

    @Property(bool, constant=True)
    def has_aria2(self) -> bool:
        return self._aria2 is not None

    def __init__(self, settings: "SettingsBackend"):
        super().__init__()
        self.settings = settings
        self._items: dict[str, DownloadItem] = {}
        self._aria2: Aria2Daemon | None = None
        self._aiohttp_dl: AiohttpDownloader | None = None
        self._workers: list = []
        self._meta = DownloadMetadata()
        self._history = DownloadHistory()
        self._recorded_history: set[str] = set()  # gids already added to history
        self._muxing: set[str] = set()  # gids currently being muxed
        self._hidden_gids: set[str] = set()  # subs gids hidden from the UI
        self._cancelled_gids: set[str] = set()  # gids being cancelled; prevent poll re-adding them

        self._poll_timer = None
        self._polling = False  # guard against stacking poll workers

        aria2c_path = settings.get("aria2c_path") or shutil.which("aria2c") or ""
        if aria2c_path:
            extra_args = settings.get("aria2c_args") or ""
            download_threads = int(settings.get("download_threads") or 4)
            proxy = ""
            if settings.get("downloader_use_proxy") and settings.get("proxy"):
                proxy = settings.get("proxy")
            self._aria2 = Aria2Daemon(aria2c_path, extra_args, download_threads, proxy)
        else:
            self._aiohttp_dl = AiohttpDownloader(settings)

    @Slot()
    def init(self):
        if self._poll_timer is None:
            self._poll_timer = QTimer(self)
            self._poll_timer.setInterval(500)
            self._poll_timer.timeout.connect(self._poll_progress)

        if self._aria2:
            session_file = DATA_DIR / "aria2.session"
            if session_file.exists() and session_file.stat().st_size > 0:
                self._ensure_aria2_running()

    def _ensure_aria2_running(self):
        if self._aria2:
            self._aria2.start()
            if self._poll_timer and not self._poll_timer.isActive():
                self._poll_timer.start()

    @Slot(str, str, str, str)
    def add_download(
        self, url: str, filename: str, subs_url: str = "", subs_filename: str = ""
    ):
        from .utils import AsyncFunctionWorker

        if self._aria2:
            self._ensure_aria2_running()

            async def _add():
                gid = await self._aria2.add_uri(url, filename)
                subs_gid = ""
                if subs_url and subs_filename:
                    subs_gid = await self._aria2.add_uri(subs_url, subs_filename)
                return [gid, subs_gid]

            worker = AsyncFunctionWorker(_add)
            worker.result_list.connect(
                lambda ids, _sf=subs_filename: self._register_aria2_items(
                    ids, filename, url, _sf
                )
            )
            self._workers.append(worker)
            worker.completed.connect(
                lambda *_: (
                    self._workers.remove(worker) if worker in self._workers else None
                )
            )
            worker.start()
        else:
            gid = self._aiohttp_dl.add_download(url, filename)
            item = self._aiohttp_dl._downloads[gid]
            self._items[gid] = item

            async def _run():
                await self._aiohttp_dl.run_download(gid)
                if subs_url and subs_filename:
                    subs_gid = self._aiohttp_dl.add_download(subs_url, subs_filename)
                    await self._aiohttp_dl.run_download(subs_gid)
                    new_name = await _embed_subs(
                        DOWNLOADS_DIR / filename,
                        DOWNLOADS_DIR / subs_filename,
                        self.settings.get("ffmpeg_path"),
                    )
                    if new_name and new_name != filename:
                        item = self._items.get(gid)
                        if item:
                            item.filename = new_name
                            meta = self._meta.get(filename)
                            if meta:
                                self._meta.record(new_name, meta)
                                self._meta.remove(filename)

            from .utils import AsyncFunctionWorker

            worker = AsyncFunctionWorker(_run)
            self._workers.append(worker)
            worker.completed.connect(
                lambda *_: (
                    self._workers.remove(worker) if worker in self._workers else None
                )
            )
            worker.start()

            if self._poll_timer and not self._poll_timer.isActive():
                self._poll_timer.start()

    def _register_item(
        self, gid: str, filename: str, url: str, subs_filename: str = ""
    ):
        self._items[gid] = DownloadItem(
            gid=gid,
            filename=filename,
            url=url,
            status="active",
            subs_filename=subs_filename,
        )

    def _register_aria2_items(
        self, ids: list, filename: str, url: str, subs_filename: str = ""
    ):
        if not ids:
            return
        video_gid = ids[0] if len(ids) > 0 else ""
        subs_gid = ids[1] if len(ids) > 1 else ""
        if video_gid:
            self._register_item(video_gid, filename, url, subs_filename)
        if subs_gid:
            self._hidden_gids.add(subs_gid)

    @Slot(str)
    def pause_download(self, gid: str):
        from .utils import AsyncFunctionWorker

        if self._aria2:
            worker = AsyncFunctionWorker(self._aria2.pause, gid)
            self._workers.append(worker)
            worker.completed.connect(
                lambda *_: (
                    self._workers.remove(worker) if worker in self._workers else None
                )
            )
            worker.start()

            if self._poll_timer and not self._poll_timer.isActive():
                self._poll_timer.start()
        # aiohttp downloads are not pausable

    @Slot(str)
    def resume_download(self, gid: str):
        from .utils import AsyncFunctionWorker

        if self._aria2:
            worker = AsyncFunctionWorker(self._aria2.unpause, gid)
            self._workers.append(worker)
            worker.completed.connect(
                lambda *_: (
                    self._workers.remove(worker) if worker in self._workers else None
                )
            )
            worker.start()
            if self._poll_timer and not self._poll_timer.isActive():
                self._poll_timer.start()
        # aiohttp downloads are not pausable

    @Slot(str)
    def retry_download(self, gid: str):
        item = self._items.get(gid)
        if not item or item.status != "error":
            return
        url = item.url
        filename = item.filename
        # Drop the errored entry before re-adding so it gets a fresh slot
        self._items.pop(gid, None)
        if self._aria2:
            from .utils import AsyncFunctionWorker

            async def _remove_and_readd():
                try:
                    await self._aria2.remove(gid)
                except Exception:
                    pass
                return await self._aria2.add_uri(url, filename)

            worker = AsyncFunctionWorker(_remove_and_readd)
            worker.result_str.connect(
                lambda new_gid: self._register_item(new_gid, filename, url)
            )
            self._workers.append(worker)
            worker.completed.connect(
                lambda *_: (
                    self._workers.remove(worker) if worker in self._workers else None
                )
            )
            worker.start()
        elif self._aiohttp_dl:
            self._aiohttp_dl.remove(gid)
            new_gid = self._aiohttp_dl.add_download(url, filename)
            new_item = self._aiohttp_dl._downloads[new_gid]
            self._items[new_gid] = new_item

            from .utils import AsyncFunctionWorker

            worker = AsyncFunctionWorker(self._aiohttp_dl.run_download, new_gid)
            self._workers.append(worker)
            worker.completed.connect(
                lambda *_: (
                    self._workers.remove(worker) if worker in self._workers else None
                )
            )
            worker.start()

            if self._poll_timer and not self._poll_timer.isActive():
                self._poll_timer.start()

        self._emit_updates()

    @Slot(str)
    def cancel_download(self, gid: str):
        from .utils import AsyncFunctionWorker

        item = self._items.get(gid)
        filename = item.filename if item else None

        if self._aria2:
            self._cancelled_gids.add(gid)  # prevent poll from re-adding before removal completes
            worker = AsyncFunctionWorker(self._aria2.remove, gid)
            self._workers.append(worker)
            worker.completed.connect(
                lambda *_: (
                    self._workers.remove(worker) if worker in self._workers else None
                )
            )
            worker.start()
        elif self._aiohttp_dl:
            self._aiohttp_dl.remove(gid)

        self._items.pop(gid, None)

        # Delete partial file and associated subs from disk
        if filename:
            filepath = DOWNLOADS_DIR / filename
            filepath.unlink(missing_ok=True)
            # Also remove subs with matching stem
            stem = Path(filename).stem
            for ext in (".ass", ".srt", ".ssa"):
                (DOWNLOADS_DIR / (stem + ext)).unlink(missing_ok=True)
            self._meta.remove(filename)

        self._emit_updates()

    @Slot()
    def clear_completed(self):
        completed = [
            gid for gid, item in self._items.items() if item.status == "complete"
        ]
        for gid in completed:
            self._items.pop(gid, None)
            if self._aria2:
                from .utils import AsyncFunctionWorker

                worker = AsyncFunctionWorker(self._aria2.remove, gid)
                self._workers.append(worker)
                worker.completed.connect(
                    lambda *_: (
                        self._workers.remove(worker)
                        if worker in self._workers
                        else None
                    )
                )
                worker.start()
        self._emit_updates()

    @Slot(result=list)
    def get_downloads(self) -> list[dict]:
        return [item.to_dict() for item in self._items.values()]

    @Slot(result=list)
    def get_history(self) -> list[dict]:
        return self._history.get_all()

    @Slot(int)
    def remove_history_item(self, index: int):
        self._history.remove(index)
        self.history_updated.emit(self._history.get_all())

    @Slot(int)
    def delete_history_item(self, index: int):
        entries = self._history.get_all()
        if 0 <= index < len(entries):
            filename = entries[index].get("filename", "")
            if filename:
                filepath = DOWNLOADS_DIR / filename
                filepath.unlink(missing_ok=True)
                stem = Path(filename).stem
                for ext in (".ass", ".srt", ".ssa"):
                    (DOWNLOADS_DIR / (stem + ext)).unlink(missing_ok=True)
                self._meta.remove(filename)
        self._history.remove(index)
        self.history_updated.emit(self._history.get_all())

    @Slot()
    def clear_history(self):
        self._history.clear()
        self.history_updated.emit(self._history.get_all())

    @Slot(str, result=str)
    def get_local_file(self, filename: str) -> str:
        filepath = DOWNLOADS_DIR / filename
        if filepath.exists() and filepath.stat().st_size > 0:
            return str(filepath)
        return ""

    @Slot(str, str, str, str, str, str, result=str)
    def resolve_filename(
        self,
        base_filename: str,
        anime_title: str,
        episode: str,
        translation: str,
        video_source: str,
        file_type: str,
    ) -> str:
        stem = Path(base_filename).stem
        ext = Path(base_filename).suffix

        # Check if we already have this exact translation downloaded
        existing = self._meta.find(
            anime_title=anime_title,
            episode=episode,
            translation=translation,
            file_type=file_type,
        )
        if video_source:
            existing = [
                (f, m) for f, m in existing if m.get("video_source") == video_source
            ]
        if existing:
            return existing[0][0]

        # Check if the base filename is free
        if base_filename not in self._meta._data:
            filepath = DOWNLOADS_DIR / base_filename
            if not filepath.exists():
                return base_filename

        # Find a free numbered variant
        for i in range(2, 100):
            candidate = f"{stem}_{i}{ext}"
            if candidate not in self._meta._data:
                filepath = DOWNLOADS_DIR / candidate
                if not filepath.exists():
                    return candidate
        return base_filename

    @Slot(str, str, str, str, str, str)
    def record_meta(
        self,
        filename: str,
        anime_title: str,
        episode: str,
        translation: str,
        video_source: str,
        quality: str = "",
    ):
        ext = Path(filename).suffix
        file_type = "subs" if ext in (".ass", ".srt", ".ssa") else "video"
        self._meta.record(
            filename,
            {
                "anime_title": anime_title,
                "episode": episode,
                "translation": translation,
                "video_source": video_source,
                "quality": quality,
                "file_type": file_type,
            },
        )

    @Slot(str, str, str, str, result=dict)
    def find_downloaded_video(
        self, anime_title: str, episode: str, translation: str, quality: str
    ) -> dict:
        def _parse_height(q: str) -> int:
            s = q.rstrip("p")
            return int(s) if s.isdigit() else 0

        sel_h = _parse_height(quality)

        # Gather all valid downloads for this episode, prune stale entries
        all_matches = self._meta.find(
            anime_title=anime_title,
            episode=episode,
            file_type="video",
        )
        stale = []
        valid: list[tuple[str, dict]] = []
        for fname, meta in all_matches:
            filepath = DOWNLOADS_DIR / fname
            if filepath.exists() and filepath.stat().st_size > 0:
                valid.append((fname, meta))
            else:
                stale.append(fname)
        for fname in stale:
            self._meta.remove(fname)

        # Split into exact-TL and other-TL
        exact = [(f, m) for f, m in valid if m.get("translation") == translation]
        others = [(f, m) for f, m in valid if m.get("translation") != translation]

        # Collect unique other translation names
        other_tls = list(dict.fromkeys(m.get("translation", "") for _, m in others))

        result = {}
        if exact:
            fname, meta = exact[0]
            dl_h = _parse_height(meta.get("quality", ""))
            result = {
                "path": str(DOWNLOADS_DIR / fname),
                "exact_match": True,
                "translation": meta.get("translation", ""),
                "quality": meta.get("quality", ""),
                "lower_quality": sel_h > dl_h > 0,
                "higher_quality": dl_h > sel_h > 0,
            }
        elif others:
            # Don't set path — just report what's available
            # Pick highest quality other download for display
            best_m, best_h = others[0][1], -1
            for _, meta in others:
                dl_h = _parse_height(meta.get("quality", ""))
                if dl_h > best_h:
                    best_h = dl_h
                    best_m = meta
            result = {
                "path": "",
                "exact_match": False,
                "translation": best_m.get("translation", ""),
                "quality": best_m.get("quality", ""),
                "lower_quality": False,
                "higher_quality": False,
            }

        if result:
            result["other_count"] = len(other_tls)
            result["other_first_tl"] = other_tls[0] if other_tls else ""

        return result

    @Slot(str, str, str, result=str)
    def find_downloaded_subs(
        self, anime_title: str, episode: str, translation: str
    ) -> str:
        matches = self._meta.find(
            anime_title=anime_title,
            episode=episode,
            translation=translation,
            file_type="subs",
        )
        for fname, meta in matches:
            filepath = DOWNLOADS_DIR / fname
            if filepath.exists() and filepath.stat().st_size > 0:
                return str(filepath)
        return ""

    def _poll_progress(self):
        from .utils import AsyncFunctionWorker

        if self._polling:
            return
        self._polling = True

        if self._aria2:

            async def _poll():
                try:
                    active = await self._aria2.tell_active()
                    waiting = await self._aria2.tell_waiting()
                    stopped = await self._aria2.tell_stopped()
                    return active + waiting + stopped
                except Exception:
                    # aria2c unreachable — restart if the process died
                    if self._aria2.process and self._aria2.process.poll() is not None:
                        self._aria2.start()
                    return []

            worker = AsyncFunctionWorker(_poll)
            worker.result_list.connect(self._update_aria2_items)
            self._workers.append(worker)

            def _on_done():
                self._polling = False
                if worker in self._workers:
                    self._workers.remove(worker)

            worker.completed.connect(_on_done)
            worker.start()
        else:
            # aiohttp fallback: items are updated in-place
            self._polling = False
            self._emit_updates()

    def _update_aria2_items(self, results: list):
        seen_gids = {r["gid"] for r in results}
        # Keep only cancelled GIDs still visible in aria2 (once gone, cleanup is done)
        self._cancelled_gids &= seen_gids

        for r in results:
            gid = r["gid"]
            if gid in self._hidden_gids:
                continue
            if gid in self._cancelled_gids:
                continue  # cancel pending in aria2, don't re-add to tracked items
            if gid not in self._items:
                # Discovered a download we didn't track (e.g. from previous session)
                files = r.get("files", [])
                filename = (
                    Path(files[0]["path"]).name
                    if files and files[0].get("path")
                    else gid
                )
                self._items[gid] = DownloadItem(gid=gid, filename=filename, url="")

            item = self._items[gid]

            # Don't overwrite status while muxing
            if gid in self._muxing:
                continue

            item.status = r["status"]
            item.total_size = int(r.get("totalLength", 0))
            item.downloaded = int(r.get("completedLength", 0))
            item.speed = int(r.get("downloadSpeed", 0))
            if item.total_size > 0:
                item.progress = item.downloaded / item.total_size
            if r.get("errorMessage"):
                item.error_message = r["errorMessage"]

            # Trigger sub embedding when video is done
            if (
                item.status == "complete"
                and item.subs_filename
                and gid not in self._recorded_history
            ):
                subs_path = DOWNLOADS_DIR / item.subs_filename
                if subs_path.exists():
                    self._muxing.add(gid)
                    item.status = "muxing"

                    async def _do_mux(
                        _vfn=item.filename,
                        _sfn=item.subs_filename,
                        _ffmpeg=self.settings.get("ffmpeg_path"),
                    ) -> str:
                        return await _embed_subs(
                            DOWNLOADS_DIR / _vfn, DOWNLOADS_DIR / _sfn, _ffmpeg
                        )

                    from .utils import AsyncFunctionWorker

                    mux_worker = AsyncFunctionWorker(_do_mux)

                    def _on_mux_done(new_name: str, _gid=gid, _vfn=item.filename):
                        self._muxing.discard(_gid)
                        if _gid in self._items:
                            self._items[_gid].status = "complete"
                            if new_name and new_name != _vfn:
                                self._items[_gid].filename = new_name
                                meta = self._meta.get(_vfn)
                                if meta:
                                    self._meta.record(new_name, meta)
                                    self._meta.remove(_vfn)
                        self._emit_updates()

                    mux_worker.result_str.connect(_on_mux_done)
                    self._workers.append(mux_worker)
                    mux_worker.completed.connect(
                        lambda *_, w=mux_worker: (
                            self._workers.remove(w) if w in self._workers else None
                        )
                    )
                    mux_worker.start()

        self._emit_updates()

    def _emit_updates(self):
        # Record newly completed downloads to history
        for gid, item in self._items.items():
            if item.status == "complete" and gid not in self._recorded_history:
                self._recorded_history.add(gid)
                meta = self._meta.get(item.filename)
                size = item.total_size or item.downloaded
                if not size:
                    filepath = DOWNLOADS_DIR / item.filename
                    if filepath.exists():
                        size = filepath.stat().st_size
                self._history.add(item.filename, size, meta)
                self.history_updated.emit(self._history.get_all())

        self.downloads_updated.emit([item.to_dict() for item in self._items.values()])

        # Stop polling if no active downloads
        has_active = any(
            item.status in ("active", "waiting") for item in self._items.values()
        )
        if not has_active and self._poll_timer and self._poll_timer.isActive():
            self._poll_timer.stop()

    def shutdown(self):
        if self._poll_timer:
            self._poll_timer.stop()
        if self._aria2:
            self._aria2.stop()
