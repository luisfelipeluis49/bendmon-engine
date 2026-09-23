"""Strict loader for the pure M6 fixture corpus."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

FIXTURE_VERSION = "m6-core-1"
U32_MAX = 2**32 - 1
ID_MAX = U32_MAX
COOLDOWN_MAX = 3600
COOLDOWN_MIN = 60
MIXED_COOLDOWN_MIN = 90
MIXED_COOLDOWN_MAX = 5400


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


def _required(obj: dict[str, Any], fields: set[str], path: str) -> None:
    missing = sorted(fields - set(obj))
    if missing:
        _fail(path, f"missing field(s): {', '.join(missing)}")


def _int(value: Any, path: str, low: int, high: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        _fail(path, "expected integer")
    if not low <= value <= high:
        _fail(path, f"expected integer in [{low}, {high}]")
    return value


def _bool(value: Any, path: str) -> bool:
    if not isinstance(value, bool):
        _fail(path, "expected boolean")
    return value


def _array(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        _fail(path, "expected array")
    return value


def _ids(value: Any, path: str, *, unique: bool = False) -> list[int]:
    result = [_int(item, f"{path}/{index}", 0, ID_MAX) for index, item in enumerate(_array(value, path))]
    if unique and len(result) != len(set(result)):
        _fail(path, "duplicate identity")
    return result


def _load_identity(fixture: dict[str, Any], path: str) -> None:
    data = _object(fixture["input"], f"{path}/input", {"left", "right"})
    _required(data, {"left", "right"}, f"{path}/input")
    left = _int(data["left"], f"{path}/input/left", 0, ID_MAX)
    right = _int(data["right"], f"{path}/input/right", 0, ID_MAX)
    if left == right:
        _fail(f"{path}/input", "recipe source IDs must be distinct")
    expected = _object(fixture["expected"], f"{path}/expected", {"canonical"})
    _required(expected, {"canonical"}, f"{path}/expected")
    canonical = _ids(expected["canonical"], f"{path}/expected/canonical")
    if len(canonical) != 2:
        _fail(f"{path}/expected/canonical", "expected exactly two IDs")


def _load_cooldown(fixture: dict[str, Any], path: str) -> None:
    data = _object(fixture["input"], f"{path}/input", {"ordinary"})
    _required(data, {"ordinary"}, f"{path}/input")
    ordinary = _array(data["ordinary"], f"{path}/input/ordinary")
    for index, value in enumerate(ordinary):
        _int(value, f"{path}/input/ordinary/{index}", COOLDOWN_MIN, COOLDOWN_MAX)
    expected = _object(fixture["expected"], f"{path}/expected", {"mixed"})
    _required(expected, {"mixed"}, f"{path}/expected")
    mixed = _array(expected["mixed"], f"{path}/expected/mixed")
    for index, value in enumerate(mixed):
        _int(value, f"{path}/expected/mixed/{index}", MIXED_COOLDOWN_MIN, MIXED_COOLDOWN_MAX)
    if len(ordinary) != len(mixed):
        _fail(f"{path}/expected/mixed", "must align with ordinary cooldowns")


def _load_learning(fixture: dict[str, Any], path: str) -> None:
    data = _object(fixture["input"], f"{path}/input", {"sources", "witnesses", "training", "terminal_results"})
    _required(data, {"sources", "witnesses", "training", "terminal_results"}, f"{path}/input")
    sources = _ids(data["sources"], f"{path}/input/sources", unique=True)
    if len(sources) != 2 or sources[0] == sources[1]:
        _fail(f"{path}/input/sources", "expected two distinct source IDs")
    witnesses = _array(data["witnesses"], f"{path}/input/witnesses")
    for index, value in enumerate(witnesses):
        item_path = f"{path}/input/witnesses/{index}"
        item = _object(value, item_path, {"id", "active", "conscious", "moves"})
        _required(item, {"id", "active", "conscious", "moves"}, item_path)
        _int(item["id"], f"{item_path}/id", 0, ID_MAX)
        _bool(item["active"], f"{item_path}/active")
        _bool(item["conscious"], f"{item_path}/conscious")
        _ids(item["moves"], f"{item_path}/moves")
    training = _array(data["training"], f"{path}/input/training")
    case_fields = {
        "id", "trainer", "in_battle", "tokens", "observed", "learned",
        "has_sources", "compatible", "accepted", "tokens_after", "progress", "reason",
    }
    for index, value in enumerate(training):
        item_path = f"{path}/input/training/{index}"
        item = _object(value, item_path, case_fields)
        _required(item, case_fields, item_path)
        if not isinstance(item["id"], str) or not item["id"]:
            _fail(f"{item_path}/id", "expected non-empty string")
        for key in ("trainer", "in_battle", "observed", "learned", "has_sources", "compatible", "accepted"):
            _bool(item[key], f"{item_path}/{key}")
        _int(item["tokens"], f"{item_path}/tokens", 0, U32_MAX)
        _int(item["tokens_after"], f"{item_path}/tokens_after", 0, U32_MAX)
        if item["progress"] is not None:
            _int(item["progress"], f"{item_path}/progress", 0, 40)
        if item["reason"] is not None and item["reason"] not in {
            "in_battle", "no_trainer", "no_token", "not_observed",
            "already_learned", "missing_source", "missing_recipe", "invalid_catalog",
        }:
            _fail(f"{item_path}/reason", "unknown training failure")
    terminals = _array(data["terminal_results"], f"{path}/input/terminal_results")
    if terminals != ["victory", "defeat", "draw", "timeout", "escaped"]:
        _fail(f"{path}/input/terminal_results", "must enumerate every committed terminal result in canonical order")
    expected = _object(fixture["expected"], f"{path}/expected", {"witness_ids", "observed_after_terminal", "training_case_count"})
    _required(expected, {"witness_ids", "observed_after_terminal", "training_case_count"}, f"{path}/expected")
    _ids(expected["witness_ids"], f"{path}/expected/witness_ids", unique=True)
    _ids(expected["observed_after_terminal"], f"{path}/expected/observed_after_terminal", unique=True)
    _int(expected["training_case_count"], f"{path}/expected/training_case_count", 0, 100)


def _load_harmony(fixture: dict[str, Any], path: str) -> None:
    data = _object(fixture["input"], f"{path}/input", {"progress"})
    _required(data, {"progress"}, f"{path}/input")
    values = _array(data["progress"], f"{path}/input/progress")
    for index, value in enumerate(values):
        _int(value, f"{path}/input/progress/{index}", 0, U32_MAX)
    expected = _object(fixture["expected"], f"{path}/expected", {"tiers", "packages"})
    _required(expected, {"tiers", "packages"}, f"{path}/expected")
    tiers = _array(expected["tiers"], f"{path}/expected/tiers")
    packages = _array(expected["packages"], f"{path}/expected/packages")
    if len(tiers) != len(values) or len(packages) != len(values):
        _fail(f"{path}/expected", "tiers and packages must align with progress values")
    allowed_tiers = {"novice", "familiar", "practiced", "expert", "master", "perfected"}
    for index, (tier, package) in enumerate(zip(tiers, packages)):
        if tier not in allowed_tiers:
            _fail(f"{path}/expected/tiers/{index}", "unknown Harmony tier")
        pair = _array(package, f"{path}/expected/packages/{index}")
        if len(pair) != 2:
            _fail(f"{path}/expected/packages/{index}", "expected accuracy/critical pair")
        for j, value in enumerate(pair):
            _int(value, f"{path}/expected/packages/{index}/{j}", 0, 10000)


def load_fixture(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        _fail(str(path), f"invalid JSON: {error}")
    fixture = _object(value, path.name, {"fixture_version", "id", "description", "kind", "input", "expected"})
    _required(fixture, {"fixture_version", "id", "description", "kind", "input", "expected"}, path.name)
    if fixture["fixture_version"] != FIXTURE_VERSION:
        _fail(f"{path.name}/fixture_version", f"expected {FIXTURE_VERSION!r}")
    for key in ("id", "description"):
        if not isinstance(fixture[key], str) or not fixture[key]:
            _fail(f"{path.name}/{key}", "expected non-empty string")
    loaders = {
        "identity": _load_identity,
        "cooldown": _load_cooldown,
        "learning": _load_learning,
        "harmony": _load_harmony,
    }
    loader = loaders.get(fixture["kind"])
    if loader is None:
        _fail(f"{path.name}/kind", "unknown M6 fixture kind")
    loader(fixture, path.name)
    return fixture


def load_corpus(directory: Path) -> list[dict[str, Any]]:
    try:
        index_value = json.loads((directory / "index.json").read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        _fail(str(directory / "index.json"), f"invalid JSON: {error}")
    index = _object(index_value, "index", {"fixture_version", "fixtures"})
    _required(index, {"fixture_version", "fixtures"}, "index")
    if index["fixture_version"] != FIXTURE_VERSION:
        _fail("index/fixture_version", f"expected {FIXTURE_VERSION!r}")
    names = index["fixtures"]
    if not isinstance(names, list) or any(not isinstance(name, str) for name in names):
        _fail("index/fixtures", "expected array of strings")
    if names != sorted(names) or len(names) != len(set(names)):
        _fail("index/fixtures", "fixture names must be unique and sorted")
    return [load_fixture(directory / name) for name in names]
