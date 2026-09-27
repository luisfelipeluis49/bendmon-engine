"""Bounded stable-world save and deterministic command replay boundary."""

from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Any, Callable, Iterable

from .battle_replay import M8_RULESET_VERSION, RNG_VERSION
from .canonical_json import CanonicalJSONError, canonical_json, canonical_sha256
from .save_identity import SaveIdentity, SaveIdentityError, require_exact_identity

WORLD_SAVE_SCHEMA_VERSION = 1
MAX_WORLD_SAVE_BYTES = 65_536
MAX_PERSISTENT_RECORDS = 4_096
MAX_REPLAY_COMMANDS = 10_000
_U32_MAX = 0xFFFFFFFF
_WORLD_COORD_MAX = 524_288


class WorldStateError(ValueError):
    """A world save is malformed, unstable, oversized, or incompatible."""


@dataclass(frozen=True, slots=True)
class WorldSnapshot:
    """Only values required to resume a settled overworld simulation."""

    map_id: int
    x: int
    y: int
    z: int
    region_id: int | None
    weighted_distance: int
    encounter_threshold: int
    safe_distance: int
    rng_state: tuple[int, int, int, int]
    persistent_values: tuple[tuple[int, int], ...]
    persistent_entities: tuple[int, ...] = ()
    pending_encounter: bool = False
    event_active: bool = False
    battle_active: bool = False


def _uint(value: Any, field: str) -> int:
    if type(value) is not int or not 0 <= value <= _U32_MAX:
        raise WorldStateError(f"{field} must be a U32")
    return value


def _stable(snapshot: WorldSnapshot) -> None:
    if type(snapshot) is not WorldSnapshot:
        raise WorldStateError("world state must be a WorldSnapshot")
    for name in ("pending_encounter", "event_active", "battle_active"):
        if type(getattr(snapshot, name)) is not bool:
            raise WorldStateError(f"{name} must be a boolean")
    if snapshot.pending_encounter or snapshot.event_active or snapshot.battle_active:
        raise WorldStateError("world save requires no pending encounter, event, or battle")
    if _uint(snapshot.map_id, "map_id") == 0:
        raise WorldStateError("map_id must be a positive bound map ID")
    for axis in ("x", "y", "z"):
        value = getattr(snapshot, axis)
        if type(value) is not int or not -_WORLD_COORD_MAX <= value <= _WORLD_COORD_MAX:
            raise WorldStateError(
                f"position {axis} must be within -{_WORLD_COORD_MAX}..{_WORLD_COORD_MAX}"
            )
    if snapshot.region_id is not None:
        if _uint(snapshot.region_id, "region_id") == 0:
            raise WorldStateError("region_id must be a positive bound region ID")
    for name in ("weighted_distance", "encounter_threshold", "safe_distance"):
        _uint(getattr(snapshot, name), name)
    if snapshot.region_id is None:
        if (snapshot.weighted_distance, snapshot.encounter_threshold,
                snapshot.safe_distance) != (0, 0, 0):
            raise WorldStateError("an inactive encounter meter must have zero counters")
    else:
        if not 98_304 <= snapshot.encounter_threshold <= 163_840:
            raise WorldStateError("encounter threshold is outside the M8 meter range")
        if snapshot.weighted_distance >= snapshot.encounter_threshold:
            raise WorldStateError("stable encounter meter cannot meet its pending threshold")
        if snapshot.safe_distance > 12_288:
            raise WorldStateError("encounter safe distance exceeds the M8 meter limit")
    rng = snapshot.rng_state
    if (type(rng) is not tuple or len(rng) != 4
            or any(type(word) is not int or not 0 <= word <= _U32_MAX for word in rng)
            or not any(rng)):
        raise WorldStateError("rng_state must contain four U32 words and cannot be all zero")
    values = snapshot.persistent_values
    if type(values) is not tuple or len(values) > MAX_PERSISTENT_RECORDS:
        raise WorldStateError(
            f"persistent_values must contain at most {MAX_PERSISTENT_RECORDS} entries"
        )
    for entry in values:
        if type(entry) is not tuple or len(entry) != 2:
            raise WorldStateError("each persistent value must be a (key, value) pair")
        key, value = entry
        _uint(key, "persistent value key")
        _uint(value, "persistent value value")
    entities = snapshot.persistent_entities
    if type(entities) is not tuple or len(entities) > MAX_PERSISTENT_RECORDS:
        raise WorldStateError(
            f"persistent_entities must contain at most {MAX_PERSISTENT_RECORDS} entries"
        )
    for entity in entities:
        _uint(entity, "persistent entity")


def _value(snapshot: WorldSnapshot) -> dict[str, Any]:
    _stable(snapshot)
    return {
        "encounter": {
            "regionId": snapshot.region_id,
            "safeDistance": snapshot.safe_distance,
            "threshold": snapshot.encounter_threshold,
            "weightedDistance": snapshot.weighted_distance,
        },
        "identity": None,
        "mapId": snapshot.map_id,
        "persistentValues": [[key, value] for key, value in snapshot.persistent_values],
        "persistentEntities": list(snapshot.persistent_entities),
        "position": {"x": snapshot.x, "y": snapshot.y, "z": snapshot.z},
        "rng": {"state": list(snapshot.rng_state), "version": RNG_VERSION},
    }


def encode_world_state(identity: SaveIdentity, snapshot: WorldSnapshot) -> bytes:
    """Encode a stable state under exact m8-1/content identity."""
    if identity.ruleset_version != M8_RULESET_VERSION:
        raise WorldStateError("world saves require ruleset 'm8-1'")
    if identity.schema_version != WORLD_SAVE_SCHEMA_VERSION:
        raise WorldStateError(f"world saves require schema version {WORLD_SAVE_SCHEMA_VERSION}")
    value = _value(snapshot)
    value["identity"] = identity.canonical_value()
    try:
        encoded = canonical_json(value)
    except CanonicalJSONError as exc:
        raise WorldStateError(str(exc)) from exc
    if len(encoded) > MAX_WORLD_SAVE_BYTES:
        raise WorldStateError(f"world save exceeds {MAX_WORLD_SAVE_BYTES} bytes")
    return encoded


def _object(value: Any, fields: set[str], label: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != fields:
        raise WorldStateError(f"{label} must contain exactly {sorted(fields)}")
    return value


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise WorldStateError(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def decode_world_state(encoded: bytes, expected_identity: SaveIdentity) -> WorldSnapshot:
    """Decode canonical, bounded bytes and reject content/ruleset mismatch."""
    if type(encoded) is not bytes:
        raise WorldStateError("encoded world save must be bytes")
    if (expected_identity.ruleset_version != M8_RULESET_VERSION
            or expected_identity.schema_version != WORLD_SAVE_SCHEMA_VERSION):
        raise WorldStateError("expected identity must use m8-1 and world save schema version 1")
    if len(encoded) > MAX_WORLD_SAVE_BYTES:
        raise WorldStateError(f"world save exceeds {MAX_WORLD_SAVE_BYTES} bytes")
    try:
        value = json.loads(encoded.decode("utf-8"), object_pairs_hook=_pairs)
        if canonical_json(value) != encoded:
            raise WorldStateError("world save JSON is not canonical")
    except WorldStateError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError, CanonicalJSONError) as exc:
        raise WorldStateError("world save is not valid canonical UTF-8 JSON") from exc
    root = _object(value, {"encounter", "identity", "mapId", "persistentValues",
                           "persistentEntities", "position", "rng"}, "world save")
    identity_value = _object(root["identity"], {"saveSchemaVersion", "rulesetVersion", "contentDigest"}, "save identity")
    try:
        actual = SaveIdentity(identity_value["saveSchemaVersion"], identity_value["rulesetVersion"], identity_value["contentDigest"])
        require_exact_identity(actual, expected_ruleset_version=M8_RULESET_VERSION,
                               expected_content_digest=expected_identity.content_digest)
    except (SaveIdentityError, TypeError) as exc:
        raise WorldStateError(str(exc)) from exc
    if actual.schema_version != expected_identity.schema_version:
        raise WorldStateError("save schema version mismatch")
    encounter = _object(root["encounter"], {"regionId", "safeDistance", "threshold", "weightedDistance"}, "encounter meter")
    position = _object(root["position"], {"x", "y", "z"}, "position")
    rng = _object(root["rng"], {"state", "version"}, "rng")
    if rng["version"] != RNG_VERSION or type(rng["state"]) is not list:
        raise WorldStateError("RNG version or state is invalid")
    if encounter["regionId"] is not None:
        _uint(encounter["regionId"], "regionId")
    values_raw = root["persistentValues"]
    entities_raw = root["persistentEntities"]
    if type(values_raw) is not list or len(values_raw) > MAX_PERSISTENT_RECORDS:
        raise WorldStateError("persistentValues is not a bounded array")
    if type(entities_raw) is not list or len(entities_raw) > MAX_PERSISTENT_RECORDS:
        raise WorldStateError("persistentEntities is not a bounded array")
    values = tuple(tuple(pair) if type(pair) is list else pair
                   for pair in values_raw)
    snapshot = WorldSnapshot(
        _uint(root["mapId"], "mapId"), position["x"], position["y"], position["z"],
        encounter["regionId"], _uint(encounter["weightedDistance"], "weightedDistance"),
        _uint(encounter["threshold"], "threshold"), _uint(encounter["safeDistance"], "safeDistance"),
        tuple(rng["state"]), values, tuple(entities_raw),
    )
    _stable(snapshot)
    return snapshot


def replay_world_commands(
    initial: WorldSnapshot,
    commands: Iterable[Any],
    step: Callable[[WorldSnapshot, Any], WorldSnapshot],
) -> tuple[WorldSnapshot, tuple[str, ...]]:
    """Apply canonical command values and return a state digest per step."""
    _stable(initial)
    try:
        commands = tuple(commands)
    except TypeError as exc:
        raise WorldStateError("commands must be iterable") from exc
    if len(commands) > MAX_REPLAY_COMMANDS:
        raise WorldStateError(f"replay exceeds {MAX_REPLAY_COMMANDS} commands")
    state = initial
    digests: list[str] = []
    replay_bytes = 0
    for index, command in enumerate(commands):
        try:
            replay_bytes += len(canonical_json(command))
        except CanonicalJSONError as exc:
            raise WorldStateError(f"command {index} is not canonical JSON data: {exc}") from exc
        if replay_bytes > MAX_WORLD_SAVE_BYTES:
            raise WorldStateError(f"replay command data exceeds {MAX_WORLD_SAVE_BYTES} bytes")
        state = step(state, command)
        _stable(state)
        digests.append(canonical_sha256(_value(state)))
    return state, tuple(digests)


__all__ = ["MAX_REPLAY_COMMANDS", "MAX_WORLD_SAVE_BYTES", "WORLD_SAVE_SCHEMA_VERSION",
           "WorldSnapshot", "WorldStateError", "decode_world_state", "encode_world_state",
           "replay_world_commands"]
