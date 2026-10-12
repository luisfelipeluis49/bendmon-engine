"""Validated geometry records for the existing read-only M9 Canvas renderer."""
from __future__ import annotations

from content.loader import ContentError, InfrastructureError, load_project
from content.m8_binding import (BoundPoint, M8BindingError, SignedCoord,
                                bind_m8_content)
from .playtest import FrozenPlaytestSnapshot, PlaytestError


def _signed(value: SignedCoord) -> int:
    return -value.magnitude if value.negative else value.magnitude


def _point(value: BoundPoint) -> dict[str, int]:
    return {"x": _signed(value.x), "y": _signed(value.y),
            "z": _signed(value.z)}


def presentation_content(snapshot: FrozenPlaytestSnapshot) -> dict[str, object]:
    """Project immutable bound map geometry for M9's browser renderer."""
    if type(snapshot) is not FrozenPlaytestSnapshot:
        raise PlaytestError("presentation content requires a frozen snapshot")
    try:
        loaded = load_project(snapshot.project_root)
    except (ContentError, InfrastructureError, OSError) as exc:
        raise PlaytestError(f"frozen project could not be presented: {exc}") from exc
    if (loaded.content_hash != snapshot.content_hash or
            loaded.canonical_json != snapshot.canonical_json):
        raise PlaytestError("frozen project changed before presentation binding")
    try:
        binding = bind_m8_content(loaded, expected_ruleset_version="m8-1",
                                  expected_content_digest=snapshot.content_hash)
    except M8BindingError as exc:
        raise PlaytestError(f"frozen project cannot be presented: {exc}") from exc
    dialogues = sorted(loaded.dialogues, key=lambda row: str(row.id))
    move_names = {str(row.id): row.name for row in loaded.moves}
    starter_moves: list[dict[str, object]] = []
    if binding.starter_species_id is not None and binding.starter_level is not None:
        starter = next(row for row in binding.m7.species
                       if row.id == binding.starter_species_id)
        learned = tuple(entry for entry in starter.level_moves
                        if entry.level <= binding.starter_level)[-4:]
        for entry in learned:
            move_id = binding.m7.move_ids[str(entry.move)]
            starter_moves.append({"runtimeId": move_id,
                                  "name": move_names[str(entry.move)]})
    return {"contentIdentity": binding.content_identity,
            "maps": [{"runtimeId": row.id,
                      "vertices": [_point(vertex) for vertex in row.vertices],
                      "faces": [list(face) for face in row.faces],
                      "npcs": [{"runtimeId": npc.id} for npc in row.npcs]}
                     for row in binding.maps],
            "dialogues": [{"runtimeId": index,
                           "lines": [{"speaker": line.speaker, "text": line.text}
                                     for line in row.lines]}
                          for index, row in enumerate(dialogues, 1)],
            "starterMoves": starter_moves,
            "assets": {}, "audioBindings": []}
