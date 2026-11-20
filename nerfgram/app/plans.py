"""Subscription plans and their prices."""
from __future__ import annotations

from dataclasses import dataclass

from .config import config

SECONDS_PER_DAY = 86400
PLAN_DAYS = {"trial": 3, "week": 7, "month": 30}
PLAN_LABELS = {"trial": "3 дня", "week": "7 дней", "month": "30 дней"}


@dataclass(frozen=True)
class Plan:
    id: str
    days: int
    label: str
    stars: int
    usd: int

    @property
    def duration(self) -> int:
        return self.days * SECONDS_PER_DAY


def get_plan(plan_id: str) -> Plan | None:
    if plan_id not in PLAN_DAYS:
        return None
    days = PLAN_DAYS[plan_id]
    if plan_id == "trial":
        stars, usd = 0, 0
    elif plan_id == "week":
        stars, usd = config.stars_price_7, 2
    else:
        stars, usd = config.stars_price_30, 4
    return Plan(id=plan_id, days=days, label=PLAN_LABELS[plan_id], stars=stars, usd=usd)


ALL_PLANS = [get_plan("trial"), get_plan("week"), get_plan("month")]
PAID_PLANS = [get_plan("week"), get_plan("month")]
