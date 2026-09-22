"""Strict loader for the approved M5 multi-type fixture corpus."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

FIXTURE_VERSION = "m5-multitype-1"
TYPE_MIN, TYPE_MAX = 0, 9
POWER_MIN, POWER_MAX = 1, 200
COMPONENT_MAX = 4


class FixtureValidationError(ValueError):
    pass


def _fail(path: str, message: str) -> None:
    raise FixtureValidationError(f"{path}: {message}")


def _object(value: Any, path: str, fields: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "expected object")
    unknown = sorted(set(value) - fields)
    if unknown:
        _fail(path, f"unknown field(s): {', '.join(unknown)}")
    return value


def _int(value: Any, path: str, low: int, high: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        _fail(path, "expected integer")
    if not low <= value <= high:
        _fail(path, f"expected integer in [{low}, {high}]")
    return value


def _types(value: Any, path: str, *, nonempty: bool = True, max_count: int | None = None) -> list[int]:
    if not isinstance(value, list):
        _fail(path, "expected array")
    if nonempty and not value:
        _fail(path, "expected non-empty array")
    if max_count is None and len(value) > COMPONENT_MAX:
        _fail(path, f"expected at most {COMPONENT_MAX} components")
    if max_count is not None and len(value) > max_count:
        _fail(path, f"expected at most {max_count} types")
    result = [_int(item, f"{path}/{i}", TYPE_MIN, TYPE_MAX) for i, item in enumerate(value)]
    if len(result) != len(set(result)):
        _fail(path, "duplicate type ID")
    return result


def load_fixture(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        _fail(str(path), f"invalid JSON: {error}")
    fixture = _object(value, path.name, {"fixture_version", "id", "description", "power", "components", "actor_types", "defender_types", "expected", "invalid"})
    for key in ("fixture_version", "id", "description", "power", "components", "actor_types", "defender_types", "expected"):
        if key not in fixture:
            _fail(path.name, f"missing field: {key}")
    if fixture["fixture_version"] != FIXTURE_VERSION:
        _fail(f"{path.name}/fixture_version", f"expected {FIXTURE_VERSION!r}")
    for key in ("id", "description"):
        if not isinstance(fixture[key], str) or not fixture[key]:
            _fail(f"{path.name}/{key}", "expected non-empty string")
    _int(fixture["power"], f"{path.name}/power", 0 if "invalid" in fixture else POWER_MIN, POWER_MAX)
    if "invalid" not in fixture:
        _types(fixture["components"], f"{path.name}/components")
    elif not isinstance(fixture["components"], list):
        _fail(f"{path.name}/components", "expected array")
    if "invalid" not in fixture:
        for key in ("actor_types", "defender_types"):
            values = _types(fixture[key], f"{path.name}/{key}", max_count=2)
            if not values:
                _fail(f"{path.name}/{key}", "expected one or two types")
            if len(values) != len(set(values)):
                _fail(f"{path.name}/{key}", "duplicate type ID")
    expected = _object(fixture["expected"], f"{path.name}/expected", {"allocations", "component_damage", "total_damage", "canonical", "native", "javascript"})
    for key in ("allocations", "component_damage", "total_damage", "canonical", "native", "javascript"):
        if key not in expected:
            _fail(f"{path.name}/expected", f"missing field: {key}")
    for key in ("allocations", "component_damage"):
        values = expected[key]
        if not isinstance(values, list):
            _fail(f"{path.name}/expected/{key}", "expected array")
        for i, item in enumerate(values):
            _int(item, f"{path.name}/expected/{key}/{i}", 0, 2**63 - 1)
    _int(expected["total_damage"], f"{path.name}/expected/total_damage", 0, 2**63 - 1)
    for key in ("canonical", "native", "javascript"):
        if not isinstance(expected[key], str):
            _fail(f"{path.name}/expected/{key}", "expected string")
    if expected["native"] != expected["javascript"]:
        _fail(f"{path.name}/expected", "native/javascript canonical mismatch")
    if "invalid" in fixture and not isinstance(fixture["invalid"], str):
        _fail(f"{path.name}/invalid", "expected string")
    return fixture


def load_corpus(directory: Path) -> list[dict[str, Any]]:
    index_path = directory / "index.json"
    index = _object(json.loads(index_path.read_text(encoding="utf-8")), "index", {"fixture_version", "fixtures"})
    if index.get("fixture_version") != FIXTURE_VERSION:
        _fail("index/fixture_version", f"expected {FIXTURE_VERSION!r}")
    names = index.get("fixtures")
    if not isinstance(names, list) or any(not isinstance(name, str) for name in names):
        _fail("index/fixtures", "expected array of strings")
    if names != sorted(names) or len(names) != len(set(names)):
        _fail("index/fixtures", "fixture names must be unique and sorted")
    return [load_fixture(directory / name) for name in names]
