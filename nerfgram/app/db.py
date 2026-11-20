"""SQLite storage: users, subscriptions, payments and activation keys."""
from __future__ import annotations

import sqlite3
import threading
import time
from contextlib import contextmanager
from typing import Iterator

from .config import config

_INIT = """
CREATE TABLE IF NOT EXISTS users (
    user_id       INTEGER PRIMARY KEY,
    username      TEXT,
    first_name    TEXT,
    created_at    INTEGER NOT NULL,
    last_seen     INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS entitlements (
    user_id       INTEGER PRIMARY KEY,
    plan          TEXT NOT NULL,
    active_until  INTEGER NOT NULL,
    trial_used    INTEGER NOT NULL DEFAULT 0,
    source        TEXT NOT NULL,
    updated_at    INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS payments (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id        INTEGER NOT NULL,
    plan           TEXT NOT NULL,
    method         TEXT NOT NULL,
    amount         TEXT NOT NULL,
    currency       TEXT NOT NULL,
    status         TEXT NOT NULL,
    tx_hash        TEXT,
    network        TEXT,
    payload        TEXT,
    telegram_charge_id TEXT,
    created_at     INTEGER NOT NULL,
    confirmed_at   INTEGER
);
CREATE INDEX IF NOT EXISTS payments_user ON payments(user_id);
CREATE INDEX IF NOT EXISTS payments_status ON payments(status);
CREATE TABLE IF NOT EXISTS activation_keys (
    key           TEXT PRIMARY KEY,
    user_id       INTEGER NOT NULL,
    plan          TEXT NOT NULL,
    active_until  INTEGER NOT NULL,
    created_at    INTEGER NOT NULL,
    used_at       INTEGER
);
CREATE INDEX IF NOT EXISTS activation_keys_user ON activation_keys(user_id);
"""


class Database:
    """Tiny synchronous SQLite wrapper; all writes go through a single lock."""

    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._conn = sqlite3.connect(config.db_file, check_same_thread=False, timeout=10)
        self._conn.row_factory = sqlite3.Row
        with self._lock:
            self._conn.executescript(_INIT)
            self._conn.commit()

    @contextmanager
    def transaction(self) -> Iterator[sqlite3.Connection]:
        with self._lock:
            try:
                yield self._conn
                self._conn.commit()
            except Exception:
                self._conn.rollback()
                raise

    def one(self, sql: str, params: tuple = ()) -> sqlite3.Row | None:
        with self._lock:
            return self._conn.execute(sql, params).fetchone()

    def all(self, sql: str, params: tuple = ()) -> list[sqlite3.Row]:
        with self._lock:
            return self._conn.execute(sql, params).fetchall()

    def touch_user(self, user_id: int, username: str | None, first_name: str | None) -> None:
        now = int(time.time())
        with self.transaction() as db:
            db.execute(
                """INSERT INTO users (user_id, username, first_name, created_at, last_seen)
                   VALUES (?, ?, ?, ?, ?)
                   ON CONFLICT(user_id) DO UPDATE SET
                     username = COALESCE(excluded.username, users.username),
                     first_name = COALESCE(excluded.first_name, users.first_name),
                     last_seen = excluded.last_seen""",
                (user_id, username, first_name, now, now),
            )

    def entitlement(self, user_id: int) -> sqlite3.Row | None:
        return self.one("SELECT * FROM entitlements WHERE user_id = ?", (user_id,))

    def grant(self, user_id: int, plan: str, active_until: int, source: str, mark_trial: bool = False) -> None:
        now = int(time.time())
        with self.transaction() as db:
            db.execute(
                """INSERT INTO entitlements (user_id, plan, active_until, trial_used, source, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?)
                   ON CONFLICT(user_id) DO UPDATE SET
                     plan = excluded.plan,
                     active_until = excluded.active_until,
                     trial_used = CASE WHEN excluded.trial_used = 1 THEN 1 ELSE entitlements.trial_used END,
                     source = excluded.source,
                     updated_at = excluded.updated_at""",
                (user_id, plan, active_until, 1 if mark_trial else 0, source, now),
            )

    def trial_available(self, user_id: int) -> bool:
        row = self.entitlement(user_id)
        return row is None or not row["trial_used"]

    def revoke(self, user_id: int) -> None:
        with self.transaction() as db:
            db.execute("UPDATE entitlements SET active_until = 0, updated_at = ? WHERE user_id = ?", (int(time.time()), user_id))

    def create_payment(
        self,
        user_id: int,
        plan: str,
        method: str,
        amount: str,
        currency: str,
        status: str,
        *,
        tx_hash: str | None = None,
        network: str | None = None,
        payload: str | None = None,
        telegram_charge_id: str | None = None,
    ) -> int:
        with self.transaction() as db:
            cur = db.execute(
                """INSERT INTO payments
                   (user_id, plan, method, amount, currency, status, tx_hash, network, payload,
                    telegram_charge_id, created_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (user_id, plan, method, amount, currency, status, tx_hash, network, payload, telegram_charge_id, int(time.time())),
            )
            return int(cur.lastrowid)

    def payment(self, payment_id: int) -> sqlite3.Row | None:
        return self.one("SELECT * FROM payments WHERE id = ?", (payment_id,))

    def payment_by_charge(self, charge_id: str) -> sqlite3.Row | None:
        return self.one("SELECT * FROM payments WHERE telegram_charge_id = ?", (charge_id,))

    def set_payment_status(self, payment_id: int, status: str) -> None:
        with self.transaction() as db:
            db.execute(
                "UPDATE payments SET status = ?, confirmed_at = ? WHERE id = ?",
                (status, int(time.time()), payment_id),
            )

    def set_payment_payload(self, payment_id: int, payload: str) -> None:
        with self.transaction() as db:
            db.execute("UPDATE payments SET payload = ? WHERE id = ?", (payload, payment_id))

    def pending_crypto(self) -> list[sqlite3.Row]:
        return self.all("SELECT * FROM payments WHERE method = 'crypto' AND status IN ('pending','review') ORDER BY id")

    def store_key(self, key: str, user_id: int, plan: str, active_until: int) -> None:
        with self.transaction() as db:
            db.execute(
                "INSERT OR REPLACE INTO activation_keys (key, user_id, plan, active_until, created_at) VALUES (?, ?, ?, ?, ?)",
                (key, user_id, plan, active_until, int(time.time())),
            )

    def key_info(self, key: str) -> sqlite3.Row | None:
        return self.one("SELECT * FROM activation_keys WHERE key = ?", (key,))

    def use_key(self, key: str) -> None:
        with self.transaction() as db:
            db.execute("UPDATE activation_keys SET used_at = ? WHERE key = ? AND used_at IS NULL", (int(time.time()), key))


db = Database()

# Module-level wrappers keep call sites short: db.grant(...) instead of db.db.grant(...).
def touch_user(user_id: int, username: str | None, first_name: str | None) -> None:
    db.touch_user(user_id, username, first_name)


def entitlement(user_id: int) -> sqlite3.Row | None:
    return db.entitlement(user_id)


def grant(user_id: int, plan: str, active_until: int, source: str, mark_trial: bool = False) -> None:
    db.grant(user_id, plan, active_until, source, mark_trial)


def trial_available(user_id: int) -> bool:
    return db.trial_available(user_id)


def revoke(user_id: int) -> None:
    db.revoke(user_id)


def create_payment(user_id: int, plan: str, method: str, amount: str, currency: str, status: str, **kwargs) -> int:
    return db.create_payment(user_id, plan, method, amount, currency, status, **kwargs)


def payment(payment_id: int) -> sqlite3.Row | None:
    return db.payment(payment_id)


def payment_by_charge(charge_id: str) -> sqlite3.Row | None:
    return db.payment_by_charge(charge_id)


def set_payment_status(payment_id: int, status: str) -> None:
    db.set_payment_status(payment_id, status)


def set_payment_payload(payment_id: int, payload: str) -> None:
    db.set_payment_payload(payment_id, payload)


def pending_crypto() -> list[sqlite3.Row]:
    return db.pending_crypto()


def store_key(key: str, user_id: int, plan: str, active_until: int) -> None:
    db.store_key(key, user_id, plan, active_until)


def key_info(key: str) -> sqlite3.Row | None:
    return db.key_info(key)


def use_key(key: str) -> None:
    db.use_key(key)
