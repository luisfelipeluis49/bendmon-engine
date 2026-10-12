"""Closed numeric wire for validated Content-0 M7 move descriptors."""
from __future__ import annotations

from dataclasses import dataclass

from .m7_binding import M7ContentBinding
from .models import MoveEffect
from .world_limits import MAX_ENTITIES, MAX_WIRE_BYTES, MAX_WIRE_TOKENS

MAGIC = 15
VERSION = 3


class M10M7MovesWireError(ValueError):
    """A validated move catalog cannot be represented by this wire."""


@dataclass(frozen=True, slots=True)
class M10M7MovesWire:
    version: int
    tokens: tuple[int, ...]
    text: str


def encode_m10_m7_moves(binding: M7ContentBinding) -> M10M7MovesWire:
    """Encode bounded move descriptors and the closed M4 effect algebra."""
    if type(binding) is not M7ContentBinding or binding.ruleset_version != "m7-1":
        raise M10M7MovesWireError("moves wire requires a validated m7-1 binding")
    rows = binding.moves
    if type(rows) is not tuple or len(rows) > MAX_ENTITIES:
        raise M10M7MovesWireError("move count exceeds the supported bounds")
    ids = [row.id for row in rows]
    if ids != list(range(1, len(rows) + 1)):
        raise M10M7MovesWireError("move IDs must be dense and ordered from 1")
    identity = binding.content_identity
    if type(identity) is not int or not 0 <= identity < 1 << 256:
        raise M10M7MovesWireError("content identity is outside the supported bounds")
    tokens = [MAGIC, VERSION, identity >> 224, len(rows)]
    for row in rows:
        power = 0 if row.power is None else row.power
        if type(power) is not int or not 0 <= power <= 200:
            raise M10M7MovesWireError(f"move {row.id} has invalid power")
        if (type(row.windup) is not int or not 0 <= row.windup <= 600
                or type(row.recovery) is not int or not 30 <= row.recovery <= 600
                or type(row.cooldown) is not int or not 60 <= row.cooldown <= 3600):
            raise M10M7MovesWireError(f"move {row.id} has invalid timing")
        if type(row.always_hit) is not bool or (row.always_hit == (row.accuracy is not None)):
            raise M10M7MovesWireError(f"move {row.id} must select exactly one hit mode")
        accuracy = 0 if row.always_hit else row.accuracy
        if type(accuracy) is not int or (not row.always_hit and not 500 <= accuracy <= 10000):
            raise M10M7MovesWireError(f"move {row.id} has invalid accuracy")
        components = () if row.components is None else row.components
        if type(components) is not tuple or len(components) > 4:
            raise M10M7MovesWireError(f"move {row.id} has more than four type components")
        if power > 0 and not components:
            raise M10M7MovesWireError(f"damaging move {row.id} requires type components")
        if any(type(component) is not int or not 0 <= component <= 9 for component in components):
            raise M10M7MovesWireError(f"move {row.id} has an invalid type component")
        if len(set(components)) != len(components):
            raise M10M7MovesWireError(f"move {row.id} has duplicate type components")
        padded = (*components, *(0 for _ in range(4 - len(components))))
        if row.damage_category not in ("physical", "special"):
            raise M10M7MovesWireError(f"move {row.id} has invalid damage category")
        if power == 0 and row.damage_category != "physical":
            raise M10M7MovesWireError(f"move {row.id} cannot classify a non-damaging move")
        category = 0 if row.damage_category == "physical" else 1
        if type(row.priority) is not int or not -8 <= row.priority <= 8:
            raise M10M7MovesWireError(f"move {row.id} has invalid priority")
        if type(row.effects) is not tuple or len(row.effects) > 16:
            raise M10M7MovesWireError(f"move {row.id} has invalid effect program")
        if row.effects and row.power is not None:
            raise M10M7MovesWireError(f"move {row.id} combines explicit effects with legacy power")
        category = 0 if row.damage_category == "physical" else 1
        encoded: list[int] = []

        def target_code(value: str) -> int:
            if value not in ("source", "target"):
                raise M10M7MovesWireError(f"move {row.id} has invalid effect target")
            return 0 if value == "source" else 1

        statuses = {"burn": 0, "poison": 1, "sleep": 2, "stun": 3, "blind": 4}
        stats = {"attack": 0, "defense": 1, "specialAttack": 2,
                 "specialDefense": 3, "speed": 4, "accuracy": 5, "evasion": 6}

        def emit(effect, branch: bool = False) -> None:
            if type(effect) is not MoveEffect:
                raise M10M7MovesWireError(f"move {row.id} has an untyped effect node")
            kinds = {"damage": 0, "heal": 1, "drain": 2, "recoil": 3,
                     "applyStatus": 4, "removeStatus": 5, "clearStatuses": 6,
                     "modifyStat": 7, "conditional": 8}
            kind = kinds.get(effect.kind)
            if kind is None or (branch and kind in (0, 8)):
                raise M10M7MovesWireError(f"move {row.id} has unsupported effect node")
            target = target_code(effect.target) if kind != 8 else 0
            a = b = c = then_count = else_count = 0
            if kind == 0:
                if effect.category not in ("physical", "special") or type(effect.power) is not int or not 1 <= effect.power <= 200:
                    raise M10M7MovesWireError(f"move {row.id} has invalid damage effect")
                a, b = (0 if effect.category == "physical" else 1), effect.power
            elif kind == 1:
                if type(effect.amount) is not int or not 1 <= effect.amount <= 9999:
                    raise M10M7MovesWireError(f"move {row.id} has invalid heal effect")
                a = effect.amount
            elif kind in (2, 3):
                if effect.from_node != 0 or type(effect.numerator) is not int or not 1 <= effect.numerator <= 16 or type(effect.denominator) is not int or not 1 <= effect.denominator <= 16:
                    raise M10M7MovesWireError(f"move {row.id} has invalid damage fraction")
                a, b, c = 0, effect.numerator, effect.denominator
            elif kind in (4, 5):
                if effect.status not in statuses:
                    raise M10M7MovesWireError(f"move {row.id} has invalid status effect")
                a = statuses[effect.status]
            elif kind == 7:
                if effect.stat not in stats or effect.direction not in ("raise", "lower") or type(effect.magnitude) is not int or not 1 <= effect.magnitude <= 6:
                    raise M10M7MovesWireError(f"move {row.id} has invalid stat effect")
                a, b, c = stats[effect.stat], (0 if effect.direction == "raise" else 1), effect.magnitude
            elif kind == 8:
                predicates = {"hpBelowHalf": 0, "hasStatus": 1, "priorDamagePositive": 2}
                a = predicates.get(effect.predicate_kind, -1)
                if a < 0:
                    raise M10M7MovesWireError(f"move {row.id} has invalid condition")
                if a in (0, 1):
                    if effect.predicate_target not in ("source", "target"):
                        raise M10M7MovesWireError(f"move {row.id} has invalid condition target")
                    b = target_code(effect.predicate_target)
                if a == 1:
                    if effect.predicate_status not in statuses:
                        raise M10M7MovesWireError(f"move {row.id} has invalid condition status")
                    c = statuses[effect.predicate_status]
                if a == 2:
                    if effect.predicate_node != 0:
                        raise M10M7MovesWireError(f"move {row.id} has invalid condition damage node")
                    c = 0
                then_count, else_count = len(effect.then_effects), len(effect.else_effects)
                if type(effect.then_effects) is not tuple or type(effect.else_effects) is not tuple:
                    raise M10M7MovesWireError(f"move {row.id} has invalid condition branches")
            encoded.extend((kind, target, a, b, c, then_count, else_count))
            if kind == 8:
                for child in effect.then_effects:
                    emit(child, True)
                for child in effect.else_effects:
                    emit(child, True)

        for effect in row.effects:
            emit(effect)
        node_count = len(encoded) // 7
        if node_count > 16:
            raise M10M7MovesWireError(f"move {row.id} effect node count exceeds 16")
        tokens.extend((row.id, power, int(row.always_hit), accuracy, row.windup,
                       row.recovery, row.cooldown, len(components), *padded, category,
                       row.priority + 8, node_count, *encoded))
    if len(tokens) > MAX_WIRE_TOKENS:
        raise M10M7MovesWireError("move wire token count exceeds bounds")
    text = " ".join(map(str, tokens))
    if len(text.encode("ascii")) > MAX_WIRE_BYTES:
        raise M10M7MovesWireError("move wire bytes exceed bounds")
    return M10M7MovesWire(VERSION, tuple(tokens), text)
