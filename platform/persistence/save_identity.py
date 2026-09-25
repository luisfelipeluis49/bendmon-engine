"""Versioned save identity and exact compatibility checks.

This module describes the identity envelope only. It does not parse, migrate,
or install save payloads; callers must run explicit schema migrations and
validate the resulting state before use.
"""

from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Any

from .battle_replay import (M6_RULESET_VERSION, M7_RULESET_VERSION,
                            RULESET_VERSION, SUPPORTED_REPLAY_RULESETS)

_DIGEST = re.compile(r"[0-9a-f]{64}\Z")


class SaveIdentityError(ValueError):
    """Raised when a save identity is malformed or incompatible."""


@dataclass(frozen=True, slots=True)
class SaveIdentity:
    """Stable compatibility identity stored beside a canonical save payload."""

    schema_version: int
    ruleset_version: str
    content_digest: str

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version < 1:
            raise SaveIdentityError("save schema version must be a positive integer")
        if (
            type(self.ruleset_version) is not str
            or self.ruleset_version not in SUPPORTED_REPLAY_RULESETS
        ):
            raise SaveIdentityError(f"unsupported save ruleset version: {self.ruleset_version!r}")
        if (
            type(self.content_digest) is not str
            or not _DIGEST.fullmatch(self.content_digest)
        ):
            raise SaveIdentityError("content digest must be lowercase SHA-256")

    def canonical_value(self) -> dict[str, Any]:
        return {
            "contentDigest": self.content_digest,
            "rulesetVersion": self.ruleset_version,
            "saveSchemaVersion": self.schema_version,
        }


def require_exact_identity(
    identity: SaveIdentity,
    *,
    expected_ruleset_version: str = RULESET_VERSION,
    expected_content_digest: str,
) -> None:
    """Reject save data unless semantics and project content both match exactly."""
    if identity.ruleset_version != expected_ruleset_version:
        raise SaveIdentityError(
            "ruleset version mismatch: "
            f"expected {expected_ruleset_version!r}, actual {identity.ruleset_version!r}"
        )
    if identity.content_digest != expected_content_digest:
        raise SaveIdentityError(
            "project content identity mismatch: "
            f"expected {expected_content_digest!r}, actual {identity.content_digest!r}"
        )


__all__ = [
    "M6_RULESET_VERSION",
    "M7_RULESET_VERSION",
    "RULESET_VERSION",
    "SaveIdentity",
    "SaveIdentityError",
    "require_exact_identity",
]
