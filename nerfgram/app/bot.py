"""Long-polling update loop for the Nerf Gram bot."""
from __future__ import annotations

import asyncio
import logging
import time

from . import db, service
from .auth import make_auth_token, parse_payload
from .config import config
from .plans import get_plan, PAID_PLANS
from .telegram import Telegram, inline_keyboard

log = logging.getLogger("nerfgram.bot")


def main_keyboard() -> dict:
    return inline_keyboard(
        [
            [{"text": "💎 Открыть Nerf Gram", "url": f"{config.public_base_url}/?auth={{auth}}"}],
            [{"text": "🎁 Проба 3 дня", "callback_data": "trial"}, {"text": "📊 Мой статус", "callback_data": "status"}],
            [{"text": "ℹ️ Как это работает", "callback_data": "how"}],
        ]
    )


async def handle_message(bot: Telegram, message: dict) -> None:
    user = message.get("from") or {}
    user_id = user.get("id")
    if not user_id:
        return
    db.touch_user(user_id, user.get("username"), user.get("first_name"))
    text = (message.get("text") or "").strip()
    if text.startswith("/start") or text.startswith("/menu"):
        token = make_auth_token(user_id)
        markup = main_keyboard()
        markup["inline_keyboard"][0][0]["url"] = markup["inline_keyboard"][0][0]["url"].format(auth=token)
        await bot.send_message(
            user_id,
            "✨ <b>Nerf Gram</b> — платная подписка для LARP-функций Nerf Client.\n\n"
            "3 дня — бесплатная проба (один раз)\n"
            "7 дней — $2\n"
            "30 дней — $4\n\n"
            "Оплатить можно Telegram Stars или криптовалютой. После оплаты бот выдаст ключ — "
            "введи его в приложении: Настройки ▸ Nerf Client ▸ LARP ▸ Nerf Gram.",
            reply_markup=markup,
        )
    elif text.startswith("/status"):
        await send_status(bot, user_id)
    elif message.get("successful_payment"):
        await handle_payment(bot, message)


async def send_status(bot: Telegram, user_id: int) -> None:
    status = service.entitlement_status(user_id)
    if status["active"]:
        line = f"Подписка активна до {time.strftime('%d.%m.%Y %H:%M', time.gmtime(status['active_until']))} UTC."
    else:
        line = "Подписки нет или она истекла."
    trial = "Проба использована." if status["trial_used"] else "Проба на 3 дня доступна."
    await bot.send_message(user_id, f"📊 {line}\n{trial}", reply_markup=main_keyboard())


async def handle_payment(bot: Telegram, message: dict) -> None:
    payment = message["successful_payment"]
    payload = payment.get("invoice_payload", "")
    parsed = parse_payload(payload)
    if not parsed:
        log.warning("Bad Stars payload: %r", payload)
        return
    plan_id, user_id = parsed
    if db.payment_by_charge(payment.get("telegram_payment_charge_id", "")):
        return
    db.create_payment(
        user_id,
        plan_id,
        "stars",
        str(payment.get("total_amount", "")),
        "XTR",
        "paid",
        payload=payload,
        telegram_charge_id=payment.get("telegram_payment_charge_id"),
    )
    service.grant(user_id, plan_id, "stars", bot)
    log.info("Stars payment for user %s, plan %s", user_id, plan_id)


async def handle_callback(bot: Telegram, callback: dict) -> None:
    callback_id = callback["id"]
    user = callback.get("from") or {}
    user_id = user.get("id")
    data = callback.get("data") or ""
    if not user_id:
        return
    db.touch_user(user_id, user.get("username"), user.get("first_name"))
    if data == "trial":
        ok = await service.grant_trial(user_id, bot)
        await bot.answer_callback(callback_id, "Проба активирована" if ok else "Проба уже использована", alert=True)
    elif data == "status":
        await bot.answer_callback(callback_id)
        await send_status(bot, user_id)
    elif data == "how":
        await bot.answer_callback(callback_id)
        await bot.send_message(
            user_id,
            "1️⃣ Открой сайт из кнопки выше — он запомнит твой Telegram ID.\n"
            "2️⃣ Выбери тариф: 3 дня бесплатно, 7 дней ($2), 30 дней ($4).\n"
            "3️⃣ Оплати Stars или криптовалютой (TON / BTC / USDT TRC20 / USDT ERC20).\n"
            "4️⃣ После проверки перевода в блокчейне бот сам пришлёт ключ вида <code>NFG-XXXXXX-XX</code>.\n"
            "5️⃣ Введи ключ в Nerf Client ▸ Настройки ▸ Nerf Client ▸ LARP ▸ Nerf Gram.\n\n"
            "Передача LARP-гифтов доступна только после недели переписки с получателем "
            "и с предупреждением: это для LARP, не для скама.",
        )
    else:
        await bot.answer_callback(callback_id)


async def handle_pre_checkout(bot: Telegram, query: dict) -> None:
    parsed = parse_payload(query.get("invoice_payload", ""))
    user_id = query.get("from", {}).get("id")
    if not parsed or parsed[1] != user_id or get_plan(parsed[0]) is None:
        await bot.answer_pre_checkout(query["id"], False, "Платёж устарел, открой сайт заново")
        return
    await bot.answer_pre_checkout(query["id"], True)


async def handle_subscription(bot: Telegram, update: dict) -> None:
    sub = update.get("subscription") or {}
    user_id = (sub.get("user") or {}).get("id")
    state = sub.get("state")
    log.info("Subscription update: user=%s state=%s payload=%r", user_id, state, sub.get("invoice_payload"))
    if not user_id or state not in ("canceled", "failed"):
        return
    # Native 30-day subscriptions are not used by default (Bot API only allows 2592000),
    # but revoke if one is ever cancelled.
    db.revoke(user_id)
    await bot.send_message(user_id, "Подписка Nerf Gram отменена — доступ к LARP-передаче закрыт.")


async def poll(bot: Telegram) -> None:
    offset = 0
    log.info("Bot polling started")
    while True:
        try:
            updates = await bot.get_updates(offset)
            for update in updates:
                offset = max(offset, update["update_id"] + 1)
                try:
                    if "message" in update:
                        await handle_message(bot, update["message"])
                    elif "callback_query" in update:
                        await handle_callback(bot, update["callback_query"])
                    elif "pre_checkout_query" in update:
                        await handle_pre_checkout(bot, update["pre_checkout_query"])
                    elif "subscription" in update:
                        await handle_subscription(bot, update)
                except Exception:
                    log.exception("Failed to handle update %s", update.get("update_id"))
        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception("Polling error")
            await asyncio.sleep(2)
