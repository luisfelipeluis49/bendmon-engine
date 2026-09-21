"""Canonical JSON encoding and SHA-256 identity for validated data.

This module deliberately handles only an already validated, in-memory value.
It does not read or write files and does not implement save-slot policy.
"""

from __future__ import annotations

import hashlib
import json
from typing import Any


class CanonicalJSONError(ValueError):
    """Raised when a value is outside the canonical JSON value domain."""


def _validate(value: Any, active: set[int]) -> None:
    """Validate the supported JSON domain and reject recursive containers."""
    if value is None or type(value) is str:
        if type(value) is str and any(0xD800 <= ord(char) <= 0xDFFF for char in value):
            raise CanonicalJSONError("Unicode surrogate code points are not allowed")
        return
    if type(value) is int:
        return
    if type(value) is bool:
        raise CanonicalJSONError("booleans are not allowed in canonical JSON")
    if type(value) is float:
        raise CanonicalJSONError("floating-point numbers are not allowed in canonical JSON")
    if isinstance(value, dict):
        marker = id(value)
        if marker in active:
            raise CanonicalJSONError("recursive containers are not allowed")
        active.add(marker)
        try:
            for key, child in value.items():
                if type(key) is not str:
                    raise CanonicalJSONError("object keys must be strings")
                if any(0xD800 <= ord(char) <= 0xDFFF for char in key):
                    raise CanonicalJSONError("Unicode surrogate code points are not allowed")
                _validate(child, active)
        finally:
            active.remove(marker)
        return
    if isinstance(value, list):
        marker = id(value)
        if marker in active:
            raise CanonicalJSONError("recursive containers are not allowed")
        active.add(marker)
        try:
            for child in value:
                _validate(child, active)
        finally:
            active.remove(marker)
        return
    raise CanonicalJSONError(f"unsupported JSON value type: {type(value).__name__}")


def canonical_json(value: Any) -> bytes:
    """Return canonical compact UTF-8 JSON bytes for a validated value.

    Objects use lexicographically sorted string keys, arrays retain their
    original order, and numbers are limited to exact Python integers. Boolean
    values are rejected even though Python models them as a subclass of int.
    """
    _validate(value, set())
    try:
        text = json.dumps(
            value,
            ensure_ascii=False,
            allow_nan=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        return text.encode("utf-8")
    except (UnicodeEncodeError, TypeError, ValueError) as exc:
        raise CanonicalJSONError(str(exc)) from exc


def canonical_sha256(value: Any) -> str:
    """Return the lowercase SHA-256 hex digest of :func:`canonical_json`."""
    return hashlib.sha256(canonical_json(value)).hexdigest()


def canonical_json_sha256(value: Any) -> str:
    """Compatibility spelling for :func:`canonical_sha256`."""
    return canonical_sha256(value)
