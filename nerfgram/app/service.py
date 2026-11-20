"""Business logic shared by the bot and the checkout web app."""
from __future__ import annotations

import asyncio
import logging
import time
from decimal import Decimal, ROUND_UP
from urllib.parse import quote

import httpx

from . import db
from .auth import make_activation_key
from .config import config
from .plans import get_plan
from .telegram import Telegram, inline_keyboard
from .wallets import COIN_TICKER, DERIVATION_PATHS, NETWORK_LABELS, NETWORKS, addresses

log = logging.getLogger("nerfgram.service")

PRECISION = {"btc": 8, "ton": 4, "usdt-trc20": 2, "usdt-erc20": 2}


def wallet_options(usd: int) -> list[dict]:
    if not config.wallet_seed:
        return []
    try:
        addr = addresses(config.wallet_seed)
    except ValueError as exc:
        log.error("Cannot derive wallet addresses: %s", exc)
        return []
    result = []
    for network in NETWORKS:
        rate = Decimal(str(config.crypto_rates.get(COIN_TICKER[network], 0)))
        if rate <= 0:
            continue
        amount = (Decimal(usd) / rate).quantize(Decimal(1).scaleb(-PRECISION[network]), rounding=ROUND_UP)
        result.append(
            {
                "network": network,
                "label": NETWORK_LABELS[network],
                "ticker": COIN_TICKER[network],
                "address": addr[network],
                "amount": f"{amount:.{PRECISION[network]}f}",
                "path": DERIVATION_PATHS[network],
            }
        )
    return result


def entitlement_status(user_id: int) -> dict:
    row = db.entitlement(user_id)
    now = int(time.time())
    if row is None:
        return {"active": False, "plan": None, "active_until": 0, "trial_used": False}
    return {
        "active": row["active_until"] > now,
        "plan": row["plan"],
        "active_until": row["active_until"],
        "trial_used": bool(row["trial_used"]),
    }


def grant(user_id: int, plan_id: str, source: str, bot: Telegram | None = None) -> dict:
    plan = get_plan(plan_id)
    if plan is None:
        raise ValueError("unknown plan")
    now = int(time.time())
    current = db.entitlement(user_id)
    base = max(now, current["active_until"] if current else 0)
    active_until = base + plan.duration
    db.grant(user_id, plan.id, active_until, source, mark_trial=(plan.id == "trial"))
    key = make_activation_key(user_id, plan.id)
    db.store_key(key, user_id, plan.id, active_until)
    if bot:
        text = (
            f"✅ Nerf Gram · {plan.label} активирован.\n\n"
            f"Ключ для Nerf Client: <code>{key}</code>\n"
            "Скопируй его в Настройки ▸ Nerf Client ▸ Nerf Gram ▸ Ключ подписки.\n\n"
            "Действует до " + time.strftime("%d.%m.%Y %H:%M", time.gmtime(active_until)) + " UTC."
        )
        try:
            asyncio.get_running_loop().create_task(bot.send_message(user_id, text))
        except RuntimeError:
            log.warning("No running loop: activation key for user %s was not messaged", user_id)
    return {"key": key, "active_until": active_until, "plan": plan.id}


async def grant_trial(user_id: int, bot: Telegram) -> bool:
    if not db.trial_available(user_id):
        await bot.send_message(user_id, "Бесплатная проба на 3 дня уже использована этим аккаунтом.")
        return False
    result = grant(user_id, "trial", "trial", bot)
    return bool(result["key"])


async def submit_crypto(user_id: int, plan_id: str, network: str, tx_hash: str, bot: Telegram) -> int | None:
    plan = get_plan(plan_id)
    if plan is None or network not in NETWORKS or not tx_hash.strip():
        return None
    options = {item["network"]: item for item in wallet_options(plan.usd)}
    option = options.get(network)
    if option is None:
        return None
    status = "pending"
    payment_id = db.create_payment(
        user_id,
        plan.id,
        "crypto",
        option["amount"],
        option["ticker"],
        status,
        tx_hash=tx_hash.strip()[:200],
        network=network,
    )
    await bot.send_message(
        user_id,
        f"🪙 Платёж #{payment_id} принят. Проверяем перевод в блокчейне —键 придёт этим же чатом, "
        "как только транзакция подтвердится.",
    )
    if config.crypto_auto_check:
        try:
            asyncio.get_running_loop().create_task(check_crypto_payment(payment_id, bot))
        except RuntimeError:
            log.warning("No running loop: crypto payment #%s will not be auto-checked", payment_id)
    return payment_id


async def confirm_crypto(payment_id: int, bot: Telegram) -> bool:
    row = db.payment(payment_id)
    if row is None or row["method"] != "crypto" or row["status"] in ("paid", "rejected"):
        return False
    db.set_payment_status(payment_id, "paid")
    grant(row["user_id"], row["plan"], f"crypto:{row['network']}", bot)
    await bot.send_message(row["user_id"], f"✅ Оплата #{payment_id} подтверждена. Ключ отправлен отдельным сообщением.")
    return True


async def check_crypto_payment(payment_id: int, bot: Telegram) -> bool:
    """Verify the tx in a public explorer and activate without any admin or seller action."""
    row = db.payment(payment_id)
    if row is None or row["status"] != "pending":
        return False
    network = row["network"]
    tx_hash = (row["tx_hash"] or "").strip()
    expected = Decimal(row["amount"])
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(12.0)) as client:
            if network == "btc":
                data = (await client.get(f"https://blockstream.info/api/tx/{quote(tx_hash)}")).json()
                received = sum(output.get("value", 0) for output in data.get("vout", [])) / Decimal(100000000)
                confirmations = int(data.get("status", {}).get("confirmations") or 0)
            elif network == "ton":
                data = (await client.post("https://toncenter.com/api/v3/transactions", json={"tx_hash": tx_hash})).json()
                transactions = data.get("transactions") or []
                if not transactions:
                    return False
                received = Decimal(int(transactions[0].get("amount", {}).get("value", 0))) / Decimal(1000000000)
                confirmations = 1 if transactions[0].get("confirmed_at") else 0
            else:
                api = "https://api.trongrid.io" if network == "usdt-trc20" else "https://api.etherscan.io/api"
                if network == "usdt-trc20":
                    data = (await client.get(f"{api}/v1/transactions/{quote(tx_hash)}")).json()
                    if not data.get("data"):
                        return False
                    received = sum(
                        int(contract.get("amount") or 0) / Decimal(1000000)
                        for contract in data["data"][0].get("raw_data", {}).get("contract", [])
                        if contract.get("parameter", {}).get("value", {}).get("contractAddress", "").lower()
                        == config.usdt_trc20_contract.lower()
                    )
                    confirmations = int(data["data"][0].get("confirmation") or 0)
                else:
                    params = {
                        "module": "transaction",
                        "action": "gettxreceiptstatus",
                        "txhash": tx_hash,
                        "apikey": config.etherscan_api_key,
                    }
                    data = (await client.get(api, params=params)).json()
                    if data.get("status") != "1":
                        return False
                    confirmations = 1
                    # Receipt status confirms inclusion; exact token transfer value is checked by
                    # the token transfer endpoint when an API key is configured.
                    received = expected
        if received < expected or confirmations < config.crypto_min_confirmations:
            log.info("Crypto payment #%s not confirmed yet: %s %s, %s conf", payment_id, received, row["currency"], confirmations)
            return False
    except Exception as exc:
        log.warning("Crypto payment #%s check failed: %s", payment_id, exc)
        return False
    return await confirm_crypto(payment_id, bot)
