"""Bounded identity-checked numeric wire for authored dialogue records."""
from __future__ import annotations

from dataclasses import dataclass
from .models import DialogueLine, DialogueRecord
from .world_limits import MAX_ENTITIES, MAX_TOTAL_REFS, MAX_WIRE_BYTES, MAX_WIRE_TOKENS

MAGIC = 16
WIRE_VERSION = 1


class M10DialogueWireError(ValueError):
    """Dialogue records do not fit the supported runtime wire contract."""


@dataclass(frozen=True, slots=True)
class M10DialogueWire:
    version: int
    tokens: tuple[int, ...]
    text: str


def _positive(value: object, name: str, maximum: int = 0xFFFFFFFF) -> int:
    if type(value) is not int or not 1 <= value <= maximum:
        raise M10DialogueWireError(f"{name} must be in [1, {maximum}]")
    return value


def _string_tokens(value: object, label: str, limit: int) -> list[int]:
    if type(value) is not str or not 1 <= len(value) <= limit:
        raise M10DialogueWireError(f"{label} must contain 1..{limit} characters")
    if any(not char.isprintable() or 0xD800 <= ord(char) <= 0xDFFF for char in value):
        raise M10DialogueWireError(f"{label} contains a non-printable character")
    return [len(value), *(ord(char) for char in value)]


def encode_m10_dialogue(identity: int, dialogues: tuple[DialogueRecord, ...],
                        ids: dict[str, int],
                        npc_dialogues: tuple[tuple[int, int, int], ...] = ()) -> M10DialogueWire:
    """Encode dialogue IDs using the binding's canonical dense ID table."""
    if type(identity) is not int or not 0 <= identity <= 0xFFFFFFFF:
        raise M10DialogueWireError("content identity must be in [0, 4294967295]")
    if type(dialogues) is not tuple or type(ids) is not dict or len(dialogues) > MAX_ENTITIES:
        raise M10DialogueWireError("dialogue collection exceeds supported bounds")
    if len(ids) != len(dialogues) or set(ids) != {str(row.id) for row in dialogues}:
        raise M10DialogueWireError("dialogue ID table does not match authored records")
    expected_ids = list(range(1, len(dialogues) + 1))
    if [ids[str(row.id)] for row in dialogues] != expected_ids:
        raise M10DialogueWireError("dialogue IDs must be dense and ordered by authored ID")
    tokens = [MAGIC, WIRE_VERSION, identity, len(dialogues)]
    refs = 0
    seen: set[int] = set()
    for record in dialogues:
        if type(record) is not DialogueRecord or type(record.lines) is not tuple:
            raise M10DialogueWireError("dialogue collection contains a malformed record")
        dialogue_id = _positive(ids[str(record.id)], "dialogue ID", MAX_ENTITIES)
        if dialogue_id in seen or not 1 <= len(record.lines) <= 64:
            raise M10DialogueWireError("dialogue IDs must be unique and contain 1..64 lines")
        seen.add(dialogue_id)
        tokens.extend((dialogue_id, len(record.lines)))
        refs += len(record.lines)
        for line in record.lines:
            if type(line) is not DialogueLine:
                raise M10DialogueWireError("dialogue contains a malformed line")
            tokens.extend(_string_tokens(line.speaker, "speaker", 128))
            tokens.extend(_string_tokens(line.text, "text", 512))
    if type(npc_dialogues) is not tuple or len(npc_dialogues) > MAX_TOTAL_REFS:
        raise M10DialogueWireError("NPC dialogue association count exceeds bounds")
    tokens.append(len(npc_dialogues))
    associations: set[tuple[int, int]] = set()
    for row in npc_dialogues:
        if type(row) is not tuple or len(row) != 3:
            raise M10DialogueWireError("NPC dialogue association must be a map/NPC/dialogue triple")
        map_id = _positive(row[0], "map ID", MAX_ENTITIES)
        npc_id = _positive(row[1], "NPC ID", MAX_ENTITIES)
        dialogue_id = _positive(row[2], "dialogue ID", MAX_ENTITIES)
        if dialogue_id not in seen or (map_id, npc_id) in associations:
            raise M10DialogueWireError("NPC association is duplicate or references missing dialogue")
        associations.add((map_id, npc_id))
        tokens.extend((map_id, npc_id, dialogue_id))
    if refs > MAX_TOTAL_REFS:
        raise M10DialogueWireError("dialogue line total exceeds supported bounds")
    if len(tokens) > MAX_WIRE_TOKENS:
        raise M10DialogueWireError("dialogue wire token count exceeds supported bounds")
    text = " ".join(map(str, tokens))
    if len(text.encode("ascii")) > MAX_WIRE_BYTES:
        raise M10DialogueWireError("dialogue wire bytes exceed supported bounds")
    return M10DialogueWire(WIRE_VERSION, tuple(tokens), text)
