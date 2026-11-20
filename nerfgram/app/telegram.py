"""Minimal Telegram Bot API client. No aiogram: one httpx client, long polling."""
from __future__ import annotations

import asyncio
import logging
from typing import Any

import httpx

from .config import config

log = logging.getLogger("nerfgram.telegram")
API = "https://api.telegram.org/bot" + config.bot_token


class Telegram:
    def __init__(self) -> None:
        self.client = httpx.AsyncClient(timeout=httpx.Timeout(12.0), limits=httpx.Limits(max_connections=8))

    async def close(self) -> None:
        await self.client.aclose()

    async def call(self, method: str, **params: Any) -> Any:
        try:
            response = await self.client.post(f"{API}/{method}", json=params)
        except httpx.HTTPError as exc:
            log.warning("Telegram %s failed: %s", method, exc)
            return None
        if response.status_code != 200:
            log.warning("Telegram %s HTTP %s: %s", method, response.status_code, response.text[:300])
            return None
        data = response.json()
        if not data.get("ok"):
            log.warning("Telegram %s error: %s", method, data.get("description"))
            return None
        return data.get("result")

    async def get_updates(self, offset: int, timeout: int = 10) -> list[dict]:
        result = await self.call(
            "getUpdates",
            offset=offset,
            timeout=timeout,
            allowed_updates=["message", "callback_query", "pre_checkout_query", "subscription"],
        )
        return result or []

    async def send_message(self, chat_id: int, text: str, reply_markup: dict | None = None) -> None:
        await self.call("sendMessage", chat_id=chat_id, text=text, reply_markup=reply_markup, disable_web_page_preview=False)

    async def answer_callback(self, callback_id: str, text: str = "", alert: bool = False) -> None:
        await self.call("answerCallbackQuery", callback_query_id=callback_id, text=text, show_alert=alert)

    async def answer_pre_checkout(self, query_id: str, ok: bool, error: str = "") -> None:
        await self.call("answerPreCheckoutQuery", pre_checkout_query_id=query_id, ok=ok, error=error or "Не удалось проверить платёж")

    async def create_invoice_link(self, plan_label: str, stars: int, payload: str) -> str | None:
        return await self.call(
            "createInvoiceLink",
            title=f"Nerf Gram · {plan_label}",
            description="Подписка Nerf Gram для LARP-возможностей Nerf Client",
            payload=payload,
            currency="XTR",
            prices=[{"label": plan_label, "amount": stars}],
        )

    async def setup(self) -> None:
        """Webhook cannot be used on a Pterodactyl port: make sure polling is active."""
        await self.call("deleteWebhook", drop_pending_updates=False)
        me = await self.call("getMe")
        if me:
            log.info("Bot: @%s", me.get("username"))


def inline_keyboard(rows: list[list[dict]]) -> dict:
    return {"inline_keyboard": rows}
