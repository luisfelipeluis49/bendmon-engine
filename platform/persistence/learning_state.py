"""Exact-identity codec for terminal per-individual learning state."""

from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Any, Iterable

from .canonical_json import CanonicalJSONError, canonical_json
from .battle_replay import M6_RULESET_VERSION
from .save_identity import SaveIdentity, SaveIdentityError, require_exact_identity

MAX_HARMONY_PROGRESS = 40


class LearningStateCodecError(ValueError):
    """Raised when learning data is malformed or bound to another save identity."""


@dataclass(frozen=True, slots=True)
class RecipeHarmony:
    recipe_id: int
    progress: int


@dataclass(frozen=True, slots=True)
class IndividualLearning:
    individual_id: int
    observed_recipe_ids: tuple[int, ...]
    harmony: tuple[RecipeHarmony, ...]


def _uint(value: Any, field: str) -> int:
    if type(value) is not int or value < 0:
        raise LearningStateCodecError(f"{field} must be a non-negative integer")
    return value


def _unique_roster(roster_ids: Iterable[int]) -> tuple[int, ...]:
    try:
        roster = tuple(_uint(item, "individual_id") for item in roster_ids)
    except TypeError as exc:
        raise LearningStateCodecError("roster_ids must be iterable") from exc
    if len(set(roster)) != len(roster):
        raise LearningStateCodecError("duplicate roster individual ID")
    return roster


def _validated_records(
    roster: tuple[int, ...], records: Iterable[IndividualLearning]
) -> tuple[IndividualLearning, ...]:
    try:
        materialized = tuple(records)
    except TypeError as exc:
        raise LearningStateCodecError("learning records must be iterable") from exc
    by_id: dict[int, IndividualLearning] = {}
    roster_set = set(roster)
    for record in materialized:
        if not isinstance(record, IndividualLearning):
            raise LearningStateCodecError("each learning record must be IndividualLearning")
        individual_id = _uint(record.individual_id, "individual_id")
        if individual_id in by_id:
            raise LearningStateCodecError(f"duplicate learning record for individual {individual_id}")
        if individual_id not in roster_set:
            raise LearningStateCodecError(f"learning record for non-roster individual {individual_id}")

        observed = tuple(_uint(item, "observed_recipe_id") for item in record.observed_recipe_ids)
        if len(set(observed)) != len(observed):
            raise LearningStateCodecError(f"duplicate observed recipe for individual {individual_id}")
        if observed != tuple(sorted(observed)):
            raise LearningStateCodecError(f"observed recipes are not canonical for individual {individual_id}")
        harmony = tuple(record.harmony)
        harmony_ids: set[int] = set()
        for entry in harmony:
            if not isinstance(entry, RecipeHarmony):
                raise LearningStateCodecError("each Harmony entry must be RecipeHarmony")
            recipe_id = _uint(entry.recipe_id, "harmony recipe_id")
            progress = _uint(entry.progress, "Harmony progress")
            if progress > MAX_HARMONY_PROGRESS:
                raise LearningStateCodecError(
                    f"Harmony progress for individual {individual_id} exceeds {MAX_HARMONY_PROGRESS}"
                )
            if recipe_id in harmony_ids:
                raise LearningStateCodecError(
                    f"duplicate Harmony recipe for individual {individual_id}"
                )
            harmony_ids.add(recipe_id)
        if not harmony_ids.issubset(set(observed)):
            raise LearningStateCodecError(
                f"Harmony recipe was not observed for individual {individual_id}"
            )
        if tuple(entry.recipe_id for entry in harmony) != tuple(sorted(harmony_ids)):
            raise LearningStateCodecError(f"Harmony recipes are not canonical for individual {individual_id}")
        by_id[individual_id] = IndividualLearning(individual_id, observed, harmony)

    missing = roster_set - by_id.keys()
    if missing:
        raise LearningStateCodecError(f"missing roster learning records: {sorted(missing)}")
    return tuple(by_id[individual_id] for individual_id in roster)


def encode_learning_state(
    identity: SaveIdentity,
    roster_ids: Iterable[int],
    records: Iterable[IndividualLearning],
) -> bytes:
    """Encode all roster members in roster order as canonical UTF-8 JSON."""
    if identity.ruleset_version != M6_RULESET_VERSION:
        raise LearningStateCodecError(
            f"M6 learning state requires ruleset {M6_RULESET_VERSION!r}"
        )
    roster = _unique_roster(roster_ids)
    ordered = _validated_records(roster, records)
    value = {
        "identity": identity.canonical_value(),
        "participants": [
            {
                "harmony": [
                    {"progress": entry.progress, "recipeId": entry.recipe_id}
                    for entry in record.harmony
                ],
                "individualId": record.individual_id,
                "observedRecipeIds": list(record.observed_recipe_ids),
            }
            for record in ordered
        ],
    }
    try:
        return canonical_json(value)
    except CanonicalJSONError as exc:
        raise LearningStateCodecError(str(exc)) from exc


def _no_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise LearningStateCodecError(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def _object(value: Any, fields: set[str], label: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != fields:
        raise LearningStateCodecError(f"{label} must contain exactly {sorted(fields)}")
    return value


def decode_learning_state(
    encoded: bytes,
    expected_identity: SaveIdentity,
    roster_ids: Iterable[int],
) -> tuple[IndividualLearning, ...]:
    """Decode canonical bytes after exact schema, ruleset and content checks."""
    if expected_identity.ruleset_version != M6_RULESET_VERSION:
        raise LearningStateCodecError(
            f"M6 learning state requires ruleset {M6_RULESET_VERSION!r}"
        )
    if type(encoded) is not bytes:
        raise LearningStateCodecError("encoded learning state must be bytes")
    try:
        value = json.loads(
            encoded.decode("utf-8"), object_pairs_hook=_no_duplicate_keys
        )
    except LearningStateCodecError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise LearningStateCodecError("learning state is not valid UTF-8 JSON") from exc
    try:
        if canonical_json(value) != encoded:
            raise LearningStateCodecError("learning state JSON is not canonical")
    except CanonicalJSONError as exc:
        raise LearningStateCodecError(str(exc)) from exc

    root = _object(value, {"identity", "participants"}, "learning envelope")
    identity_value = _object(
        root["identity"],
        {"saveSchemaVersion", "rulesetVersion", "contentDigest"},
        "save identity",
    )
    try:
        actual_identity = SaveIdentity(
            schema_version=identity_value["saveSchemaVersion"],
            ruleset_version=identity_value["rulesetVersion"],
            content_digest=identity_value["contentDigest"],
        )
        require_exact_identity(
            actual_identity,
            expected_ruleset_version=expected_identity.ruleset_version,
            expected_content_digest=expected_identity.content_digest,
        )
    except (SaveIdentityError, TypeError) as exc:
        raise LearningStateCodecError(str(exc)) from exc
    if actual_identity.schema_version != expected_identity.schema_version:
        raise LearningStateCodecError(
            "save schema version mismatch: "
            f"expected {expected_identity.schema_version}, actual {actual_identity.schema_version}"
        )

    if type(root["participants"]) is not list:
        raise LearningStateCodecError("participants must be an array")
    records: list[IndividualLearning] = []
    for item in root["participants"]:
        participant = _object(
            item,
            {"individualId", "observedRecipeIds", "harmony"},
            "participant learning record",
        )
        observed_raw = participant["observedRecipeIds"]
        harmony_raw = participant["harmony"]
        if type(observed_raw) is not list or type(harmony_raw) is not list:
            raise LearningStateCodecError("observations and Harmony must be arrays")
        harmony_entries: list[RecipeHarmony] = []
        for entry in harmony_raw:
            parsed = _object(entry, {"recipeId", "progress"}, "Harmony record")
            harmony_entries.append(RecipeHarmony(parsed["recipeId"], parsed["progress"]))
        records.append(
            IndividualLearning(
                participant["individualId"],
                tuple(observed_raw),
                tuple(harmony_entries),
            )
        )
    roster = _unique_roster(roster_ids)
    return _validated_records(roster, records)


__all__ = [
    "IndividualLearning",
    "LearningStateCodecError",
    "MAX_HARMONY_PROGRESS",
    "RecipeHarmony",
    "decode_learning_state",
    "encode_learning_state",
]
