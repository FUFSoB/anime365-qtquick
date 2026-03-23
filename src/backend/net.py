import asyncio
import ssl
import certifi
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

    def _ssl_context(self):
        ctx = ssl.create_default_context(cafile=certifi.where())
        return ctx

    async def get_connector(self):
        if self.settings.proxy:
            return ProxyConnector.from_url(self.settings.proxy, ssl=self._ssl_context())
        return aiohttp.TCPConnector(ssl=self._ssl_context())

    async def check_proxy(self, proxy_url: str) -> bool:
        try:
            connector = ProxyConnector.from_url(proxy_url, ssl=self._ssl_context())
            timeout = aiohttp.ClientTimeout(total=10)
            async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
                async with session.get(
                    f"{self.anime365_url}/api/series", params={"limit": 1}
                ) as response:
                    return response.status == 200
        except Exception:
            return False

    # Anime365 API

    async def check_token(self, token: str) -> bool:
        url = f"{self.anime365_url}/api/me"
        params = {"access_token": token}
        async with aiohttp.ClientSession(
            connector=await self.get_connector()
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
            connector=await self.get_connector()
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
            connector=await self.get_connector()
        ) as session:
            async with session.get(
                f"{self.anime365_url}/api/series/{anime_id}",
                params={"fields": "episodes"},
            ) as response:
                return (await response.json())["data"]["episodes"]

    async def get_translations(self, episode_id: int) -> list[dict]:
        async with aiohttp.ClientSession(
            connector=await self.get_connector()
        ) as session:
            async with session.get(
                f"{self.anime365_url}/api/episodes/{episode_id}"
            ) as response:
                return (await response.json())["data"]["translations"]

    async def get_streams(self, translation_id: int) -> list[dict]:
        async with aiohttp.ClientSession(
            connector=await self.get_connector()
        ) as session:
            async with session.get(
                f"{self.anime365_url}/api/translations/embed/{translation_id}",
                params={"access_token": self.settings.anime365_token},
            ) as response:
                return (await response.json())["data"]

    # Shikimori API

    def _shiki_headers(self, token: str) -> dict:
        return {
            "Authorization": f"Bearer {token}",
            "User-Agent": "Anime365-QtQuick",
        }

    async def shiki_exchange_code(
        self, code: str, client_id: str, client_secret: str
    ) -> dict:
        url = f"{self.shikimori_url}/oauth/token"
        data = {
            "grant_type": "authorization_code",
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
        }
        async with aiohttp.ClientSession(
            connector=await self.get_connector()
        ) as session:
            async with session.post(url, json=data) as response:
                if response.status != 200:
                    raise Exception(f"Auth failed: {await response.text()}")
                return await response.json()

    async def shiki_refresh_token(
        self, refresh_token: str, client_id: str, client_secret: str
    ) -> dict:
        url = f"{self.shikimori_url}/oauth/token"
        data = {
            "grant_type": "refresh_token",
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
        }
        async with aiohttp.ClientSession(
            connector=await self.get_connector()
        ) as session:
            async with session.post(url, json=data) as response:
                if response.status != 200:
                    raise Exception(f"Token refresh failed: {await response.text()}")
                return await response.json()

    async def shiki_get_user(self, token: str) -> dict:
        url = f"{self.shikimori_url}/api/users/whoami"
        async with aiohttp.ClientSession(
            connector=await self.get_connector()
        ) as session:
            async with session.get(
                url, headers=self._shiki_headers(token)
            ) as response:
                if response.status != 200:
                    raise Exception("Failed to get user info")
                return await response.json()

    async def shiki_get_user_rates(
        self, user_id: int, token: str, target_type: str = "Anime"
    ) -> list:
        url = f"{self.shikimori_url}/api/v2/user_rates"
        params = {
            "user_id": user_id,
            "target_type": target_type,
        }
        async with aiohttp.ClientSession(
            connector=await self.get_connector()
        ) as session:
            async with session.get(
                url, params=params, headers=self._shiki_headers(token)
            ) as response:
                if response.status != 200:
                    return []
                return await response.json()

    async def shiki_create_or_update_rate(
        self,
        token: str,
        user_id: int,
        target_id: int,
        target_type: str,
        status: str,
        episodes: int,
        score: int,
        rewatches: int,
    ) -> dict:
        url = f"{self.shikimori_url}/api/v2/user_rates"
        data = {
            "user_rate": {
                "user_id": user_id,
                "target_id": target_id,
                "target_type": target_type,
                "status": status,
                "episodes": episodes,
                "score": score,
                "rewatches": rewatches,
            }
        }
        async with aiohttp.ClientSession(
            connector=await self.get_connector()
        ) as session:
            async with session.post(
                url, json=data, headers=self._shiki_headers(token)
            ) as response:
                if response.status in (200, 201):
                    return await response.json()
                raise Exception(f"Failed to update rate: {await response.text()}")

    async def shiki_search_anime(self, token: str, search: str) -> list:
        url = f"{self.shikimori_url}/api/animes"
        params = {"search": search, "limit": 5}
        async with aiohttp.ClientSession(
            connector=await self.get_connector()
        ) as session:
            async with session.get(
                url, params=params, headers=self._shiki_headers(token)
            ) as response:
                if response.status != 200:
                    return []
                return await response.json()
