import asyncio
import aiohttp
from aiohttp_socks import ProxyConnector

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend

BASE_URL = "https://anime365.ru"
H_BASE_URL = "https://hentai365.ru"


class Api:
    def __init__(self, settings: "SettingsBackend"):
        self.settings = settings
        self.connector = self._get_connector()

    def _get_connector(self):
        # if self.settings.proxy_enabled:
        #     return ProxyConnector.from_url(self.settings.proxy_url)
        return None

    async def check_token(self, token: str) -> bool:
        url = f"{BASE_URL}/api/me"
        params = {"access_token": token}
        async with aiohttp.ClientSession(connector=self.connector) as session:
            async with session.get(url, params=params) as response:
                data = await response.json()
                return response.status == 200 and data["data"]["isPremium"]

    async def find_anime(self, query: str) -> list[dict]:
        params = (
            (f"{BASE_URL}/api/series", query, False),
            # (f"{H_BASE_URL}/api/series", query, True),
        )
        tasks = []
        async with asyncio.TaskGroup() as tg:
            for param in params:
                tasks.append(tg.create_task(self._find_anime(*param)))
        result = []
        for task in tasks:
            result.extend(await task)
        return result

    async def _find_anime(self, url: str, query: str, is_hentai: bool) -> list[dict]:
        async with aiohttp.ClientSession(connector=self.connector) as session:
            async with session.get(
                url,
                params={
                    "query": query,
                    "limit": 100,
                    "offset": 0,
                    "isHentai": int(is_hentai),
                },
            ) as response:
                return (await response.json())["data"]

    async def get_episodes(self, anime_id: int) -> list[dict]:
        async with aiohttp.ClientSession(connector=self.connector) as session:
            async with session.get(
                f"{BASE_URL}/api/series/{anime_id}", params={"fields": "episodes"}
            ) as response:
                return (await response.json())["data"]["episodes"]

    async def get_translations(self, episode_id: int) -> list[dict]:
        async with aiohttp.ClientSession(connector=self.connector) as session:
            async with session.get(f"{BASE_URL}/api/episodes/{episode_id}") as response:
                return (await response.json())["data"]["translations"]

    async def get_streams(self, translation_id: int) -> list[dict]:
        async with aiohttp.ClientSession(connector=self.connector) as session:
            async with session.get(
                f"{BASE_URL}/api/translations/embed/{translation_id}",
                params={"access_token": self.settings.anime365_token},
            ) as response:
                return (await response.json())["data"]
