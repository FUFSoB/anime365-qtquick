import asyncio
import subprocess
import traceback

import aiohttp
import ass
from PySide6.QtCore import QThread, Signal


async def monitor_mpv_status(
    process: subprocess.Popen[bytes],
    ipc_path: str,
    title: str = "",
    episode: str = "",
    cover_url: str = "",
) -> bool:
    import json as _json
    import sys as _sys
    import time as _time

    try:
        from .discord_rpc import DiscordRPC

        rpc = DiscordRPC()
    except ImportError:
        rpc = None

    start_time = _time.time()
    if rpc and title:
        await rpc.update(title=title, episode=episode, cover_url=cover_url)

    # Wait for mpv to create the IPC socket
    await asyncio.sleep(1)

    max_percent = 0.0
    completed = False

    try:
        if _sys.platform == "win32":
            reader, writer = await asyncio.open_connection(ipc_path)
        else:
            reader, writer = await asyncio.open_unix_connection(ipc_path)

        # Observe percent-pos (1), time-pos (2), duration (3), pause (4)
        for obs_id, prop in [
            (1, "percent-pos"),
            (2, "time-pos"),
            (3, "duration"),
            (4, "pause"),
        ]:
            writer.write(
                (
                    _json.dumps({"command": ["observe_property", obs_id, prop]}) + "\n"
                ).encode()
            )
        await writer.drain()

        time_pos = 0.0
        duration = 0.0
        is_paused = False
        last_rpc_update = 0.0
        RPC_DRIFT_INTERVAL = 30.0  # periodic re-sync to correct wall-clock drift

        async def push_rpc():
            nonlocal last_rpc_update
            if not rpc or not title:
                return
            now = _time.time()
            if is_paused:
                # Use session start so elapsed time keeps ticking stably; no end = no bar
                await rpc.update(
                    title=title,
                    episode=episode,
                    start_time=start_time,
                    cover_url=cover_url,
                    paused=True,
                )
            else:
                end_ts = (now + (duration - time_pos)) if duration > 0 else None
                await rpc.update(
                    title=title,
                    episode=episode,
                    start_time=now - time_pos,
                    end_time=end_ts,
                    cover_url=cover_url,
                )
            last_rpc_update = now

        while process.poll() is None:
            try:
                line = await asyncio.wait_for(reader.readline(), timeout=2.0)
                if not line:
                    break
                data = _json.loads(line)
                if data.get("event") == "property-change":
                    name = data.get("name")
                    val = data.get("data")
                    if name == "percent-pos" and isinstance(val, (int, float)):
                        if val > max_percent:
                            max_percent = val
                            if max_percent >= 85:
                                completed = True
                    elif name == "time-pos" and isinstance(val, (int, float)):
                        time_pos = val
                    elif name == "duration" and isinstance(val, (int, float)):
                        duration = val
                        await push_rpc()  # progress bar becomes available
                    elif name == "pause" and isinstance(val, bool):
                        is_paused = val
                        await push_rpc()  # immediate update on pause/resume

                    # Periodic drift correction while playing
                    if (
                        not is_paused
                        and (_time.time() - last_rpc_update) >= RPC_DRIFT_INTERVAL
                    ):
                        await push_rpc()
            except asyncio.TimeoutError:
                continue
            except Exception:
                break

        writer.close()
    except (ConnectionRefusedError, FileNotFoundError, OSError):
        # IPC not available — just wait for process to exit
        while process.poll() is None:
            await asyncio.sleep(1)

    # Ensure process is done
    process.wait()

    if rpc:
        await rpc.clear()
        await rpc.disconnect()

    return completed


async def get_subtitle_fonts(url: str) -> list[str]:
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            if response.status != 200:
                return []

            subtitle_bytes = await response.read()
            # file can be with or without BOM
            subtitle_content = subtitle_bytes.decode("utf-8-sig", errors="replace")

            try:
                subtitle = ass.parse_string(subtitle_content)
                styles: list[ass.Style] = subtitle.styles

                return sorted({style.fontname for style in styles})

            except Exception as e:
                print(f"Error parsing subtitle file: {e}")
                return []


class AsyncFunctionWorker(QThread):
    result_bool = Signal(bool)
    result_str = Signal(str)
    result_list = Signal(list)
    result_dict = Signal(dict)

    completed = Signal()
    error = Signal(str)

    def __init__(self, func, *args, **kwargs):
        super().__init__()
        self.func = func
        self.args = args
        self.kwargs = kwargs

    def run(self):
        try:
            result = asyncio.run(self.func(*self.args, **self.kwargs))
        except Exception:
            self.error.emit(traceback.format_exc())
            return

        self.completed.emit()

        if isinstance(result, bool):
            self.result_bool.emit(result)
        elif isinstance(result, str):
            self.result_str.emit(result)
        elif isinstance(result, list):
            self.result_list.emit(result)
        elif isinstance(result, dict):
            self.result_dict.emit(result)
