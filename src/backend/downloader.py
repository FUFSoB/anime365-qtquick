import asyncio
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import TYPE_CHECKING

import aiohttp
from PySide6.QtCore import QObject, QTimer, Signal, Slot

from constants import DOWNLOADS_DIR

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend

IS_ANDROID = hasattr(sys, "getandroidapilevel")


@dataclass
class DownloadItem:
    gid: str
    filename: str
    url: str
    status: str = "waiting"  # waiting, active, complete, error, paused
    progress: float = 0.0
    speed: int = 0
    total_size: int = 0
    downloaded: int = 0
    error_message: str = ""

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
        }


class Aria2Daemon:
    def __init__(self, aria2c_path: str, extra_args: str = "", download_threads: int = 4):
        self.aria2c_path = aria2c_path
        self.extra_args = extra_args
        self.download_threads = max(1, min(download_threads, 16))
        self.process: subprocess.Popen | None = None
        self.rpc_url = "http://localhost:6800/jsonrpc"
        self._id_counter = 0

    def start(self):
        if self.process and self.process.poll() is None:
            return
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
            "--quiet",
        ]
        if self.extra_args:
            import shlex
            cmd.extend(shlex.split(self.extra_args, posix=(sys.platform != "win32")))
        self.process = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def stop(self):
        if self.process and self.process.poll() is None:
            try:
                asyncio.run(self._rpc_call("aria2.shutdown"))
            except Exception:
                self.process.terminate()

    async def _rpc_call(self, method: str, params: list | None = None):
        self._id_counter += 1
        payload = {
            "jsonrpc": "2.0",
            "id": str(self._id_counter),
            "method": method,
            "params": params or [],
        }
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
            await self._rpc_call("aria2.removeDownloadResult", [gid])

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
        item = DownloadItem(gid=gid, filename=filename, url=url, status="active")
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
            offset = start
            with filepath.open("r+b") as f:
                f.seek(start)
                async for chunk in resp.content.iter_chunked(65536):
                    if item.status == "paused":
                        return
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
                    with filepath.open("wb") as f:
                        f.seek(total - 1)
                        f.write(b"\0")

                    chunk_size = total // n
                    tasks = []
                    for i in range(n):
                        start = i * chunk_size
                        end = (start + chunk_size - 1) if i < n - 1 else (total - 1)
                        tasks.append(
                            self._download_chunk(session, item.url, filepath, start, end, item)
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
                                if item.status == "paused":
                                    return
                                f.write(chunk)
                                item.downloaded += len(chunk)
                                if item.total_size > 0:
                                    item.progress = item.downloaded / item.total_size

                if item.status != "paused":
                    item.status = "complete"
                    item.progress = 1.0
        except asyncio.CancelledError:
            item.status = "paused"
        except Exception as e:
            item.status = "error"
            item.error_message = str(e)

    def get_all_items(self) -> list[DownloadItem]:
        return list(self._downloads.values())

    def pause(self, gid: str):
        item = self._downloads.get(gid)
        if item:
            item.status = "paused"

    def remove(self, gid: str):
        self._downloads.pop(gid, None)


class Backend(QObject):
    downloads_updated = Signal(list)  # list of dicts

    def __init__(self, settings: "SettingsBackend"):
        super().__init__()
        self.settings = settings
        self._items: dict[str, DownloadItem] = {}
        self._aria2: Aria2Daemon | None = None
        self._aiohttp_dl: AiohttpDownloader | None = None
        self._workers: list = []

        self._poll_timer = QTimer()
        self._poll_timer.setInterval(500)
        self._poll_timer.timeout.connect(self._poll_progress)
        self._polling = False  # guard against stacking poll workers

        aria2c_path = settings.get("aria2c_path") or shutil.which("aria2c") or ""
        if aria2c_path and not IS_ANDROID:
            extra_args = settings.get("aria2c_args") or ""
            download_threads = int(settings.get("download_threads") or 4)
            self._aria2 = Aria2Daemon(aria2c_path, extra_args, download_threads)
        else:
            self._aiohttp_dl = AiohttpDownloader(settings)

    def _ensure_aria2_running(self):
        if self._aria2:
            self._aria2.start()
            if not self._poll_timer.isActive():
                self._poll_timer.start()

    @Slot(str, str)
    def add_download(self, url: str, filename: str):
        from .utils import AsyncFunctionWorker

        if self._aria2:
            self._ensure_aria2_running()

            async def _add():
                gid = await self._aria2.add_uri(url, filename)
                return gid

            worker = AsyncFunctionWorker(_add)
            worker.result_str.connect(
                lambda gid: self._register_item(gid, filename, url)
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

            from .utils import AsyncFunctionWorker

            worker = AsyncFunctionWorker(_run)
            self._workers.append(worker)
            worker.completed.connect(
                lambda *_: (
                    self._workers.remove(worker) if worker in self._workers else None
                )
            )
            worker.start()

            if not self._poll_timer.isActive():
                self._poll_timer.start()

    def _register_item(self, gid: str, filename: str, url: str):
        self._items[gid] = DownloadItem(
            gid=gid, filename=filename, url=url, status="active"
        )

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
        elif self._aiohttp_dl:
            self._aiohttp_dl.pause(gid)

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
        elif self._aiohttp_dl:
            item = self._aiohttp_dl._downloads.get(gid)
            if item and item.status == "paused":
                item.status = "active"

                async def _run():
                    await self._aiohttp_dl.run_download(gid)

                from .utils import AsyncFunctionWorker

                worker = AsyncFunctionWorker(_run)
                self._workers.append(worker)
                worker.completed.connect(
                    lambda *_: (
                        self._workers.remove(worker)
                        if worker in self._workers
                        else None
                    )
                )
                worker.start()

    @Slot(str)
    def cancel_download(self, gid: str):
        from .utils import AsyncFunctionWorker

        if self._aria2:
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

    def _poll_progress(self):
        from .utils import AsyncFunctionWorker

        if self._polling:
            return
        self._polling = True

        if self._aria2:

            async def _poll():
                active = await self._aria2.tell_active()
                waiting = await self._aria2.tell_waiting()
                stopped = await self._aria2.tell_stopped()
                return active + waiting + stopped

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
        for r in results:
            gid = r["gid"]
            if gid not in self._items:
                # Discovered a download we didn't track (e.g. from previous session)
                files = r.get("files", [])
                filename = Path(files[0]["path"]).name if files else gid
                self._items[gid] = DownloadItem(gid=gid, filename=filename, url="")

            item = self._items[gid]
            item.status = r["status"]
            item.total_size = int(r.get("totalLength", 0))
            item.downloaded = int(r.get("completedLength", 0))
            item.speed = int(r.get("downloadSpeed", 0))
            if item.total_size > 0:
                item.progress = item.downloaded / item.total_size
            if r.get("errorMessage"):
                item.error_message = r["errorMessage"]

        self._emit_updates()

    def _emit_updates(self):
        self.downloads_updated.emit([item.to_dict() for item in self._items.values()])

        # Stop polling if no active downloads
        has_active = any(
            item.status in ("active", "waiting") for item in self._items.values()
        )
        if not has_active and self._poll_timer.isActive():
            self._poll_timer.stop()

    def shutdown(self):
        self._poll_timer.stop()
        if self._aria2:
            self._aria2.stop()
