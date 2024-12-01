import asyncio
import aiohttp
from aiohttp_socks import ProxyConnector

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend


class Api:
    def __init__(self, settings: "SettingsBackend"):
        self.settings = settings
        self.anime365_url = self.settings.anime365_site
        self.hentai365_url = self.settings.hentai365_site
        self.shikimori_url = self.settings.shikimori_site

    async def _get_connector(self):
        if self.settings.proxy:
            return ProxyConnector.from_url(self.settings.proxy)
        return None

    # Anime365 API

    async def check_token(self, token: str) -> bool:
        url = f"{self.anime365_url}/api/me"
        params = {"access_token": token}
        async with aiohttp.ClientSession(
            connector=await self._get_connector()
        ) as session:
            async with session.get(url, params=params) as response:
                data = await response.json()
                return response.status == 200 and data["data"]["isPremium"]

    async def find_anime(self, query: str) -> list[dict]:
        params = [(f"{self.anime365_url}/api/series", query, False)]
        if self.settings.hentai365_site:
            params.append((f"{self.hentai365_url}/api/series", query, True))
        tasks = []
        async with asyncio.TaskGroup() as tg:
            for param in params:
                tasks.append(tg.create_task(self._find_anime(*param)))
        result = []
        for task in tasks:
            result.extend(await task)
        return result

    async def _find_anime(self, url: str, query: str, is_hentai: bool) -> list[dict]:
        async with aiohttp.ClientSession(
            connector=await self._get_connector(),
            timeout=aiohttp.ClientTimeout(total=2),
        ) as session:
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
        async with aiohttp.ClientSession(
            connector=await self._get_connector()
        ) as session:
            async with session.get(
                f"{self.anime365_url}/api/series/{anime_id}",
                params={"fields": "episodes"},
            ) as response:
                return (await response.json())["data"]["episodes"]

    async def get_translations(self, episode_id: int) -> list[dict]:
        async with aiohttp.ClientSession(
            connector=await self._get_connector()
        ) as session:
            async with session.get(
                f"{self.anime365_url}/api/episodes/{episode_id}"
            ) as response:
                return (await response.json())["data"]["translations"]

    async def get_streams(self, translation_id: int) -> list[dict]:
        async with aiohttp.ClientSession(
            connector=await self._get_connector()
        ) as session:
            async with session.get(
                f"{self.anime365_url}/api/translations/embed/{translation_id}",
                params={"access_token": self.settings.anime365_token},
            ) as response:
                return (await response.json())["data"]

    # Shikimori API

    async def shiki_refresh_token(self, code: str) -> str:
        pass

    async def shiki_auth(self, token: str) -> bool:
        url = f"{self.shikimori_url}/api/users/whoami"
        headers = {"Authorization": f"Bearer {token}"}
        async with aiohttp.ClientSession(
            connector=await self._get_connector()
        ) as session:
            async with session.get(url, headers=headers) as response:
                return response.status == 200

    async def shiki_check_token(self, token: str) -> bool:
        pass
