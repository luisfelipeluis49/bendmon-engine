"""Canonical M3 battle replay identity and initial-state boundary."""

from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Any


RULESET_VERSION = "m3-1"
RNG_VERSION = "xoshiro128ss-1.1"
_DIGEST = re.compile(r"[0-9a-f]{64}\Z")


class BattleReplayError(ValueError):
    """Raised when battle replay identity or initial RNG state is invalid."""


@dataclass(frozen=True, slots=True)
class BattleReplayHeader:
    ruleset_version: str
    content_digest: str
    wait_ticks: int
    rng_version: str
    rng_state: tuple[int, int, int, int]

    def __post_init__(self) -> None:
        if self.ruleset_version != RULESET_VERSION:
            raise BattleReplayError("ruleset version mismatch")
        if type(self.content_digest) is not str or not _DIGEST.fullmatch(
            self.content_digest
        ):
            raise BattleReplayError("content digest must be lowercase SHA-256")
        if type(self.wait_ticks) is not int or self.wait_ticks not in (30, 60, 120):
            raise BattleReplayError("wait ticks must be 30, 60, or 120")
        if self.rng_version != RNG_VERSION:
            raise BattleReplayError("RNG version mismatch")
        if (
            type(self.rng_state) is not tuple
            or len(self.rng_state) != 4
            or any(type(word) is not int or not 0 <= word <= 0xFFFFFFFF for word in self.rng_state)
            or not any(self.rng_state)
        ):
            raise BattleReplayError("RNG state must contain four nonzero-domain U32 words")

    def canonical_value(self) -> dict[str, Any]:
        return {
            "contentDigest": self.content_digest,
            "rng": {"state": list(self.rng_state), "version": self.rng_version},
            "rulesetVersion": self.ruleset_version,
            "waitTicks": self.wait_ticks,
        }


def require_exact_identity(
    header: BattleReplayHeader, *, content_digest: str
) -> None:
    """Reject replay reinterpretation under any different project content."""
    if header.content_digest != content_digest:
        raise BattleReplayError("project content identity mismatch")
