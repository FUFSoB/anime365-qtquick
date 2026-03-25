import asyncio
import json
import os
import struct
import sys
import time
import uuid

DISCORD_APP_ID = "1019972663294308400"

IS_ANDROID = hasattr(sys, "getandroidapilevel")

OP_HANDSHAKE = 0
OP_FRAME = 1


def _find_ipc_socket() -> str | None:
    if sys.platform == "win32":
        return None  # Windows uses named pipes handled separately

    xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    search_dirs = [
        xdg,
        os.path.join(xdg, "app", "dev.vencord.Vesktop"),  # Vesktop Flatpak
        os.path.join(xdg, "app", "com.discordapp.Discord"),  # Discord Flatpak
        os.path.join(xdg, "app", "com.discordapp.DiscordPTB"),
        os.path.join(xdg, "app", "com.discordapp.DiscordCanary"),
        "/tmp",
    ]
    for env in ("TMPDIR", "TMP", "TEMP"):
        val = os.environ.get(env)
        if val:
            search_dirs.append(val)

    for d in search_dirs:
        for i in range(10):
            path = os.path.join(d, f"discord-ipc-{i}")
            if os.path.exists(path):
                return path
    return None


def _encode(opcode: int, payload: dict) -> bytes:
    data = json.dumps(payload).encode()
    return struct.pack("<II", opcode, len(data)) + data


async def _read_frame(reader: asyncio.StreamReader) -> tuple[int, dict]:
    header = await reader.readexactly(8)
    op, length = struct.unpack("<II", header)
    body = await reader.readexactly(length)
    return op, json.loads(body)


class DiscordRPC:
    def __init__(self):
        self._reader: asyncio.StreamReader | None = None
        self._writer: asyncio.StreamWriter | None = None
        self._connected = False
        self._drain_task: asyncio.Task | None = None

    async def connect(self) -> bool:
        if self._connected:
            return True
        if IS_ANDROID:
            return False

        if sys.platform == "win32":
            pipe_path = r"\\.\pipe\discord-ipc-0"
            try:
                self._reader, self._writer = await asyncio.open_connection(pipe_path)
            except Exception:
                return False
        else:
            sock_path = _find_ipc_socket()
            if not sock_path:
                return False
            try:
                self._reader, self._writer = await asyncio.open_unix_connection(
                    sock_path
                )
            except Exception:
                return False

        # Handshake — must wait for READY before sending anything else
        try:
            self._writer.write(
                _encode(OP_HANDSHAKE, {"v": 1, "client_id": DISCORD_APP_ID})
            )
            await self._writer.drain()
            _, resp = await asyncio.wait_for(_read_frame(self._reader), timeout=5)
            if resp.get("evt") != "READY":
                await self._close_transport()
                return False
        except Exception:
            await self._close_transport()
            return False

        self._connected = True
        # Drain incoming frames in the background so they never block sends
        self._drain_task = asyncio.create_task(self._drain_reader())
        return True

    async def _drain_reader(self):
        while self._connected and self._reader:
            try:
                await asyncio.wait_for(_read_frame(self._reader), timeout=60)
            except asyncio.TimeoutError:
                continue
            except Exception:
                self._connected = False
                break

    async def _send(self, payload: dict) -> bool:
        if not self._connected and not await self.connect():
            return False
        try:
            self._writer.write(_encode(OP_FRAME, payload))
            await self._writer.drain()  # just flush; response handled by _drain_reader
            return True
        except Exception:
            self._connected = False
            await self._close_transport()
            return False

    async def update(
        self,
        title: str,
        episode: str,
        start_time: float | None = None,
        end_time: float | None = None,
        cover_url: str = "",
        paused: bool = False,
    ):
        assets = {
            "large_image": cover_url if cover_url else "anime365",
            "large_text": title,
            "small_image": "anime365",
            "small_text": "Anime365",
        }
        state = f"Episode: {episode}" + (" (Paused)" if paused else "")
        # When paused: show session start time, no end (no progress bar, no drift)
        # When playing: show accurate position via start/end (renders progress bar)
        timestamps: dict = {"start": int(start_time or time.time())}
        if end_time is not None and not paused:
            timestamps["end"] = int(end_time)
        await self._send(
            {
                "cmd": "SET_ACTIVITY",
                "args": {
                    "pid": os.getpid(),
                    "activity": {
                        "type": 3,  # 0=Playing, 1=Streaming, 2=Listening, 3=Watching
                        "details": title,
                        "state": state,
                        "timestamps": timestamps,
                        "assets": assets,
                    },
                },
                "nonce": str(uuid.uuid4()),
            }
        )

    async def set_paused(self, title: str, episode: str, cover_url: str = ""):
        assets = {
            "large_image": cover_url if cover_url else "anime365",
            "large_text": title,
            "small_image": "anime365",
            "small_text": "Anime365",
        }
        await self._send(
            {
                "cmd": "SET_ACTIVITY",
                "args": {
                    "pid": os.getpid(),
                    "activity": {
                        "type": 3,
                        "details": title,
                        "state": f"Episode: {episode} (Paused)",
                        "assets": assets,
                    },
                },
                "nonce": str(uuid.uuid4()),
            }
        )

    async def clear(self):
        await self._send(
            {
                "cmd": "SET_ACTIVITY",
                "args": {"pid": os.getpid(), "activity": None},
                "nonce": str(uuid.uuid4()),
            }
        )

    async def disconnect(self):
        self._connected = False
        if self._drain_task:
            self._drain_task.cancel()
            self._drain_task = None
        await self._close_transport()

    async def _close_transport(self):
        if self._writer:
            try:
                self._writer.close()
                await self._writer.wait_closed()
            except Exception:
                pass
            self._writer = None
            self._reader = None
