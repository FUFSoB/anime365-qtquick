import asyncio
import re
import socket
import subprocess
import time
import traceback
from dataclasses import dataclass, field

import aiohttp
import ass
from PySide6.QtCore import QThread, Signal

_MPC_VAR_RE = re.compile(r'<p id="(\w+)">(.*?)</p>')
_ASS_TAG_RE = re.compile(r"\{[^}]*\}")

_SUBSET_RANGES: list[tuple[int, int, str]] = [
    (0x0400, 0x052F, "cyrillic"),
    (0x1C80, 0x1C8F, "cyrillic"),
    (0x3040, 0x309F, "japanese"),
    (0x30A0, 0x30FF, "japanese"),
    (0x4E00, 0x9FFF, "japanese"),
    (0x3400, 0x4DBF, "japanese"),
    (0xF900, 0xFAFF, "japanese"),
    (0xFF00, 0xFFEF, "japanese"),
    (0xAC00, 0xD7AF, "korean"),
    (0x1100, 0x11FF, "korean"),
    (0x0100, 0x024F, "latin-ext"),
    (0x1E00, 0x1EFF, "latin-ext"),
]


_ALL_SUBSETS = len({s for _, _, s in _SUBSET_RANGES})


def _detect_scripts(text: str) -> list[str]:
    found: set[str] = set()
    for ch in text:
        cp = ord(ch)
        for start, end, subset in _SUBSET_RANGES:
            if start <= cp <= end:
                found.add(subset)
                break
        if len(found) == _ALL_SUBSETS:
            break
    return sorted(found)


@dataclass
class _PlaybackState:
    time_pos: float = 0.0
    duration: float = 0.0
    speed: float = 1.0
    is_paused: bool = False
    max_percent: float = 0.0
    completed: bool = False
    last_time_pos_wall: float = field(default_factory=time.time)
    last_rpc_update: float = 0.0


def find_free_port(start: int = 8080, count: int = 20) -> int:
    for port in range(start, start + count):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(("127.0.0.1", port))
            return port
        except OSError:
            continue
    raise OSError(f"No free port found in range {start}–{start + count - 1}")


def _on_time_pos(val: float, state: _PlaybackState, push_rpc) -> bool:
    now_wall = time.time()
    expected = state.time_pos + (now_wall - state.last_time_pos_wall) * state.speed
    seeked = abs(val - expected) > 3.0
    state.time_pos = val
    state.last_time_pos_wall = now_wall
    return seeked


async def _monitor(
    process: subprocess.Popen[bytes],
    driver,  # async generator/coroutine: _mpv_driver or _vlc_driver
    title: str = "",
    episode: str = "",
    cover_url: str = "",
    discord_rpc_enabled: bool = True,
) -> bool:
    rpc = None
    if discord_rpc_enabled:
        try:
            from .discord_rpc import DiscordRPC

            rpc = DiscordRPC()
        except ImportError:
            pass

    start_time = time.time()
    if rpc and title:
        await rpc.update(title=title, episode=episode, cover_url=cover_url)

    state = _PlaybackState()
    RPC_DRIFT_INTERVAL = 30.0

    async def push_rpc():
        if not rpc or not title:
            return
        now = time.time()
        if state.is_paused:
            await rpc.update(
                title=title,
                episode=episode,
                start_time=start_time,
                cover_url=cover_url,
                paused=True,
            )
        else:
            end_ts = (
                (now + (state.duration - state.time_pos) / state.speed)
                if state.duration > 0
                else None
            )
            await rpc.update(
                title=title,
                episode=episode,
                start_time=now - state.time_pos / state.speed,
                end_time=end_ts,
                cover_url=cover_url,
            )
        state.last_rpc_update = now

    await driver(process, state, push_rpc, RPC_DRIFT_INTERVAL)

    if rpc:
        await rpc.clear()
        await rpc.disconnect()

    return state.completed


async def _mpv_driver(
    process: subprocess.Popen[bytes],
    state: _PlaybackState,
    push_rpc,
    rpc_drift_interval: float,
    ipc_path: str,
):
    import json as _json
    import sys as _sys

    await asyncio.sleep(1)

    try:
        if _sys.platform == "win32":
            reader, writer = await asyncio.open_connection(ipc_path)
        else:
            reader, writer = await asyncio.open_unix_connection(ipc_path)

        for obs_id, prop in [
            (1, "percent-pos"),
            (2, "time-pos"),
            (3, "duration"),
            (4, "pause"),
            (5, "speed"),
        ]:
            writer.write(
                (
                    _json.dumps({"command": ["observe_property", obs_id, prop]}) + "\n"
                ).encode()
            )
        await writer.drain()

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
                        if val > state.max_percent:
                            state.max_percent = val
                            if state.max_percent >= 85:
                                state.completed = True

                    elif name == "time-pos" and isinstance(val, (int, float)):
                        seeked = _on_time_pos(val, state, push_rpc)
                        if seeked and not state.is_paused:
                            await push_rpc()

                    elif name == "duration" and isinstance(val, (int, float)):
                        state.duration = val
                        await push_rpc()

                    elif name == "pause" and isinstance(val, bool):
                        state.is_paused = val
                        state.last_time_pos_wall = time.time()
                        await push_rpc()

                    elif name == "speed" and isinstance(val, (int, float)) and val > 0:
                        state.speed = val
                        await push_rpc()

                    if (
                        not state.is_paused
                        and (time.time() - state.last_rpc_update) >= rpc_drift_interval
                    ):
                        await push_rpc()

            except asyncio.TimeoutError:
                continue
            except Exception:
                break

        writer.close()
    except (ConnectionRefusedError, FileNotFoundError, OSError):
        while process.poll() is None:
            await asyncio.sleep(1)

    process.wait()


# ---------------------------------------------------------------------------
# VLC driver
# ---------------------------------------------------------------------------


async def _vlc_driver(
    process: subprocess.Popen[bytes],
    state: _PlaybackState,
    push_rpc,
    rpc_drift_interval: float,
    port: int,
    password: str = "",
):
    await asyncio.sleep(1.5)  # give VLC a moment to start

    status_url = f"http://localhost:{port}/requests/status.json"
    auth = aiohttp.BasicAuth("", password)

    try:
        async with aiohttp.ClientSession() as session:
            while process.poll() is None:
                try:
                    async with session.get(
                        status_url, auth=auth, timeout=aiohttp.ClientTimeout(total=1.5)
                    ) as resp:
                        if resp.status == 200:
                            data = await resp.json(content_type=None)

                            raw_time = data.get("time", 0)
                            raw_length = data.get("length", 0)
                            raw_rate = data.get("rate", 1.0)
                            raw_state = data.get("state", "")

                            # --- duration ---
                            if raw_length and raw_length != state.duration:
                                state.duration = float(raw_length)
                                await push_rpc()

                            # --- speed ---
                            new_speed = float(raw_rate) if raw_rate else 1.0
                            if abs(new_speed - state.speed) > 0.01:
                                state.speed = new_speed
                                await push_rpc()

                            # --- pause state ---
                            new_paused = raw_state == "paused"
                            if new_paused != state.is_paused:
                                state.is_paused = new_paused
                                state.last_time_pos_wall = time.time()
                                await push_rpc()

                            # --- time position / seek ---
                            new_time = float(raw_time)
                            seeked = _on_time_pos(new_time, state, push_rpc)
                            if seeked and not state.is_paused:
                                await push_rpc()

                            # --- percent / completion ---
                            if state.duration > 0:
                                pct = (new_time / state.duration) * 100.0
                                if pct > state.max_percent:
                                    state.max_percent = pct
                                    if state.max_percent >= 85:
                                        state.completed = True

                            # --- drift correction ---
                            if (
                                not state.is_paused
                                and (time.time() - state.last_rpc_update)
                                >= rpc_drift_interval
                            ):
                                await push_rpc()

                except (aiohttp.ClientError, asyncio.TimeoutError):
                    pass

                await asyncio.sleep(1.0)

    except Exception:
        pass

    process.wait()


# ---------------------------------------------------------------------------
# MPC-HC driver (polls /variables.html on the built-in web interface)
# ---------------------------------------------------------------------------


async def _mpc_driver(
    process: subprocess.Popen[bytes],
    state: _PlaybackState,
    push_rpc,
    rpc_drift_interval: float,
    port: int,
):
    await asyncio.sleep(2)  # MPC-HC needs a moment to start its web server

    status_url = f"http://localhost:{port}/variables.html"

    try:
        async with aiohttp.ClientSession() as session:
            while process.poll() is None:
                try:
                    async with session.get(
                        status_url, timeout=aiohttp.ClientTimeout(total=1.5)
                    ) as resp:
                        if resp.status == 200:
                            text = await resp.text()
                            vrs = dict(_MPC_VAR_RE.findall(text))

                            # positions are REFERENCE_TIME (100-ns units)
                            raw_position = int(vrs.get("position", 0))
                            raw_duration = int(vrs.get("filedur", 0))
                            raw_state = int(vrs.get("state", -1))
                            raw_rate = float(vrs.get("playbackrate", 1) or 1)

                            new_time = raw_position / 10_000_000.0
                            new_duration = raw_duration / 10_000_000.0

                            # --- duration ---
                            if new_duration > 0 and new_duration != state.duration:
                                state.duration = new_duration
                                await push_rpc()

                            # --- speed ---
                            new_speed = raw_rate if raw_rate > 0 else 1.0
                            if abs(new_speed - state.speed) > 0.01:
                                state.speed = new_speed
                                await push_rpc()

                            # --- pause state (0=stopped, 1=paused, 2=playing) ---
                            new_paused = raw_state != 2
                            if new_paused != state.is_paused:
                                state.is_paused = new_paused
                                state.last_time_pos_wall = time.time()
                                await push_rpc()

                            # --- time position / seek ---
                            seeked = _on_time_pos(new_time, state, push_rpc)
                            if seeked and not state.is_paused:
                                await push_rpc()

                            # --- percent / completion ---
                            if state.duration > 0:
                                pct = (new_time / state.duration) * 100.0
                                if pct > state.max_percent:
                                    state.max_percent = pct
                                    if state.max_percent >= 85:
                                        state.completed = True

                            # --- drift correction ---
                            if (
                                not state.is_paused
                                and (time.time() - state.last_rpc_update)
                                >= rpc_drift_interval
                            ):
                                await push_rpc()

                except (aiohttp.ClientError, asyncio.TimeoutError, ValueError):
                    pass

                await asyncio.sleep(1.0)

    except Exception:
        pass

    process.wait()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


async def monitor_mpv_status(
    process: subprocess.Popen[bytes],
    ipc_path: str,
    title: str = "",
    episode: str = "",
    cover_url: str = "",
    discord_rpc_enabled: bool = True,
) -> bool:
    async def driver(proc, state, push_rpc, drift):
        await _mpv_driver(proc, state, push_rpc, drift, ipc_path)

    return await _monitor(
        process, driver, title, episode, cover_url, discord_rpc_enabled
    )


async def monitor_vlc_status(
    process: subprocess.Popen[bytes],
    port: int,
    password: str = "",
    title: str = "",
    episode: str = "",
    cover_url: str = "",
    discord_rpc_enabled: bool = True,
) -> bool:
    async def driver(proc, state, push_rpc, drift):
        await _vlc_driver(proc, state, push_rpc, drift, port, password)

    return await _monitor(
        process, driver, title, episode, cover_url, discord_rpc_enabled
    )


async def monitor_mpc_status(
    process: subprocess.Popen[bytes],
    port: int,
    title: str = "",
    episode: str = "",
    cover_url: str = "",
    discord_rpc_enabled: bool = True,
) -> bool:
    async def driver(proc, state, push_rpc, drift):
        await _mpc_driver(proc, state, push_rpc, drift, port)

    return await _monitor(
        process, driver, title, episode, cover_url, discord_rpc_enabled
    )


async def get_subtitle_fonts(url: str) -> dict:
    """Fetch ASS subtitle and return font names + detected language scripts."""
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            if response.status != 200:
                return {"fonts": [], "scripts": []}

            subtitle_bytes = await response.read()
            subtitle_content = subtitle_bytes.decode("utf-8-sig", errors="replace")

            try:
                subtitle = ass.parse_string(subtitle_content)
                fonts = sorted({style.fontname for style in subtitle.styles})

                text_parts: list[str] = []
                for event in subtitle.events:
                    raw = getattr(event, "text", "") or ""
                    text_parts.append(_ASS_TAG_RE.sub("", raw))
                scripts = _detect_scripts("\n".join(text_parts))

                return {"fonts": fonts, "scripts": scripts}
            except Exception as e:
                print(f"Error parsing subtitle file: {e}")
                return {"fonts": [], "scripts": []}


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
            self.completed.emit()
            return

        if isinstance(result, bool):
            self.result_bool.emit(result)
        elif isinstance(result, str):
            self.result_str.emit(result)
        elif isinstance(result, list):
            self.result_list.emit(result)
        elif isinstance(result, dict):
            self.result_dict.emit(result)

        self.completed.emit()
