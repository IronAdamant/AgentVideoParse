"""Duration hard gate: reject videos longer than DURATION_LIMIT_SECONDS."""

from __future__ import annotations

import math
from dataclasses import dataclass
from enum import Enum
from typing import Optional

from .constants import DURATION_LIMIT_SECONDS


class DurationStatus(str, Enum):
    ACCEPTED = "accepted"
    REJECTED_TOO_LONG = "rejected_too_long"
    REJECTED_INVALID = "rejected_invalid"


@dataclass(frozen=True)
class DurationDecision:
    status: DurationStatus
    seconds: Optional[float] = None
    limit: float = DURATION_LIMIT_SECONDS

    @property
    def accepted(self) -> bool:
        return self.status is DurationStatus.ACCEPTED


def evaluate_duration(duration_seconds: float) -> DurationDecision:
    """
    Evaluate whether a video duration is allowed.

    Rejects when duration_seconds > DURATION_LIMIT_SECONDS (30.0).
    Does not truncate or partially accept long videos.
    """
    if duration_seconds is None or isinstance(duration_seconds, bool):
        return DurationDecision(status=DurationStatus.REJECTED_INVALID, seconds=None)

    try:
        value = float(duration_seconds)
    except (TypeError, ValueError):
        return DurationDecision(status=DurationStatus.REJECTED_INVALID, seconds=None)

    if not math.isfinite(value) or value < 0.0:
        return DurationDecision(status=DurationStatus.REJECTED_INVALID, seconds=value)

    if value > DURATION_LIMIT_SECONDS:
        return DurationDecision(
            status=DurationStatus.REJECTED_TOO_LONG,
            seconds=value,
            limit=DURATION_LIMIT_SECONDS,
        )

    return DurationDecision(status=DurationStatus.ACCEPTED, seconds=value)
