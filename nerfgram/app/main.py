"""Entry point: one process serving the checkout and polling the bot."""
from __future__ import annotations

import asyncio
import logging

import uvicorn

from . import db, web
from .bot import poll
from .config import config
from .telegram import Telegram

logging.basicConfig(
    level=getattr(logging, config.log_level.upper(), logging.INFO),
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
log = logging.getLogger("nerfgram")


async def _main() -> None:
    if not config.bot_token:
        raise SystemExit("BOT_TOKEN is required. Copy .env.example to .env and fill it in.")
    telegram = Telegram()
    web.set_bot(telegram)
    await telegram.setup()
    log.info("Database: %s", config.db_file)
    server = uvicorn.Server(
        uvicorn.Config(
            web.app,
            host=config.host,
            port=config.port,
            log_level=config.log_level.lower(),
            access_log=False,
        )
    )
    tasks = [asyncio.create_task(server.serve()), asyncio.create_task(poll(telegram))]
    try:
        await asyncio.gather(*tasks)
    finally:
        for task in tasks:
            task.cancel()
        await telegram.close()


def main() -> None:
    asyncio.run(_main())


if __name__ == "__main__":
    main()
