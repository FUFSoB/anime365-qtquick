import asyncio
import aiohttp
from aiohttp_socks import ProxyConnector

BASE = "https://anime365.ru/api"


class Api:
    def __init__(self, settings):
        self.settings = settings

    async def check_token(self, token):
        url = f"{BASE}/me"
        params = {"access_token": token}
        async with aiohttp.ClientSession() as session:
            async with session.get(url, params=params) as response:
                data = await response.json()
                return response.status == 200 and data["data"]["isPremium"]
