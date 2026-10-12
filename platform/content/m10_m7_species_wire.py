"""Closed numeric wire for M7 species progression and level learning data."""
from __future__ import annotations

from dataclasses import dataclass

from .m7_binding import M7ContentBinding, SpeciesBinding
from .world_limits import MAX_ENTITIES, MAX_TOTAL_REFS, MAX_WIRE_BYTES, MAX_WIRE_TOKENS

MAGIC = 13
VERSION = 2
U32_MAX = 0xFFFFFFFF
STAT_MAX = 1_000_000
LEVEL_MAX = 200
MOVE_MAX = MAX_ENTITIES


class M10M7SpeciesWireError(ValueError):
    """A bound M7 progression catalog cannot be represented by this wire."""


@dataclass(frozen=True, slots=True)
class M10M7SpeciesWire:
    version: int
    tokens: tuple[int, ...]
    text: str


def _uint(value: object, label: str, maximum: int = U32_MAX) -> int:
    if type(value) is not int or not 0 <= value <= maximum:
        raise M10M7SpeciesWireError(f"{label} must be an integer in [0, {maximum}]")
    return value


def _positive_id(value: object, label: str, maximum: int = MAX_ENTITIES) -> int:
    result = _uint(value, label, maximum)
    if result == 0:
        raise M10M7SpeciesWireError(f"{label} must be positive")
    return result


def _species_row(row: SpeciesBinding) -> list[int]:
    if type(row) is not SpeciesBinding or type(row.level_moves) is not tuple:
        raise M10M7SpeciesWireError("binding contains a malformed species progression row")
    progression = row.progression
    values = (progression.base_hp, progression.base_attack, progression.base_defense,
              progression.base_special_attack, progression.base_special_defense,
              progression.base_speed, progression.capture_rate,
              progression.base_xp_yield, progression.base_currency_yield)
    checked = [_uint(value, "species progression value", STAT_MAX) for value in values]
    if (any(not 1 <= value <= 500 for value in checked[:6])
            or not 500 <= checked[6] <= 9_000
            or not 1 <= checked[7] <= 1_000 or checked[8] > 100_000):
        raise M10M7SpeciesWireError(f"species {row.id} has invalid stats or capture rate")
    species_id = _positive_id(row.id, "species id")
    moves = row.engine_level_moves
    if type(moves) is not tuple or len(moves) > MAX_ENTITIES:
        raise M10M7SpeciesWireError(f"species {species_id} has invalid level-move count")
    types = row.combat_types
    if type(types) is not tuple or not 1 <= len(types) <= 2:
        raise M10M7SpeciesWireError(f"species {species_id} has invalid combat type count")
    if any(type(value) is not int or not 0 <= value <= 9 for value in types):
        raise M10M7SpeciesWireError(f"species {species_id} has an invalid combat type")
    if len(set(types)) != len(types):
        raise M10M7SpeciesWireError(f"species {species_id} has duplicate combat types")
    padded_types = (*types, *(0 for _ in range(2 - len(types))))
    out = [species_id, *checked, len(types), *padded_types, len(moves)]
    prior_level = 0
    for pair in moves:
        if type(pair) is not tuple or len(pair) != 2:
            raise M10M7SpeciesWireError(f"species {species_id} has a malformed level move")
        level = _uint(pair[0], "learn level", LEVEL_MAX)
        move_id = _positive_id(pair[1], "move id")
        if level == 0 or level < prior_level:
            raise M10M7SpeciesWireError(f"species {species_id} level moves are not ordered")
        out.extend((level, move_id))
        prior_level = level
    return out


def encode_m10_m7_species(binding: M7ContentBinding) -> M10M7SpeciesWire:
    """Encode species stats, reward/capture progression, and ordered level moves."""
    if type(binding) is not M7ContentBinding or binding.ruleset_version != "m7-1":
        raise M10M7SpeciesWireError("species wire requires a validated m7-1 binding")
    rows = binding.species
    if type(rows) is not tuple or not 1 <= len(rows) <= MAX_ENTITIES:
        raise M10M7SpeciesWireError("species count is outside the supported bounds")
    ids = [_positive_id(row.id, "species id") for row in rows]
    if ids != list(range(1, len(rows) + 1)):
        raise M10M7SpeciesWireError("species IDs must be dense and ordered from 1")
    move_ids = {_positive_id(move.id, "move id") for move in binding.moves}
    if len(move_ids) != len(binding.moves):
        raise M10M7SpeciesWireError("move IDs must be unique")
    if move_ids != set(range(1, len(binding.moves) + 1)):
        raise M10M7SpeciesWireError("move IDs must be dense from 1")
    if len(move_ids) > MAX_ENTITIES:
        raise M10M7SpeciesWireError("move count is outside the supported bounds")
    digest_identity = _uint(binding.content_identity, "content identity", (1 << 256) - 1)
    # M8 uses the first eight digest hex digits as its compact Bend identity.
    tokens = [MAGIC, VERSION, digest_identity >> 224,
              len(rows), len(move_ids)]
    total_refs = 0
    for row in rows:
        record = _species_row(row)
        count = record[13]
        learned_ids = record[15::2]
        if any(move not in move_ids for move in learned_ids):
            raise M10M7SpeciesWireError(f"species {row.id} references an unknown move")
        total_refs += count
        tokens.extend(record)
    if total_refs > MAX_TOTAL_REFS:
        raise M10M7SpeciesWireError("species progression references exceed bounds")
    if len(tokens) > MAX_WIRE_TOKENS:
        raise M10M7SpeciesWireError("numeric wire token count exceeds bounds")
    text = " ".join(map(str, tokens))
    if len(text.encode("ascii")) > MAX_WIRE_BYTES:
        raise M10M7SpeciesWireError("numeric wire bytes exceed bounds")
    return M10M7SpeciesWire(VERSION, tuple(tokens), text)
