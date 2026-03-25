import json
import sqlite3
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot

from constants import DATABASE_FILE, LEGACY_DATABASE_FILE

_JSON_FIELDS = ("titles", "genres")

_CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS anime (
    id              TEXT PRIMARY KEY,
    title           TEXT,
    titles          TEXT,
    total_episodes  INTEGER,
    image_url       TEXT,
    type            TEXT,
    score           REAL,
    year            INTEGER,
    hentai          INTEGER,
    h_type          TEXT,
    description     TEXT,
    genres          TEXT,
    mal_id          INTEGER DEFAULT 0,
    world_art_id    INTEGER DEFAULT 0,
    anidb_id        INTEGER DEFAULT 0,
    ann_id          INTEGER DEFAULT 0,
    anime365_url    TEXT    DEFAULT '',
    episode         TEXT    DEFAULT '',
    translation     TEXT    DEFAULT '',
    alt_video       TEXT    DEFAULT '',
    quality         TEXT    DEFAULT '',
    last_viewed     INTEGER DEFAULT 0
)
"""


def _encode(value: dict) -> dict:
    row = dict(value)
    for field in _JSON_FIELDS:
        if field in row and not isinstance(row[field], str):
            row[field] = json.dumps(row[field], ensure_ascii=False)
    return row


def _decode(row) -> dict:
    d = dict(row)
    for field in _JSON_FIELDS:
        raw = d.get(field)
        if raw and isinstance(raw, str):
            try:
                d[field] = json.loads(raw)
            except (json.JSONDecodeError, TypeError):
                pass
    return d


class Database:
    def __init__(self, path: Path = DATABASE_FILE):
        self.path = path
        self.conn: sqlite3.Connection | None = None

    def load(self):
        self.conn = sqlite3.connect(str(self.path))
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA journal_mode=WAL")
        self.conn.execute(_CREATE_TABLE)
        self._add_columns_if_missing()
        self.conn.commit()
        self._migrate_legacy()

    def _add_columns_if_missing(self):
        existing = {
            row[1] for row in self.conn.execute("PRAGMA table_info(anime)").fetchall()
        }
        new_cols = {
            "mal_id": "INTEGER DEFAULT 0",
            "world_art_id": "INTEGER DEFAULT 0",
            "anidb_id": "INTEGER DEFAULT 0",
            "ann_id": "INTEGER DEFAULT 0",
            "anime365_url": "TEXT DEFAULT ''",
        }
        for col, typedef in new_cols.items():
            if col not in existing:
                self.conn.execute(f"ALTER TABLE anime ADD COLUMN {col} {typedef}")

    def _migrate_legacy(self):
        if not LEGACY_DATABASE_FILE.exists():
            return
        try:
            legacy = json.loads(LEGACY_DATABASE_FILE.read_text())
            for item in legacy.values():
                self._insert(item)
            self.conn.commit()
            LEGACY_DATABASE_FILE.rename(
                LEGACY_DATABASE_FILE.with_suffix(".json.migrated")
            )
        except Exception:
            pass

    def _insert(self, value: dict):
        row = _encode(value)
        self.conn.execute(
            """INSERT OR IGNORE INTO anime
               (id, title, titles, total_episodes, image_url, type, score, year,
                hentai, h_type, description, genres,
                mal_id, world_art_id, anidb_id, ann_id, anime365_url,
                episode, translation, alt_video, quality, last_viewed)
               VALUES (:id,:title,:titles,:total_episodes,:image_url,:type,:score,:year,
                       :hentai,:h_type,:description,:genres,
                       :mal_id,:world_art_id,:anidb_id,:ann_id,:anime365_url,
                       :episode,:translation,:alt_video,:quality,:last_viewed)""",
            {
                "id": row.get("id", ""),
                "title": row.get("title"),
                "titles": row.get("titles"),
                "total_episodes": row.get("total_episodes"),
                "image_url": row.get("image_url"),
                "type": row.get("type"),
                "score": row.get("score"),
                "year": row.get("year"),
                "hentai": row.get("hentai"),
                "h_type": row.get("h_type"),
                "description": row.get("description"),
                "genres": row.get("genres"),
                "mal_id": row.get("mal_id", 0),
                "world_art_id": row.get("world_art_id", 0),
                "anidb_id": row.get("anidb_id", 0),
                "ann_id": row.get("ann_id", 0),
                "anime365_url": row.get("anime365_url", ""),
                "episode": row.get("episode", ""),
                "translation": row.get("translation", ""),
                "alt_video": row.get("alt_video", ""),
                "quality": row.get("quality", ""),
                "last_viewed": row.get("last_viewed", 0),
            },
        )

    def get(self, key: str) -> dict:
        row = self.conn.execute("SELECT * FROM anime WHERE id=?", (key,)).fetchone()
        return _decode(row) if row else {}

    def get_list(self) -> list[dict]:
        rows = self.conn.execute(
            "SELECT * FROM anime ORDER BY last_viewed DESC"
        ).fetchall()
        return [_decode(r) for r in rows]

    def get_continue_watching(self) -> list[dict]:
        rows = self.conn.execute(
            "SELECT * FROM anime WHERE episode != '' "
            "ORDER BY last_viewed DESC LIMIT 10"
        ).fetchall()
        return [_decode(r) for r in rows]

    def put(self, key: str, value: dict) -> bool:
        existing = self.get(key)
        row = _encode(value)
        now = int(datetime.now().timestamp())
        if existing:
            self.conn.execute(
                """UPDATE anime SET
                   title=:title, titles=:titles, total_episodes=:total_episodes,
                   image_url=:image_url, type=:type, score=:score, year=:year,
                   hentai=:hentai, h_type=:h_type, description=:description,
                   genres=:genres,
                   mal_id=:mal_id, world_art_id=:world_art_id,
                   anidb_id=:anidb_id, ann_id=:ann_id, anime365_url=:anime365_url,
                   last_viewed=:last_viewed
                   WHERE id=:id""",
                {
                    "id": key,
                    "title": row.get("title"),
                    "titles": row.get("titles"),
                    "total_episodes": row.get("total_episodes"),
                    "image_url": row.get("image_url"),
                    "type": row.get("type"),
                    "score": row.get("score"),
                    "year": row.get("year"),
                    "hentai": row.get("hentai"),
                    "h_type": row.get("h_type"),
                    "description": row.get("description"),
                    "genres": row.get("genres"),
                    "mal_id": row.get("mal_id", 0),
                    "world_art_id": row.get("world_art_id", 0),
                    "anidb_id": row.get("anidb_id", 0),
                    "ann_id": row.get("ann_id", 0),
                    "anime365_url": row.get("anime365_url", ""),
                    "last_viewed": now,
                },
            )
            self.conn.commit()
            return False
        else:
            self._insert({**value, "last_viewed": now})
            self.conn.commit()
            return True

    def update(self, key: str, value: dict):
        self.conn.execute(
            """UPDATE anime SET episode=?, translation=?, alt_video=?, quality=?,
               last_viewed=? WHERE id=?""",
            (
                value.get("episode", ""),
                value.get("translation", ""),
                value.get("alt_video", ""),
                value.get("quality", ""),
                int(datetime.now().timestamp()),
                key,
            ),
        )
        self.conn.commit()

    def delete(self, key: str):
        self.conn.execute("DELETE FROM anime WHERE id=?", (key,))
        self.conn.commit()


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

    @Slot(result=list)
    def get_continue_watching(self) -> list[dict]:
        return self.db.get_continue_watching()

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
            "mal_id",
            "world_art_id",
            "anidb_id",
            "ann_id",
            "anime365_url",
        )
        data = {k: value.get(k) for k in keys}
        result = self.db.put(key, data)
        if result:
            self.list_updated.emit()
        return result

    @Slot(str, dict)
    def update(self, key: str, value: dict):
        self.db.update(
            key,
            {
                "episode": value.get("episode"),
                "translation": value.get("translation"),
                "alt_video": value.get("alt_video"),
                "quality": value.get("quality"),
            },
        )
        self.list_updated.emit()

    @Slot(str)
    def delete(self, key: str):
        self.db.delete(key)
        self.list_updated.emit()
