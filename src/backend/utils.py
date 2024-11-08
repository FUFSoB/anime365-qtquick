import asyncio
from PySide6.QtCore import QThread, Signal


class AsyncFunctionWorker(QThread):
    result = Signal(bool)

    def __init__(self, func, *args, **kwargs):
        super().__init__()
        self.func = func
        self.args = args
        self.kwargs = kwargs

    def run(self):
        self.result.emit(asyncio.run(self.func(*self.args, **self.kwargs)))
