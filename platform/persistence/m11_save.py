"""Bounded M11 stable-world save envelope and explicit M8 schema migration."""

from __future__ import annotations

from dataclasses import dataclass
import json
import re
from typing import Any

from content.m11_command_codec import M10CommandJSONError, validate_m10_command_value

from .battle_replay import M8_RULESET_VERSION
from .canonical_json import CanonicalJSONError, canonical_json, canonical_sha256
from .m11_progression import (
    M11Progression, M11ProgressionError, decode_m11_progression,
    encode_m11_progression,
)
from .save_identity import SaveIdentity
from .world_state import (
    MAX_WORLD_SAVE_BYTES, WORLD_SAVE_SCHEMA_VERSION, WorldSnapshot,
    WorldStateError, decode_world_state, encode_world_state,
)

M11_SAVE_SCHEMA_VERSION = 4
_M11_SAVE_SCHEMA_V2 = 2
_M11_SAVE_SCHEMA_V3 = 3
MAX_M11_SAVE_BYTES = 2_097_152
MAX_ACCEPTED_COMMANDS = 4_096
_DIGEST = re.compile(r"[0-9a-f]{64}\Z")
_IDENTIFIER = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\Z")


class M11SaveError(ValueError):
    """A save envelope is malformed, incompatible, or not a stable snapshot."""


@dataclass(frozen=True, slots=True)
class SaveExpectation:
    ruleset_version: str
    content_digest: str
    project_id: str
    catalog_id: str


@dataclass(frozen=True, slots=True)
class M11Save:
    engine_build: str
    project_id: str
    catalog_id: str
    ruleset_version: str
    content_digest: str
    wait_ticks: int
    snapshot: WorldSnapshot
    initial_rng_state: tuple[int, int, int, int] = (1, 0, 0, 0)
    accepted_commands: tuple[Any, ...] = ()
    # New schema selection is explicit so existing constructors continue to
    # produce byte-for-byte schema-2 envelopes.
    schema_version: int = _M11_SAVE_SCHEMA_V2
    restore_snapshot: WorldSnapshot | None = None
    progression: M11Progression | None = None
    restore_progression: M11Progression | None = None


def _identifier(value: Any, field: str) -> str:
    if type(value) is not str or not _IDENTIFIER.fullmatch(value):
        raise M11SaveError(f"{field} must be a bounded identifier")
    return value


def _expectation(expected: SaveExpectation) -> None:
    if type(expected) is not SaveExpectation:
        raise M11SaveError("expected identity must be a SaveExpectation")
    if expected.ruleset_version != M8_RULESET_VERSION:
        raise M11SaveError("M11 world saves require exact ruleset 'm8-1'")
    if type(expected.content_digest) is not str or not _DIGEST.fullmatch(expected.content_digest):
        raise M11SaveError("content digest must be lowercase SHA-256")
    _identifier(expected.project_id, "project_id")
    _identifier(expected.catalog_id, "catalog_id")


def _payload(snapshot: WorldSnapshot, digest: str) -> dict[str, Any]:
    try:
        legacy = json.loads(encode_world_state(
            SaveIdentity(WORLD_SAVE_SCHEMA_VERSION, M8_RULESET_VERSION, digest), snapshot
        ).decode("utf-8"))
    except (WorldStateError, ValueError) as exc:
        raise M11SaveError(str(exc)) from exc
    return {key: value for key, value in legacy.items() if key != "identity"}


def _decode_payload(payload: Any, digest: str) -> WorldSnapshot:
    if type(payload) is not dict:
        raise M11SaveError("payload must be an object")
    legacy = dict(payload)
    legacy["identity"] = SaveIdentity(
        WORLD_SAVE_SCHEMA_VERSION, M8_RULESET_VERSION, digest
    ).canonical_value()
    try:
        return decode_world_state(canonical_json(legacy), SaveIdentity(
            WORLD_SAVE_SCHEMA_VERSION, M8_RULESET_VERSION, digest
        ))
    except (WorldStateError, CanonicalJSONError, ValueError) as exc:
        raise M11SaveError(f"invalid stable-world payload: {exc}") from exc


def _value(save: M11Save) -> dict[str, Any]:
    if type(save) is not M11Save or save.schema_version not in (
            _M11_SAVE_SCHEMA_V2, _M11_SAVE_SCHEMA_V3, M11_SAVE_SCHEMA_VERSION):
        raise M11SaveError("save must use M11 schema version 2, 3, or 4")
    _identifier(save.engine_build, "engine_build")
    _identifier(save.project_id, "project_id")
    _identifier(save.catalog_id, "catalog_id")
    expected = SaveExpectation(save.ruleset_version, save.content_digest,
                               save.project_id, save.catalog_id)
    _expectation(expected)
    if type(save.wait_ticks) is not int or save.wait_ticks not in (30, 60, 120):
        raise M11SaveError("wait_ticks must be 30, 60, or 120")
    initial_rng = save.initial_rng_state
    if (type(initial_rng) is not tuple or len(initial_rng) != 4
            or any(type(word) is not int or not 0 <= word <= 0xFFFFFFFF for word in initial_rng)
            or not any(initial_rng)):
        raise M11SaveError("initial_rng_state must contain four U32 words and cannot be all zero")
    if type(save.accepted_commands) is not tuple or len(save.accepted_commands) > MAX_ACCEPTED_COMMANDS:
        raise M11SaveError(f"accepted_commands must contain at most {MAX_ACCEPTED_COMMANDS} records")
    try:
        for command in save.accepted_commands:
            validate_m10_command_value(command)
        canonical_json(list(save.accepted_commands))
    except (M10CommandJSONError, CanonicalJSONError, RecursionError, ValueError) as exc:
        raise M11SaveError(f"accepted command log is not canonical JSON data: {exc}") from exc
    payload = {
        "acceptedCommands": list(save.accepted_commands),
        "initialRngState": list(initial_rng),
        "world": _payload(save.snapshot, save.content_digest),
    }
    if save.schema_version == _M11_SAVE_SCHEMA_V2 and save.progression is not None:
        raise M11SaveError("schema-2 saves cannot contain progression state")
    if save.schema_version != M11_SAVE_SCHEMA_VERSION and save.restore_progression is not None:
        raise M11SaveError("restore progression requires schema 4")
    if save.schema_version in (_M11_SAVE_SCHEMA_V3, M11_SAVE_SCHEMA_VERSION):
        progression_value: dict[str, Any] | None = None
        if save.progression is not None:
            if type(save.progression) is not M11Progression:
                raise M11SaveError("progression must be an M11Progression")
            if save.progression.ruleset != 7:
                raise M11SaveError("progression ruleset must be 7")
            expected_identity = int(save.content_digest[:8], 16)
            if save.progression.content_identity != expected_identity:
                raise M11SaveError("progression content identity does not match content digest")
            try:
                progression_value = encode_m11_progression(save.progression)
            except M11ProgressionError as exc:
                raise M11SaveError(f"invalid progression state: {exc}") from exc
        payload["progression"] = progression_value
    if save.schema_version == M11_SAVE_SCHEMA_VERSION:
        restore_progression_value: dict[str, Any] | None = None
        if save.restore_progression is not None:
            if save.restore_snapshot is None:
                raise M11SaveError("restore progression requires a restore snapshot")
            if type(save.restore_progression) is not M11Progression:
                raise M11SaveError("restore progression must be an M11Progression")
            if (save.restore_progression.ruleset != 7 or
                    save.restore_progression.content_identity != int(save.content_digest[:8], 16)):
                raise M11SaveError("restore progression identity does not match content digest")
            try:
                restore_progression_value = encode_m11_progression(save.restore_progression)
            except M11ProgressionError as exc:
                raise M11SaveError(f"invalid restore progression state: {exc}") from exc
        payload["restoreProgression"] = restore_progression_value
    if save.restore_snapshot is not None:
        if save.restore_snapshot.rng_state != initial_rng:
            raise M11SaveError("restore snapshot RNG must equal initial RNG state")
        payload["restoreWorld"] = _payload(save.restore_snapshot, save.content_digest)
    return {
        "catalogId": save.catalog_id,
        "contentDigest": save.content_digest,
        "engineBuild": save.engine_build,
        "payload": payload,
        "payloadDigest": canonical_sha256(payload),
        "projectId": save.project_id,
        "rng": payload["world"]["rng"],
        "rulesetVersion": save.ruleset_version,
        "saveSchemaVersion": save.schema_version,
        "waitTicks": save.wait_ticks,
    }


def encode_m11_save(save: M11Save) -> bytes:
    """Encode a stable M8 world under a bounded canonical integrity envelope."""
    try:
        encoded = canonical_json(_value(save))
    except (CanonicalJSONError, RecursionError, ValueError) as exc:
        raise M11SaveError(str(exc)) from exc
    if len(encoded) > MAX_M11_SAVE_BYTES:
        raise M11SaveError(f"save exceeds {MAX_M11_SAVE_BYTES} bytes")
    return encoded


def _object(value: Any, fields: set[str], label: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != fields:
        raise M11SaveError(f"{label} must contain exactly {sorted(fields)}")
    return value


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise M11SaveError(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def _bounded_tree(root: Any) -> None:
    """Bound decoded JSON work before digest and schema validation."""
    pending = [(root, 0)]
    visited = 0
    while pending:
        value, depth = pending.pop()
        visited += 1
        if visited > 100_000 or depth > 32:
            raise M11SaveError("save JSON exceeds depth or node limit")
        if type(value) is dict:
            pending.extend((child, depth + 1) for child in value.values())
        elif type(value) is list:
            pending.extend((child, depth + 1) for child in value)


def decode_m11_save(encoded: bytes, expected: SaveExpectation) -> M11Save:
    """Verify bounds, canonical bytes, full identity, payload digest and state."""
    _expectation(expected)
    if type(encoded) is not bytes or len(encoded) > MAX_M11_SAVE_BYTES:
        raise M11SaveError(f"encoded save must be bytes no larger than {MAX_M11_SAVE_BYTES}")
    try:
        root = json.loads(encoded.decode("utf-8"), object_pairs_hook=_pairs)
        _bounded_tree(root)
        if canonical_json(root) != encoded:
            raise M11SaveError("save JSON is not canonical")
    except M11SaveError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError, CanonicalJSONError,
            RecursionError, ValueError) as exc:
        raise M11SaveError("save is not valid canonical UTF-8 JSON") from exc
    root = _object(root, {"catalogId", "contentDigest", "engineBuild", "payload",
                          "payloadDigest", "projectId", "rng", "rulesetVersion",
                          "saveSchemaVersion", "waitTicks"},
                   "save envelope")
    schema_version = root["saveSchemaVersion"]
    if type(schema_version) is not int or schema_version not in (
            _M11_SAVE_SCHEMA_V2, _M11_SAVE_SCHEMA_V3, M11_SAVE_SCHEMA_VERSION):
        raise M11SaveError(f"unsupported save schema version: {root['saveSchemaVersion']!r}")
    if root["rulesetVersion"] != expected.ruleset_version:
        raise M11SaveError(f"ruleset version mismatch: expected {expected.ruleset_version!r}, actual {root['rulesetVersion']!r}")
    if root["contentDigest"] != expected.content_digest:
        raise M11SaveError(f"content identity mismatch: expected {expected.content_digest!r}, actual {root['contentDigest']!r}")
    for key, want in (("projectId", expected.project_id), ("catalogId", expected.catalog_id)):
        _identifier(root[key], key)
        if root[key] != want:
            raise M11SaveError(f"{key} mismatch: expected {want!r}, actual {root[key]!r}")
    build = _identifier(root["engineBuild"], "engineBuild")
    if type(root["waitTicks"]) is not int or root["waitTicks"] not in (30, 60, 120):
        raise M11SaveError("waitTicks must be 30, 60, or 120")
    if type(root["payloadDigest"]) is not str or not _DIGEST.fullmatch(root["payloadDigest"]):
        raise M11SaveError("payloadDigest must be lowercase SHA-256")
    if canonical_sha256(root["payload"]) != root["payloadDigest"]:
        raise M11SaveError("payload integrity digest mismatch")
    fields = {"acceptedCommands", "initialRngState", "world"}
    if schema_version in (_M11_SAVE_SCHEMA_V3, M11_SAVE_SCHEMA_VERSION):
        fields.add("progression")
    if schema_version == M11_SAVE_SCHEMA_VERSION:
        fields.add("restoreProgression")
    if type(root["payload"]) is dict and "restoreWorld" in root["payload"]:
        fields.add("restoreWorld")
    payload = _object(root["payload"], fields, "save payload")
    accepted = payload["acceptedCommands"]
    if type(accepted) is not list or len(accepted) > MAX_ACCEPTED_COMMANDS:
        raise M11SaveError(f"acceptedCommands must be an array of at most {MAX_ACCEPTED_COMMANDS} records")
    try:
        for command in accepted:
            validate_m10_command_value(command)
        canonical_json(accepted)
    except (M10CommandJSONError, CanonicalJSONError, RecursionError, ValueError) as exc:
        raise M11SaveError(f"accepted command log is not canonical JSON data: {exc}") from exc
    initial_rng = payload["initialRngState"]
    if (type(initial_rng) is not list or len(initial_rng) != 4
            or any(type(word) is not int or not 0 <= word <= 0xFFFFFFFF for word in initial_rng)
            or not any(initial_rng)):
        raise M11SaveError("initialRngState must contain four U32 words and cannot be all zero")
    snapshot = _decode_payload(payload["world"], expected.content_digest)
    progression: M11Progression | None = None
    if (schema_version in (_M11_SAVE_SCHEMA_V3, M11_SAVE_SCHEMA_VERSION)
            and payload["progression"] is not None):
        try:
            progression = decode_m11_progression(payload["progression"])
        except M11ProgressionError as exc:
            raise M11SaveError(f"invalid progression payload: {exc}") from exc
        if progression.ruleset != 7:
            raise M11SaveError("progression ruleset must be 7")
        if progression.content_identity != int(expected.content_digest[:8], 16):
            raise M11SaveError("progression content identity does not match content digest")
    restore_snapshot = (_decode_payload(payload["restoreWorld"], expected.content_digest)
                        if "restoreWorld" in payload else None)
    if restore_snapshot is not None and restore_snapshot.rng_state != tuple(initial_rng):
        raise M11SaveError("restore snapshot RNG must equal initial RNG state")
    if root["rng"] != payload["world"].get("rng"):
        raise M11SaveError("envelope RNG state does not match payload")
    restore_progression: M11Progression | None = None
    if schema_version == M11_SAVE_SCHEMA_VERSION and payload["restoreProgression"] is not None:
        if restore_snapshot is None:
            raise M11SaveError("restore progression requires a restore snapshot")
        try:
            restore_progression = decode_m11_progression(payload["restoreProgression"])
        except M11ProgressionError as exc:
            raise M11SaveError(f"invalid restore progression payload: {exc}") from exc
        if (restore_progression.ruleset != 7 or
                restore_progression.content_identity != int(expected.content_digest[:8], 16)):
            raise M11SaveError("restore progression content identity does not match content digest")
    return M11Save(build, expected.project_id, expected.catalog_id,
                   expected.ruleset_version, expected.content_digest,
                   root["waitTicks"], snapshot, tuple(initial_rng),
                   tuple(accepted), schema_version=schema_version,
                   restore_snapshot=restore_snapshot, progression=progression,
                   restore_progression=restore_progression)


def migrate_m8_v1_to_v2(
    encoded: bytes, expected: SaveExpectation, *, engine_build: str,
    wait_ticks: int,
) -> M11Save:
    """Explicitly migrate the M8 world schema 1 snapshot without changing identity."""
    _expectation(expected)
    if type(encoded) is not bytes or len(encoded) > MAX_WORLD_SAVE_BYTES:
        raise M11SaveError(f"legacy save must be bytes no larger than {MAX_WORLD_SAVE_BYTES}")
    try:
        snapshot = decode_world_state(encoded, SaveIdentity(
            WORLD_SAVE_SCHEMA_VERSION, expected.ruleset_version, expected.content_digest
        ))
    except (WorldStateError, ValueError) as exc:
        raise M11SaveError(f"M8 schema-1 migration rejected: {exc}") from exc
    if type(wait_ticks) is not int or wait_ticks not in (30, 60, 120):
        raise M11SaveError("wait_ticks must be 30, 60, or 120")
    result = M11Save(_identifier(engine_build, "engine_build"), expected.project_id,
                     expected.catalog_id, expected.ruleset_version,
                     expected.content_digest, wait_ticks, snapshot,
                     snapshot.rng_state, (), restore_snapshot=snapshot)
    encode_m11_save(result)
    return result


__all__ = ["M11_SAVE_SCHEMA_VERSION", "MAX_M11_SAVE_BYTES", "MAX_ACCEPTED_COMMANDS", "M11Save",
           "M11SaveError", "SaveExpectation", "decode_m11_save",
           "encode_m11_save", "migrate_m8_v1_to_v2"]
