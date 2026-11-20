"""Environment configuration for the Nerf Gram payment backend."""
from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv

# Pterodactyl injects variables directly; a local .env is a convenience for dev runs.
load_dotenv(Path(__file__).resolve().parent.parent / ".env", override=False)


def _int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        return default


def _bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in ("1", "true", "yes", "on")


@dataclass(frozen=True)
class Config:
    bot_token: str = field(default_factory=lambda: os.getenv("BOT_TOKEN", ""))
    bot_username: str = field(default_factory=lambda: os.getenv("BOT_USERNAME", "NerfGramBot"))
    public_base_url: str = field(
        default_factory=lambda: os.getenv("PUBLIC_BASE_URL", "http://127.0.0.1:8080").rstrip("/")
    )
    host: str = field(default_factory=lambda: os.getenv("HOST", "0.0.0.0"))
    port: int = field(default_factory=lambda: _int("PORT", 8080))
    app_secret: str = field(default_factory=lambda: os.getenv("APP_SECRET", "dev-only-secret"))
    wallet_seed: str = field(default_factory=lambda: os.getenv("WALLET_SEED", "").strip().strip('"'))
    stars_price_7: int = field(default_factory=lambda: _int("STARS_PRICE_7", 200))
    stars_price_30: int = field(default_factory=lambda: _int("STARS_PRICE_30", 400))
    crypto_rates: dict = field(default_factory=lambda: json.loads(os.getenv("CRYPTO_RATES_JSON", "{}")))
    crypto_auto_check: bool = field(default_factory=lambda: _bool("CRYPTO_AUTO_CHECK", True))
    crypto_min_confirmations: int = field(default_factory=lambda: _int("CRYPTO_MIN_CONFIRMATIONS", 1))
    usdt_trc20_contract: str = field(default_factory=lambda: os.getenv("USDT_TRC20_CONTRACT", "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"))
    etherscan_api_key: str = field(default_factory=lambda: os.getenv("ETHERSCAN_API_KEY", ""))
    admin_ids: tuple = field(
        default_factory=lambda: tuple(
            int(x) for x in os.getenv("ADMIN_IDS", "").split(",") if x.strip().isdigit()
        )
    )
    db_path: str = field(default_factory=lambda: os.getenv("DB_PATH", "data/nerfgram.sqlite3"))
    log_level: str = field(default_factory=lambda: os.getenv("LOG_LEVEL", "INFO"))

    @property
    def api_base(self) -> str:
        return f"{self.public_base_url}/api"

    @property
    def db_file(self) -> Path:
        path = Path(self.db_path)
        if not path.is_absolute():
            path = Path(__file__).resolve().parent.parent / path
        path.parent.mkdir(parents=True, exist_ok=True)
        return path


config = Config()
