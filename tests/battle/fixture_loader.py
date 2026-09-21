"""Strict, deterministic loader for the data-only M3 fixture corpus."""

from __future__ import annotations

import json
from pathlib import Path
import re
from typing import Any


FIXTURE_VERSION = "m3-fixtures-1"
TICK_MAX = 216_000
U32_MAX = 2**32 - 1
ACTOR_ID = re.compile(r"^actor-[0-9]{2}$")
SCENARIO_IDS = (
    "barrier-ordering",
    "zero-windup-ordering",
    "invalid-target-fizzle",
    "cancellation",
    "draw",
    "timeout",
    "wait-choices",
    "cooldown-boundaries",
    "escape",
    "reinforcement",
    "switch",
    "active-slots",
    "finite-reinforcements",
    "voluntary-switching",
    "forced-replacement",
    "escape-failure",
    "empty-queue-stall",
    "complete-barrier",
    "simultaneous-readiness",
    "rejection-unchanged",
    "rng-exhaustion",
    "terminal-extra-input",
)

INDEX_FIELDS = {"fixture_version", "scenarios"}
FIXTURE_FIELDS = {
    "fixture_version", "id", "kind", "description", "initial_state",
    "commands", "state_changes_before_execution", "expected",
}
INITIAL_FIELDS = {
    "tick", "ready_actor_ids", "rng_state", "encounter", "active_ids",
    "roster_ids", "party_ids",
}
COMMAND_FIELDS = {
    "actor_id", "choice", "move_id", "target_id", "wait_ticks", "windup",
    "priority", "speed", "action_sequence", "cooldown", "cooldown_deadline",
    "attempt_tick", "fastest_player_speed", "fastest_enemy_speed",
    "prior_failed_escapes", "replacement_id",
}
STATE_CHANGE_FIELDS = {"type", "target_id", "actor_id", "tick"}
EVENT_FIELDS = {
    "type", "actor_ids", "order", "due_tick", "actor_id", "reason", "move_id",
    "deadline", "duration", "count", "effects", "outcome", "chance", "xp",
    "currency", "items", "wait_ticks", "slot", "attempt_tick", "candidate_count",
    "ready_actor_ids", "replacement_id",
}


class FixtureValidationError(ValueError):
    """A stable path-qualified fixture diagnostic."""


def _fail(path: str, message: str) -> None:
    raise FixtureValidationError(f"{path}: {message}")


def _object(value: Any, path: str, fields: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "expected object")
    unknown = sorted(set(value) - fields)
    if unknown:
        _fail(path, f"unknown field(s): {', '.join(unknown)}")
    return value


def _required(value: dict[str, Any], fields: set[str], path: str) -> None:
    missing = sorted(fields - set(value))
    if missing:
        _fail(path, f"missing field(s): {', '.join(missing)}")


def _integer(value: Any, path: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        _fail(path, "expected integer")
    return value


def _string(value: Any, path: str) -> str:
    if not isinstance(value, str):
        _fail(path, "expected string")
    return value


def _actor_id(value: Any, path: str) -> str:
    value = _string(value, path)
    if not ACTOR_ID.fullmatch(value):
        _fail(path, "expected actor-00 style stable ID")
    return value


def _actor_ids(value: Any, path: str, *, sorted_required: bool = False) -> list[str]:
    if not isinstance(value, list):
        _fail(path, "expected array")
    result = [_actor_id(item, f"{path}/{index}") for index, item in enumerate(value)]
    if len(result) != len(set(result)):
        _fail(path, "duplicate stable actor ID")
    if sorted_required and result != sorted(result):
        _fail(path, "stable actor IDs must be sorted")
    return result


def _bounded_tick(value: Any, path: str) -> int:
    value = _integer(value, path)
    if not 0 <= value <= TICK_MAX:
        _fail(path, f"expected integer in [0, {TICK_MAX}]")
    return value


def _rng_state(value: Any, path: str) -> list[int]:
    if not isinstance(value, list) or len(value) != 4:
        _fail(path, "expected exactly four U32 words")
    words = [_integer(item, f"{path}/{index}") for index, item in enumerate(value)]
    if any(word < 0 or word > U32_MAX for word in words):
        _fail(path, f"expected U32 words in [0, {U32_MAX}]")
    if not any(words):
        _fail(path, "all-zero RNG state is forbidden")
    return words


def _json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        _fail(str(path), f"invalid JSON: {error}")


def load_index(fixtures_dir: Path) -> dict[str, Any]:
    """Load and validate the index, including its exact stable scenario order."""
    index = _object(_json(fixtures_dir / "index.json"), "index", INDEX_FIELDS)
    _required(index, INDEX_FIELDS, "index")
    if _string(index["fixture_version"], "index/fixture_version") != FIXTURE_VERSION:
        _fail("index/fixture_version", f"expected {FIXTURE_VERSION!r}")
    scenarios = index["scenarios"]
    if not isinstance(scenarios, list) or any(not isinstance(item, str) for item in scenarios):
        _fail("index/scenarios", "expected an array of strings")
    if scenarios != list(SCENARIO_IDS):
        _fail("index/scenarios", f"expected stable order {list(SCENARIO_IDS)!r}")
    return index


def _validate_fixture(value: Any, path: str, expected_id: str) -> dict[str, Any]:
    fixture = _object(value, path, FIXTURE_FIELDS)
    _required(fixture, {"fixture_version", "id", "kind", "description", "initial_state", "commands", "expected"}, path)
    if _string(fixture["fixture_version"], f"{path}/fixture_version") != FIXTURE_VERSION:
        _fail(f"{path}/fixture_version", f"expected {FIXTURE_VERSION!r}")
    if _string(fixture["id"], f"{path}/id") != expected_id:
        _fail(f"{path}/id", f"expected {expected_id!r}")
    for key in ("kind", "description"):
        if not _string(fixture[key], f"{path}/{key}"):
            _fail(f"{path}/{key}", "must not be empty")

    initial = _object(fixture["initial_state"], f"{path}/initial_state", INITIAL_FIELDS)
    _required(initial, {"tick", "rng_state"}, f"{path}/initial_state")
    _bounded_tick(initial["tick"], f"{path}/initial_state/tick")
    _rng_state(initial["rng_state"], f"{path}/initial_state/rng_state")
    if "ready_actor_ids" in initial:
        _actor_ids(initial["ready_actor_ids"], f"{path}/initial_state/ready_actor_ids", sorted_required=True)
    for key in ("active_ids", "roster_ids", "party_ids"):
        if key in initial:
            _actor_ids(initial[key], f"{path}/initial_state/{key}")

    commands = fixture["commands"]
    if not isinstance(commands, list):
        _fail(f"{path}/commands", "expected array")
    for index, command_value in enumerate(commands):
        command = _object(command_value, f"{path}/commands/{index}", COMMAND_FIELDS)
        _required(command, {"actor_id", "choice"}, f"{path}/commands/{index}")
        _actor_id(command["actor_id"], f"{path}/commands/{index}/actor_id")
        _string(command["choice"], f"{path}/commands/{index}/choice")
        for key in set(command) - {"actor_id", "choice", "move_id", "target_id", "replacement_id"}:
            _integer(command[key], f"{path}/commands/{index}/{key}")
        for key in ("target_id", "replacement_id"):
            if key in command:
                _actor_id(command[key], f"{path}/commands/{index}/{key}")

    if "state_changes_before_execution" in fixture:
        changes = fixture["state_changes_before_execution"]
        if not isinstance(changes, list):
            _fail(f"{path}/state_changes_before_execution", "expected array")
        for index, change_value in enumerate(changes):
            change = _object(change_value, f"{path}/state_changes_before_execution/{index}", STATE_CHANGE_FIELDS)
            _required(change, {"type", "tick"}, f"{path}/state_changes_before_execution/{index}")
            _string(change["type"], f"{path}/state_changes_before_execution/{index}/type")
            _bounded_tick(change["tick"], f"{path}/state_changes_before_execution/{index}/tick")
            for key in ("actor_id", "target_id"):
                if key in change:
                    _actor_id(change[key], f"{path}/state_changes_before_execution/{index}/{key}")

    expected = _object(fixture["expected"], f"{path}/expected", {"result", "rng_draws", "events"})
    _required(expected, {"result", "rng_draws", "events"}, f"{path}/expected")
    _string(expected["result"], f"{path}/expected/result")
    draws = _integer(expected["rng_draws"], f"{path}/expected/rng_draws")
    if draws < 0:
        _fail(f"{path}/expected/rng_draws", "expected nonnegative integer")
    events = expected["events"]
    if not isinstance(events, list) or not events:
        _fail(f"{path}/expected/events", "expected non-empty array")
    for index, event_value in enumerate(events):
        event = _object(event_value, f"{path}/expected/events/{index}", EVENT_FIELDS)
        _required(event, {"type"}, f"{path}/expected/events/{index}")
        _string(event["type"], f"{path}/expected/events/{index}/type")
        for key in set(event) - {"type", "reason", "order", "outcome", "effects", "actor_ids", "ready_actor_ids", "actor_id", "move_id", "replacement_id"}:
            _integer(event[key], f"{path}/expected/events/{index}/{key}")
        for key in ("actor_ids", "ready_actor_ids"):
            if key in event:
                _actor_ids(event[key], f"{path}/expected/events/{index}/{key}")
        for key in ("actor_id", "replacement_id"):
            if key in event:
                _actor_id(event[key], f"{path}/expected/events/{index}/{key}")
    return fixture


def load_corpus(fixtures_dir: Path) -> tuple[dict[str, Any], ...]:
    """Load the complete corpus in canonical index order."""
    index = load_index(fixtures_dir)
    fixtures = tuple(
        _validate_fixture(_json(fixtures_dir / f"{scenario_id}.json"), f"scenario[{scenario_id}]", scenario_id)
        for scenario_id in index["scenarios"]
    )
    actual_files = sorted(path.stem for path in fixtures_dir.glob("*.json") if path.name != "index.json")
    if actual_files != sorted(SCENARIO_IDS):
        _fail("fixtures", f"expected exactly scenario files {list(SCENARIO_IDS)!r}")
    return fixtures
