import asyncio
from PySide6.QtCore import QThread, Signal


class AsyncFunctionWorker(QThread):
    result_bool = Signal(bool)
    result_list = Signal(list)

    def __init__(self, func, *args, **kwargs):
        super().__init__()
        self.func = func
        self.args = args
        self.kwargs = kwargs

    def run(self):
        result = asyncio.run(self.func(*self.args, **self.kwargs))
        if isinstance(result, bool):
            self.result_bool.emit(result)
        elif isinstance(result, list):
            self.result_list.emit(result)
