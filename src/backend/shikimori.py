from PySide6.QtCore import QObject, Slot, Signal

from .utils import AsyncFunctionWorker

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .settings import Backend as SettingsBackend


class Backend(QObject):
    auth_completed = Signal(bool, str)  # success, message
    rate_updated = Signal(bool)
    user_rates_got = Signal(list)

    def __init__(self, settings: "SettingsBackend"):
        super().__init__()
        self.settings = settings
        self.api = settings.api
        self.workers: list[AsyncFunctionWorker] = []

    def _ensure_token(self) -> str | None:
        token = self.settings.get("shikimori_access_token")
        if not token:
            return None
        return token

    @Slot(str, str, str)
    def authorize(self, auth_code: str, client_id: str, client_secret: str):
        async def _do_auth():
            token_data = await self.api.shiki_exchange_code(
                auth_code, client_id, client_secret
            )
            access_token = token_data["access_token"]
            refresh_token = token_data["refresh_token"]

            user = await self.api.shiki_get_user(access_token)

            settings = self.settings.get_settings()
            settings["shikimori_access_token"] = access_token
            settings["shikimori_refresh_token"] = refresh_token
            settings["shikimori_user_id"] = user["id"]
            settings["shikimori_client_id"] = client_id
            settings["shikimori_client_secret"] = client_secret
            self.settings.save_settings(settings)

            return f"Logged in as {user['nickname']}"

        worker = AsyncFunctionWorker(_do_auth)
        self.workers.append(worker)
        worker.result_str.connect(lambda msg: self.auth_completed.emit(True, msg))
        worker.error.connect(lambda err: self.auth_completed.emit(False, str(err)))
        worker.completed.connect(lambda *_: self.workers.remove(worker))
        worker.start()

    @Slot(int, str, int, int, int)
    def update_rate(
        self,
        anime365_id: int,
        status: str,
        episodes: int,
        score: int,
        rewatches: int,
    ):
        token = self._ensure_token()
        if not token or not status:
            self.rate_updated.emit(False)
            return

        user_id = int(self.settings.get("shikimori_user_id") or 0)
        if not user_id:
            self.rate_updated.emit(False)
            return

        async def _do_update():
            # Try to refresh token if needed
            try:
                result = await self.api.shiki_create_or_update_rate(
                    token=token,
                    user_id=user_id,
                    target_id=anime365_id,
                    target_type="Anime",
                    status=status,
                    episodes=episodes,
                    score=score,
                    rewatches=rewatches,
                )
                return True
            except Exception:
                # Try refreshing the token
                refresh = self.settings.get("shikimori_refresh_token")
                client_id = self.settings.get("shikimori_client_id")
                client_secret = self.settings.get("shikimori_client_secret")
                if refresh and client_id and client_secret:
                    try:
                        token_data = await self.api.shiki_refresh_token(
                            refresh, client_id, client_secret
                        )
                        new_token = token_data["access_token"]
                        settings = self.settings.get_settings()
                        settings["shikimori_access_token"] = new_token
                        settings["shikimori_refresh_token"] = token_data[
                            "refresh_token"
                        ]
                        self.settings.save_settings(settings)

                        await self.api.shiki_create_or_update_rate(
                            token=new_token,
                            user_id=user_id,
                            target_id=anime365_id,
                            target_type="Anime",
                            status=status,
                            episodes=episodes,
                            score=score,
                            rewatches=rewatches,
                        )
                        return True
                    except Exception:
                        pass
                return False

        worker = AsyncFunctionWorker(_do_update)
        self.workers.append(worker)
        worker.result_bool.connect(self.rate_updated.emit)
        worker.error.connect(lambda _: self.rate_updated.emit(False))
        worker.completed.connect(lambda *_: self.workers.remove(worker))
        worker.start()

    @Slot()
    def get_user_rates(self):
        token = self._ensure_token()
        if not token:
            self.user_rates_got.emit([])
            return

        user_id = int(self.settings.get("shikimori_user_id") or 0)
        if not user_id:
            self.user_rates_got.emit([])
            return

        async def _do_get():
            return await self.api.shiki_get_user_rates(user_id, token)

        worker = AsyncFunctionWorker(_do_get)
        self.workers.append(worker)
        worker.result_list.connect(self.user_rates_got.emit)
        worker.error.connect(lambda _: self.user_rates_got.emit([]))
        worker.completed.connect(lambda *_: self.workers.remove(worker))
        worker.start()
