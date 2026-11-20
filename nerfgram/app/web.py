"""Checkout web app and the activation-key API used by the iOS client."""
from __future__ import annotations

import logging
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from . import db, service
from .auth import make_payload, verify_auth_token
from .config import config
from .plans import PAID_PLANS, get_plan
from .telegram import Telegram

log = logging.getLogger("nerfgram.web")
STATIC = Path(__file__).resolve().parent.parent / "static"
app = FastAPI(title="Nerf Gram", docs_url=None, redoc_url=None)
bot: Telegram | None = None


def set_bot(telegram: Telegram) -> None:
    global bot
    bot = telegram


class AuthRequest(BaseModel):
    auth: str


class PlanRequest(AuthRequest):
    plan: str


class CryptoRequest(PlanRequest):
    network: str
    tx_hash: str


def _uid(auth: str) -> int:
    user_id = verify_auth_token(auth)
    if user_id is None:
        raise HTTPException(401, "Invalid login token. Open the bot and tap «Открыть Nerf Gram».")
    return user_id


@app.get("/")
async def index() -> FileResponse:
    return FileResponse(STATIC / "index.html")


app.mount("/static", StaticFiles(directory=STATIC), name="static")


@app.get("/api/config")
async def api_config() -> dict:
    return {
        "plans": [
            {
                "id": p.id,
                "days": p.days,
                "label": p.label,
                "stars": p.stars,
                "usd": p.usd,
                "wallets": service.wallet_options(p.usd),
            }
            for p in PAID_PLANS
        ],
        "trial_days": 3,
        "stars_enabled": bool(config.bot_token),
        "bot_url": f"https://t.me/{config.bot_username}",
    }


@app.get("/api/status")
async def api_status(auth: str) -> dict:
    return service.entitlement_status(_uid(auth))


@app.post("/api/stars/invoice")
async def api_stars_invoice(request: PlanRequest) -> dict:
    user_id = _uid(request.auth)
    plan = get_plan(request.plan)
    if plan is None or plan.id == "trial" or bot is None:
        raise HTTPException(400, "Unknown plan")
    payload = make_payload(plan.id, user_id)
    db.create_payment(user_id, plan.id, "stars", str(plan.stars), "XTR", "pending", payload=payload)
    url = await bot.create_invoice_link(plan.label, plan.stars, payload)
    if not url:
        raise HTTPException(502, "Telegram did not create the invoice")
    return {"url": url}


@app.post("/api/trial")
async def api_trial(request: AuthRequest) -> dict:
    user_id = _uid(request.auth)
    if not db.trial_available(user_id):
        raise HTTPException(400, "Проба уже использована")
    if bot is None:
        raise HTTPException(503, "Bot is not ready")
    result = service.grant(user_id, "trial", "trial", bot)
    return {
        "message": f"Проба на 3 дня активирована. Ключ: {result['key']} — бот отправил его отдельным сообщением.",
        "key": result["key"],
    }


@app.post("/api/crypto/claim")
async def api_crypto_claim(request: CryptoRequest) -> dict:
    user_id = _uid(request.auth)
    payment_id = await service.submit_crypto(user_id, request.plan, request.network, request.tx_hash, bot)
    if payment_id is None:
        raise HTTPException(400, "Invalid plan, network or transaction hash")
    mode = "pending"
    text = f"Заявка #{payment_id} принята. Проверяем перевод в блокчейне — ключ придёт этим же чатом."
    if bot:
        import asyncio

        asyncio.create_task(bot.send_message(user_id, text))
    return {"payment_id": payment_id, "status": mode, "message": text}


@app.get("/api/entitlement")
async def api_entitlement(key: str) -> dict:
    row = db.key_info(key.strip().upper())
    if row is None:
        return {"valid": False, "active": False, "plan": None, "active_until": 0}
    import time

    active = row["active_until"] > int(time.time())
    db.use_key(key.strip().upper())
    return {
        "valid": True,
        "active": active,
        "plan": row["plan"],
        "active_until": row["active_until"],
        "user_id": row["user_id"],
    }
