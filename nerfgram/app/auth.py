"""Stateless signed login token issued by the bot to the web checkout."""
from __future__ import annotations

import hashlib
import hmac

from .config import config


def _sign(value: str) -> str:
    return hmac.new(config.app_secret.encode(), value.encode(), hashlib.sha256).hexdigest()[:16]


def make_auth_token(user_id: int) -> str:
    return f"{user_id}.{_sign(str(user_id))}"


def verify_auth_token(token: str) -> int | None:
    if not token or "." not in token:
        return None
    user_id, signature = token.rsplit(".", 1)
    if not user_id.isdigit() or not hmac.compare_digest(_sign(user_id), signature):
        return None
    return int(user_id)


def make_payload(plan: str, user_id: int) -> str:
    """Stars invoice payload, verified later in successful_payment."""
    import secrets

    nonce = secrets.token_hex(4)
    body = f"{plan}:{user_id}:{nonce}"
    signature = hmac.new(config.app_secret.encode(), body.encode(), hashlib.sha256).hexdigest()[:12]
    return f"ng:{body}:{signature}"


def parse_payload(payload: str) -> tuple[str, int] | None:
    if not payload.startswith("ng:"):
        return None
    parts = payload.split(":")
    if len(parts) != 5:
        return None
    _, plan, user_id, nonce, signature = parts
    if not user_id.isdigit():
        return None
    body = f"{plan}:{user_id}:{nonce}"
    expected = hmac.new(config.app_secret.encode(), body.encode(), hashlib.sha256).hexdigest()[:12]
    if not hmac.compare_digest(expected, signature):
        return None
    return plan, int(user_id)


def make_activation_key(user_id: int, plan: str) -> str:
    """Human-friendly key the user types into the iOS app."""
    import secrets

    random = secrets.token_hex(3).upper()  # 6 chars
    body = f"{user_id}:{plan}:{random}"
    check = hmac.new(config.app_secret.encode(), body.encode(), hashlib.sha256).hexdigest()[:2].upper()
    return f"NFG-{random}-{check}"
