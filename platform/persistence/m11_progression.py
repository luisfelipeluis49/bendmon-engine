"""Bounded canonical value codec for the settled M7 progression payload."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .canonical_json import CanonicalJSONError, canonical_json

MAX_PROGRESS_BYTES = 1_048_576
MAX_RECORDS = 10_000
MAX_PROGRESS_TOKENS = 4_096
M7_WIRE_VERSION = 1
_U32 = 0xFFFFFFFF


class M11ProgressionError(ValueError):
    """A progression payload is malformed, unstable, or outside its bounds."""


def _wire_bool(value: Any, field: str) -> bool:
    if type(value) is not int or value not in (0, 1):
        raise M11ProgressionError(f"{field} must be the integer token 0 or 1")
    return value == 1


@dataclass(frozen=True, slots=True)
class StatBlock:
    hp: int
    attack: int
    defense: int
    special_attack: int
    special_defense: int
    speed: int


@dataclass(frozen=True, slots=True)
class Capacity:
    party: int
    moves: int
    storage: int
    stack: int
    entries: int
    currency: int


@dataclass(frozen=True, slots=True)
class ItemStack:
    item: int
    quantity: int


@dataclass(frozen=True, slots=True)
class Economy:
    capacity: Capacity
    tier: int
    party: int
    storage: int
    equipped_moves: int
    currency: int
    inventory: tuple[ItemStack, ...]


@dataclass(frozen=True, slots=True)
class Roster:
    capacity: Capacity
    party: tuple[int, ...]
    storage: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class MoveHistory:
    kind: str
    move: int | None = None
    offered: int | None = None
    removed: int | None = None


@dataclass(frozen=True, slots=True)
class Individual:
    id: int
    species: int
    level: int
    xp: int
    current_hp: int
    max_hp: int
    ivs: StatBlock
    moves: tuple[int, ...]
    move_history: tuple[MoveHistory, ...]
    observations: tuple[int, ...]
    unlocks: tuple[int, ...]
    harmony: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class OwnedIndividual:
    individual: Individual
    base: StatBlock
    ivs: StatBlock
    alive: bool
    previously_active: bool


@dataclass(frozen=True, slots=True)
class RewardLedger:
    completed_encounters: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class M11Progression:
    economy: Economy
    roster: Roster
    owned: tuple[OwnedIndividual, ...]
    ledger: RewardLedger
    ruleset: int
    content_identity: int


def _uint(value: Any, field: str, maximum: int = _U32) -> int:
    if type(value) is not int or not 0 <= value <= maximum:
        raise M11ProgressionError(f"{field} must be an integer in 0..{maximum}")
    return value


def _obj(value: Any, fields: set[str], field: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != fields:
        raise M11ProgressionError(f"{field} must contain exactly {sorted(fields)}")
    return value


def _array(value: Any, field: str, limit: int = MAX_RECORDS) -> list[Any]:
    if type(value) is not list or len(value) > limit:
        raise M11ProgressionError(f"{field} must be an array of at most {limit} entries")
    return value


def _capacity(value: Any, field: str) -> Capacity:
    row = _obj(value, {"party", "moves", "storage", "stack", "entries", "currency"}, field)
    maxima = (12, 8, 10_000, 9_999, 4_096, 999_999_999)
    vals = [_uint(row[name], f"{field}.{name}", maximum) for name, maximum in zip(
        ("party", "moves", "storage", "stack", "entries", "currency"), maxima)]
    if any(v < 1 for v in vals):
        raise M11ProgressionError(f"{field} capacities must be positive")
    return Capacity(*vals)


def _stats(value: Any, field: str) -> StatBlock:
    names = ("hp", "attack", "defense", "special_attack", "special_defense", "speed")
    row = _obj(value, set(names), field)
    return StatBlock(*(_uint(row[name], f"{field}.{name}") for name in names))


def _history(value: Any) -> tuple[MoveHistory, ...]:
    records = _array(value, "individual.moveHistory", 2_000)
    result: list[MoveHistory] = []
    for index, entry in enumerate(records):
        field = f"individual.moveHistory[{index}]"
        if type(entry) is not dict or type(entry.get("kind")) is not str:
            raise M11ProgressionError(f"{field} must be a move history record")
        kind = entry["kind"]
        if kind in ("learned", "declined"):
            row = _obj(entry, {"kind", "move"}, field)
            result.append(MoveHistory(kind, move=_uint(row["move"], f"{field}.move")))
        elif kind == "replaced":
            row = _obj(entry, {"kind", "offered", "removed"}, field)
            result.append(MoveHistory(kind, offered=_uint(row["offered"], f"{field}.offered"),
                                      removed=_uint(row["removed"], f"{field}.removed")))
        else:
            raise M11ProgressionError(f"{field}.kind is unknown")
    return tuple(result)


def _individual(value: Any) -> Individual:
    names = {"id", "species", "level", "xp", "currentHp", "maxHp", "ivs", "moves",
             "moveHistory", "observations", "unlocks", "harmony"}
    row = _obj(value, names, "individual")
    lists = {name: tuple(_uint(v, f"individual.{name}[{i}]") for i, v in enumerate(
        _array(row[name], f"individual.{name}", 2_000)))
        for name in ("moves", "observations", "unlocks", "harmony")}
    level = _uint(row["level"], "individual.level")
    maximum = _uint(row["maxHp"], "individual.maxHp")
    current = _uint(row["currentHp"], "individual.currentHp")
    if not 1 <= level <= 200 or maximum == 0 or current > maximum:
        raise M11ProgressionError("individual level and HP are outside progression bounds")
    return Individual(_uint(row["id"], "individual.id"), _uint(row["species"], "individual.species"),
                      level, _uint(row["xp"], "individual.xp"), current, maximum,
                      _stats(row["ivs"], "individual.ivs"), lists["moves"],
                      _history(row["moveHistory"]), lists["observations"], lists["unlocks"],
                      lists["harmony"])


def _read(value: Any) -> M11Progression:
    row = _obj(value, {"economy", "roster", "owned", "ledger", "ruleset", "contentIdentity"},
               "progression payload")
    e = _obj(row["economy"], {"capacity", "tier", "party", "storage", "equippedMoves",
                               "currency", "inventory"}, "economy")
    capacity = _capacity(e["capacity"], "economy.capacity")
    inventory = tuple(ItemStack(_uint(_obj(x, {"item", "quantity"}, "inventory item")["item"], "item"),
                                _uint(x["quantity"], "quantity", capacity.stack))
                      for x in _array(e["inventory"], "economy.inventory", capacity.entries))
    item_ids = [stack.item for stack in inventory]
    if len(item_ids) != len(set(item_ids)) or any(s.quantity == 0 for s in inventory):
        raise M11ProgressionError("inventory item IDs must be unique and quantities positive")
    economy = Economy(capacity, _uint(e["tier"], "economy.tier", 15),
                      _uint(e["party"], "economy.party", capacity.party),
                      _uint(e["storage"], "economy.storage", capacity.storage),
                      _uint(e["equippedMoves"], "economy.equippedMoves", capacity.moves),
                      _uint(e["currency"], "economy.currency", capacity.currency), inventory)
    if len(inventory) > capacity.entries:
        raise M11ProgressionError("economy inventory exceeds its entry capacity")
    rr = _obj(row["roster"], {"capacity", "party", "storage"}, "roster")
    roster_capacity = _capacity(rr["capacity"], "roster.capacity")
    party = tuple(_uint(v, "roster.party ID") for v in _array(rr["party"], "roster.party", roster_capacity.party))
    storage = tuple(_uint(v, "roster.storage ID") for v in _array(rr["storage"], "roster.storage", roster_capacity.storage))
    if roster_capacity != capacity or len(set(party + storage)) != len(party + storage):
        raise M11ProgressionError("roster capacity must match economy and roster IDs must be unique")
    if (economy.party != len(party) or economy.storage != len(storage)
            or len(party) > capacity.party or len(storage) > capacity.storage):
        raise M11ProgressionError("economy party/storage counts must match roster membership")
    owned_rows = _array(row["owned"], "owned", roster_capacity.party + roster_capacity.storage)
    owned: list[OwnedIndividual] = []
    for i, item in enumerate(owned_rows):
        o = _obj(item, {"individual", "base", "ivs", "alive", "previouslyActive"}, f"owned[{i}]")
        owned.append(OwnedIndividual(_individual(o["individual"]), _stats(o["base"], f"owned[{i}].base"),
                                     _stats(o["ivs"], f"owned[{i}].ivs"),
                                     _wire_bool(o["alive"], f"owned[{i}].alive"),
                                     _wire_bool(o["previouslyActive"], f"owned[{i}].previouslyActive")))
    owned_ids = [item.individual.id for item in owned]
    if len(set(owned_ids)) != len(owned_ids) or set(owned_ids) != set(party + storage):
        raise M11ProgressionError("owned individuals must match roster membership exactly")
    if any(row.individual.ivs != row.ivs for row in owned):
        raise M11ProgressionError("owned IV inputs must match each individual's stored IVs")
    ledger_value = _obj(row["ledger"], {"completedEncounters"}, "ledger")
    ledger = tuple(_uint(v, "ledger encounter ID") for v in _array(
        ledger_value["completedEncounters"], "ledger.completedEncounters", 100_000))
    if len(set(ledger)) != len(ledger):
        raise M11ProgressionError("completed encounter IDs must be unique")
    ruleset = _uint(row["ruleset"], "ruleset")
    if ruleset != 7:
        raise M11ProgressionError("progression payload requires ruleset 7")
    return M11Progression(economy, Roster(roster_capacity, party, storage), tuple(owned), RewardLedger(ledger),
                          ruleset, _uint(row["contentIdentity"], "contentIdentity"))


def _value(state: M11Progression) -> dict[str, Any]:
    if type(state) is not M11Progression:
        raise M11ProgressionError("state must be an M11Progression")
    def stats(v: StatBlock) -> dict[str, int]:
        return {name: getattr(v, name) for name in ("hp", "attack", "defense", "special_attack", "special_defense", "speed")}
    def cap(v: Capacity) -> dict[str, int]:
        return {name: getattr(v, name) for name in ("party", "moves", "storage", "stack", "entries", "currency")}
    def individual(v: Individual) -> dict[str, Any]:
        history = []
        for h in v.move_history:
            if h.kind in ("learned", "declined"):
                history.append({"kind": h.kind, "move": h.move})
            elif h.kind == "replaced":
                history.append({"kind": h.kind, "offered": h.offered, "removed": h.removed})
            else:
                raise M11ProgressionError("move history kind is unknown")
        return {"id": v.id, "species": v.species, "level": v.level, "xp": v.xp,
                "currentHp": v.current_hp, "maxHp": v.max_hp, "ivs": stats(v.ivs),
                "moves": list(v.moves), "moveHistory": history, "observations": list(v.observations),
                "unlocks": list(v.unlocks), "harmony": list(v.harmony)}
    result = {"economy": {"capacity": cap(state.economy.capacity), "tier": state.economy.tier,
        "party": state.economy.party, "storage": state.economy.storage,
        "equippedMoves": state.economy.equipped_moves, "currency": state.economy.currency,
        "inventory": [{"item": s.item, "quantity": s.quantity} for s in state.economy.inventory]},
        "roster": {"capacity": cap(state.roster.capacity), "party": list(state.roster.party),
                   "storage": list(state.roster.storage)},
        "owned": [{"individual": individual(o.individual), "base": stats(o.base), "ivs": stats(o.ivs),
                   "alive": int(o.alive), "previouslyActive": int(o.previously_active)} for o in state.owned],
        "ledger": {"completedEncounters": list(state.ledger.completed_encounters)},
        "ruleset": state.ruleset, "contentIdentity": state.content_identity}
    if any(type(o.alive) is not bool or type(o.previously_active) is not bool
           for o in state.owned):
        raise M11ProgressionError("owned alive flags must be booleans in typed state")
    _read(result)
    return result


def encode_m11_progression(state: M11Progression) -> dict[str, Any]:
    """Encode validated progression as a canonicalizable JSON value."""
    value = _value(state)
    try:
        if len(canonical_json(value)) > MAX_PROGRESS_BYTES:
            raise M11ProgressionError(f"progression payload exceeds {MAX_PROGRESS_BYTES} bytes")
    except CanonicalJSONError as exc:
        raise M11ProgressionError(str(exc)) from exc
    return value


def decode_m11_progression(value: Any) -> M11Progression:
    """Decode an exact-field JSON value and enforce M7 bounds and membership."""
    try:
        if len(canonical_json(value)) > MAX_PROGRESS_BYTES:
            raise M11ProgressionError(f"progression payload exceeds {MAX_PROGRESS_BYTES} bytes")
        return _read(value)
    except (CanonicalJSONError, RecursionError) as exc:
        raise M11ProgressionError(f"invalid progression JSON value: {exc}") from exc


class _TokenReader:
    """Bounded cursor for the count-prefixed M7 persistent wire v1 format."""

    def __init__(self, tokens: tuple[int, ...]):
        self.tokens = tokens
        self.position = 2

    def take(self, field: str) -> int:
        if self.position >= len(self.tokens):
            raise M11ProgressionError(f"truncated M7 wire at {field}")
        value = self.tokens[self.position]
        self.position += 1
        return value

    def count(self, field: str, maximum: int = MAX_RECORDS) -> int:
        value = self.take(field)
        if value > maximum:
            raise M11ProgressionError(f"{field} exceeds the limit {maximum}")
        return value

    def values(self, field: str, maximum: int = MAX_RECORDS) -> list[int]:
        count = self.count(f"{field} count", maximum)
        if count > len(self.tokens) - self.position:
            raise M11ProgressionError(f"truncated M7 wire in {field}")
        return [self.take(field) for _ in range(count)]

    def capacity(self, field: str) -> dict[str, int]:
        names = ("party", "moves", "storage", "stack", "entries", "currency")
        return {name: self.take(f"{field}.{name}") for name in names}

    def stats(self, field: str) -> dict[str, int]:
        names = ("hp", "attack", "defense", "special_attack", "special_defense", "speed")
        return {name: self.take(f"{field}.{name}") for name in names}

    def individual(self, field: str) -> dict[str, Any]:
        value: dict[str, Any] = {"id": self.take(f"{field}.id"),
            "species": self.take(f"{field}.species"), "level": self.take(f"{field}.level"),
            "xp": self.take(f"{field}.xp"), "currentHp": self.take(f"{field}.currentHp"),
            "maxHp": self.take(f"{field}.maxHp"), "ivs": self.stats(f"{field}.ivs")}
        value["moves"] = self.values(f"{field}.moves", 8)
        history: list[dict[str, int | str]] = []
        for index in range(self.count(f"{field}.moveHistory count", 2_000)):
            tag = self.take(f"{field}.moveHistory[{index}].tag")
            if tag == 0:
                history.append({"kind": "learned", "move": self.take("history learned move")})
            elif tag == 1:
                history.append({"kind": "replaced", "offered": self.take("history offered move"),
                                "removed": self.take("history removed move")})
            elif tag == 2:
                history.append({"kind": "declined", "move": self.take("history declined move")})
            else:
                raise M11ProgressionError(f"unknown M7 move history tag: {tag}")
        value["moveHistory"] = history
        value["observations"] = self.values(f"{field}.observations")
        value["unlocks"] = self.values(f"{field}.unlocks")
        value["harmony"] = self.values(f"{field}.harmony", 2_000)
        return value


def decode_m11_progression_tokens(tokens: Any) -> M11Progression:
    """Decode exact M7 wire v1 tokens, requiring U32 values and full exhaustion."""
    if type(tokens) not in (tuple, list) or len(tokens) < 2:
        raise M11ProgressionError("M7 wire must contain its two-token header")
    if any(type(token) is not int or not 0 <= token <= _U32 for token in tokens[:2]):
        raise M11ProgressionError("M7 wire header tokens must be U32 integers")
    if tokens[0] != M7_WIRE_VERSION:
        raise M11ProgressionError(f"unsupported M7 wire version: {tokens[0]}")
    if tokens[1] != len(tokens) - 2:
        raise M11ProgressionError("M7 wire payload token count does not match input length")
    if tokens[1] > MAX_PROGRESS_TOKENS:
        raise M11ProgressionError(
            f"M7 wire payload exceeds {MAX_PROGRESS_TOKENS} tokens"
        )
    if len(tokens) > MAX_PROGRESS_TOKENS + 2:
        raise M11ProgressionError(
            f"M7 wire must contain at most {MAX_PROGRESS_TOKENS} payload tokens"
        )
    if any(type(token) is not int or not 0 <= token <= _U32 for token in tokens[2:]):
        raise M11ProgressionError("M7 wire payload tokens must be U32 integers")
    reader = _TokenReader(tuple(tokens))
    economy_capacity = reader.capacity("economy.capacity")
    economy = {"capacity": economy_capacity, "tier": reader.take("economy.tier"),
        "party": reader.take("economy.party"), "storage": reader.take("economy.storage"),
        "equippedMoves": reader.take("economy.equippedMoves"),
        "currency": reader.take("economy.currency")}
    inventory = []
    for index in range(reader.count("economy.inventory count", 4_096)):
        inventory.append({"item": reader.take(f"inventory[{index}].item"),
                          "quantity": reader.take(f"inventory[{index}].quantity")})
    economy["inventory"] = inventory
    roster_capacity = reader.capacity("roster.capacity")
    party = reader.values("roster.party", 12)
    storage = reader.values("roster.storage", 10_000)
    owned = []
    for index in range(reader.count("owned count", 10_012)):
        record_count = reader.count(f"owned[{index}] token count", 4_096)
        if record_count > len(reader.tokens) - reader.position:
            raise M11ProgressionError(f"truncated M7 wire in owned[{index}]")
        record_end = reader.position + record_count
        record_tokens = reader.tokens[reader.position:record_end]
        reader.position = record_end
        record = _TokenReader((M7_WIRE_VERSION, len(record_tokens), *record_tokens))
        individual = record.individual(f"owned[{index}].individual")
        base, ivs = record.stats(f"owned[{index}].base"), record.stats(f"owned[{index}].ivs")
        alive, active = record.take("owned.alive"), record.take("owned.previouslyActive")
        if record.position != len(record.tokens):
            raise M11ProgressionError(f"owned[{index}] record contains trailing tokens")
        owned.append({"individual": individual, "base": base, "ivs": ivs,
                      "alive": alive, "previouslyActive": active})
    ledger = reader.values("ledger.completedEncounters", 100_000)
    ruleset, identity = reader.take("ruleset"), reader.take("contentIdentity")
    if reader.position != len(reader.tokens):
        raise M11ProgressionError("M7 wire contains trailing tokens")
    return decode_m11_progression({"economy": economy,
        "roster": {"capacity": roster_capacity, "party": party, "storage": storage},
        "owned": owned, "ledger": {"completedEncounters": ledger},
        "ruleset": ruleset, "contentIdentity": identity})


def encode_m11_progression_tokens(state: M11Progression) -> tuple[int, ...]:
    """Encode typed progression in the exact M7 persistent wire v1 field order."""
    value = _value(state)
    body: list[int] = []

    def capacity(row: dict[str, int]) -> None:
        body.extend(row[name] for name in ("party", "moves", "storage", "stack", "entries", "currency"))

    def stats(row: dict[str, int]) -> None:
        body.extend(row[name] for name in ("hp", "attack", "defense", "special_attack", "special_defense", "speed"))

    def values(rows: list[int]) -> None:
        body.append(len(rows))
        body.extend(rows)

    def individual(row: dict[str, Any]) -> None:
        body.extend(row[name] for name in ("id", "species", "level", "xp", "currentHp", "maxHp"))
        stats(row["ivs"])
        values(row["moves"])
        body.append(len(row["moveHistory"]))
        for record in row["moveHistory"]:
            kind = record["kind"]
            if kind == "learned":
                body.extend((0, record["move"]))
            elif kind == "replaced":
                body.extend((1, record["offered"], record["removed"]))
            else:
                body.extend((2, record["move"]))
        values(row["observations"])
        values(row["unlocks"])
        values(row["harmony"])

    economy = value["economy"]
    capacity(economy["capacity"])
    body.extend(economy[name] for name in ("tier", "party", "storage", "equippedMoves", "currency"))
    body.append(len(economy["inventory"]))
    for item in economy["inventory"]:
        body.extend((item["item"], item["quantity"]))
    roster = value["roster"]
    capacity(roster["capacity"])
    values(roster["party"])
    values(roster["storage"])
    body.append(len(value["owned"]))
    for owned in value["owned"]:
        record_start = len(body)
        individual(owned["individual"])
        stats(owned["base"])
        stats(owned["ivs"])
        body.extend((owned["alive"], owned["previouslyActive"]))
        body[record_start:record_start] = [len(body) - record_start]
    values(value["ledger"]["completedEncounters"])
    body.extend((value["ruleset"], value["contentIdentity"]))
    if len(body) > MAX_PROGRESS_TOKENS or any(type(token) is not int or not 0 <= token <= _U32 for token in body):
        raise M11ProgressionError("encoded M7 progression wire exceeds U32 or token limits")
    return (M7_WIRE_VERSION, len(body), *body)


__all__ = ["Capacity", "Economy", "Individual", "ItemStack", "M11Progression",
           "M11ProgressionError", "MoveHistory", "OwnedIndividual", "RewardLedger",
           "Roster", "StatBlock", "decode_m11_progression", "decode_m11_progression_tokens",
           "encode_m11_progression", "encode_m11_progression_tokens"]
