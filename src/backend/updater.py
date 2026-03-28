import atexit
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import TYPE_CHECKING

import aiohttp
from PySide6.QtCore import QObject, Signal, Slot

from constants import APP_VERSION, FROZEN

from .utils import AsyncFunctionWorker

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend

RELEASES_URL = "https://api.github.com/repos/FUFSoB/anime365-qtquick/releases/latest"


def _parse_version(tag: str) -> tuple:
    clean = tag.lstrip("v")
    try:
        return tuple(int(x) for x in clean.split("."))
    except ValueError:
        return (0,)


def _platform_asset_names() -> tuple[str, str]:
    if sys.platform == "win32":
        return "Anime365-windows.exe", "Anime365-windows.exe.patch"
    elif sys.platform == "darwin":
        return "Anime365-macos", "Anime365-macos.patch"
    else:
        return "Anime365-linux", "Anime365-linux.patch"


def _replace_binary(target: Path, new_binary: Path) -> None:
    new_binary.chmod(0o755)
    if sys.platform == "win32":
        pending = target.parent / "_Anime365-update.exe"
        shutil.copy2(new_binary, pending)
        bat = target.parent / "_Anime365-update.bat"
        bat.write_text(
            f"@echo off\r\n"
            f"timeout /t 2 /nobreak >nul\r\n"
            f'move /y "{pending}" "{target}"\r\n'
            f'start "" "{target}"\r\n'
            f'del "%~f0"\r\n',
            encoding="utf-8",
        )
        atexit.register(
            lambda: subprocess.Popen(
                ["cmd", "/c", str(bat)],
                creationflags=subprocess.DETACHED_PROCESS
                | subprocess.CREATE_NEW_PROCESS_GROUP,
                close_fds=True,
            )
        )
    else:
        # Copy to the same filesystem as target first to avoid EXDEV
        # (os.replace fails across devices, e.g. /tmp on tmpfs vs exe on ext4)
        tmp = target.with_suffix(".tmp_update")
        try:
            shutil.copy2(new_binary, tmp)
            os.replace(tmp, target)
        finally:
            tmp.unlink(missing_ok=True)


class Backend(QObject):
    update_found = Signal(
        str, str, str
    )  # new_version_tag, release_url, current_version
    update_progress = Signal(int)  # 0-100
    update_status = Signal(str)
    update_ready = Signal()
    update_failed = Signal(str)

    def __init__(self, settings: "SettingsBackend"):
        super().__init__()
        self.settings = settings
        self._worker = None
        self._dl_worker = None
        self._assets = []

    @Slot()
    def check(self):
        if not FROZEN:
            return
        if not self.settings.get_settings().get("check_updates", True):
            return

        async def _do_check():
            headers = {"User-Agent": "anime365-qtquick"}
            connector = await self.settings.api.get_connector()
            async with aiohttp.ClientSession(connector=connector) as session:
                async with session.get(RELEASES_URL, headers=headers) as response:
                    if response.status != 200:
                        return {}
                    return await response.json()

        self._worker = AsyncFunctionWorker(_do_check)
        self._worker.result_dict.connect(self._on_result)
        self._worker.start()

    def _on_result(self, data: dict):
        self._assets = data.get("assets", [])
        tag = data.get("tag_name", "")
        html_url = data.get("html_url", "")
        if not tag:
            return
        if _parse_version(tag) > _parse_version(APP_VERSION):
            self.update_found.emit(tag, html_url, APP_VERSION)

    @Slot()
    def download_update(self):
        if not FROZEN:
            return

        asset_name, patch_name = _platform_asset_names()
        full_url = next(
            (
                a["browser_download_url"]
                for a in self._assets
                if a["name"] == asset_name
            ),
            None,
        )
        patch_url = next(
            (
                a["browser_download_url"]
                for a in self._assets
                if a["name"] == patch_name
            ),
            None,
        )

        backend = self

        async def _fetch(url: str, dest: Path, progress_scale: tuple[int, int]) -> None:
            lo, hi = progress_scale
            connector = await backend.settings.api.get_connector()
            headers = {"User-Agent": "anime365-qtquick"}
            async with aiohttp.ClientSession(
                connector=connector, headers=headers
            ) as session:
                async with session.get(url) as resp:
                    resp.raise_for_status()
                    total = int(resp.headers.get("Content-Length", 0))
                    done = 0
                    with dest.open("wb") as f:
                        async for chunk in resp.content.iter_chunked(65536):
                            f.write(chunk)
                            done += len(chunk)
                            if total:
                                pct = lo + int((hi - lo) * done / total)
                                backend.update_progress.emit(pct)

        async def _do_download() -> bool:
            tmp_dir = Path(tempfile.mkdtemp())
            try:
                use_patch = bool(patch_url and shutil.which("xdelta3"))

                if use_patch:
                    backend.update_status.emit("Downloading patch...")
                    patch_file = tmp_dir / "update.patch"
                    await _fetch(patch_url, patch_file, (0, 50))

                    backend.update_status.emit("Applying patch...")
                    new_binary = tmp_dir / asset_name
                    result = subprocess.run(
                        [
                            "xdelta3",
                            "-d",
                            "-s",
                            sys.executable,
                            str(patch_file),
                            str(new_binary),
                        ],
                        capture_output=True,
                    )
                    if result.returncode == 0:
                        backend.update_progress.emit(100)
                        backend.update_status.emit("Installing...")
                        _replace_binary(Path(sys.executable), new_binary)
                        return True

                    # patch failed — fall through to full download
                    backend.update_status.emit(
                        "Patch failed, downloading full binary..."
                    )

                if not full_url:
                    return False

                new_binary = tmp_dir / asset_name
                await _fetch(full_url, new_binary, (0, 100))
                backend.update_progress.emit(100)
                backend.update_status.emit("Installing...")
                _replace_binary(Path(sys.executable), new_binary)
                return True
            finally:
                shutil.rmtree(tmp_dir, ignore_errors=True)

        self._dl_worker = AsyncFunctionWorker(_do_download)
        self._dl_worker.result_bool.connect(
            lambda ok: (
                self.update_ready.emit()
                if ok
                else self.update_failed.emit("No download URL found")
            )
        )
        self._dl_worker.error.connect(self.update_failed.emit)
        self._dl_worker.start()
