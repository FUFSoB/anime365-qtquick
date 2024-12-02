import traceback

import asyncio
import aiohttp
from PySide6.QtCore import QThread, Signal

import ass


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
