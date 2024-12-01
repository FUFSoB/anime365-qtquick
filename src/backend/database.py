from datetime import datetime
import json
from PySide6.QtCore import QObject, Slot, Signal

from constants import DATABASE_FILE


class Database:
    def __init__(self):
        self.db = None

    def load(self):
        if not DATABASE_FILE.exists():
            DATABASE_FILE.touch()
            DATABASE_FILE.write_text("{}")
        self.db = json.load(DATABASE_FILE.open())

    def save(self):
        data = json.dumps(self.db, indent=4, ensure_ascii=False)
        DATABASE_FILE.write_text(data)

    def get(self, key: str) -> dict:
        return self.db[key]

    def get_list(self) -> list[dict]:
        return sorted(self.db.values(), key=lambda x: x["last_viewed"], reverse=True)

    def put(self, key: str, value: dict) -> bool:
        existing = self.db.get(key)
        if existing:
            value |= {
                "episode": existing["episode"],
                "translation": existing["translation"],
                "alt_video": existing["alt_video"],
                "quality": existing["quality"],
            }
        self.db[key] = value
        return existing is None

    def update(self, key: str, value: dict):
        self.db[key] |= value

    def delete(self, key: str):
        del self.db[key]


class Backend(QObject):
    list_updated = Signal()

    def __init__(self):
        super().__init__()
        self.db = Database()
        self.db.load()

    @Slot(str, result=dict)
    def get(self, key: str) -> dict:
        return self.db.get(key)

    @Slot(result=list)
    def get_list(self) -> list[dict]:
        return self.db.get_list()

    @Slot(str, dict, result=bool)
    def put(self, key: str, value: dict) -> bool:
        keys = (
            "id",
            "title",
            "titles",
            "total_episodes",
            "image_url",
            "type",
            "score",
            "year",
            "hentai",
            "h_type",
            "description",
            "genres",
        )
        data = {
            **{k: value.get(k) for k in keys},
            "episode": "",
            "translation": "",
            "alt_video": "",
            "quality": "",
            "last_viewed": int(datetime.now().timestamp()),
        }
        result = self.db.put(key, data)
        if result:
            self.db.save()
            self.list_updated.emit()
        return result

    @Slot(str, dict)
    def update(self, key: str, value: dict):
        data = {
            "episode": value.get("episode"),
            "translation": value.get("translation"),
            "alt_video": value.get("alt_video"),
            "quality": value.get("quality"),
            "last_viewed": int(datetime.now().timestamp()),
        }
        self.db.update(key, data)
        self.list_updated.emit()
        self.db.save()

    @Slot(str)
    def delete(self, key: str):
        self.db.delete(key)
        self.list_updated.emit()
        self.db.save()
