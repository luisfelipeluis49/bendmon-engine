"""Frozen playtest boundary for the M10 maker.

The shipping loader can freeze an exact project snapshot today. Starting an
interactive run remains unavailable until the precompiled Bend runtime accepts
content records and canonical commands through a documented host protocol.
This module deliberately does not substitute a Python gameplay simulation.
"""
from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path

from content.loader import ContentError, InfrastructureError, load_project
from content.m8_binding import M8BindingError, bind_m8_content
from content.m10_boot_wire import M10BootWireError, encode_m10_boot
from content.m10_events_wire import M10EventsWireError, encode_m10_events
from content.m10_m7_species_wire import M10M7SpeciesWireError, encode_m10_m7_species
from content.m10_m7_moves_wire import M10M7MovesWireError, encode_m10_m7_moves
from content.m10_dialogue_wire import M10DialogueWireError, encode_m10_dialogue
from content.m10_world_wire import M10WorldWireError, encode_m10_world
from content.models import LoadedProject


class PlaytestError(RuntimeError):
    """A playtest could not be safely prepared or started."""


class PlaytestUnavailable(PlaytestError):
    """No generic, interactive compiled Bend runtime is installed."""


@dataclass(frozen=True, slots=True)
class FrozenPlaytestSnapshot:
    """Validated immutable content identity and explicit deterministic seed."""

    project_root: Path
    canonical_json: bytes
    content_hash: str
    rng_state: tuple[int, int, int, int]
    wait_ticks: int


@dataclass(frozen=True, slots=True)
class RuntimeWires:
    """Exact-identity inert records for one precompiled Bend playtest boot."""

    content_hash: str
    world: str
    events: str
    species: str
    moves: str
    dialogue: str
    boot: str


def freeze_project(project_root: str | Path, *, rng_state: tuple[int, int, int, int],
                   wait_ticks: int) -> FrozenPlaytestSnapshot:
    """Load through the shipping validator with canonical RNG and game pacing."""
    if (type(rng_state) is not tuple or len(rng_state) != 4 or
            any(type(word) is not int or not 0 <= word <= 0xFFFFFFFF
                for word in rng_state) or not any(rng_state)):
        raise PlaytestError("playtest RNG must be four U32 words, not all zero")
    if type(wait_ticks) is not int or wait_ticks not in {30, 60, 120}:
        raise PlaytestError("playtest Wait pacing must be 30, 60, or 120 ticks")
    try:
        loaded = load_project(project_root)
    except Exception as exc:
        # Preserve loader diagnostics for callers while keeping this API's
        # message tied to the project boundary.
        raise PlaytestError(f"project did not pass the shipping content loader: {exc}") from exc
    if type(loaded) is not LoadedProject:
        raise PlaytestError("shipping content loader returned an unexpected project record")
    digest = sha256(loaded.canonical_json).hexdigest()
    if digest != loaded.content_hash:
        raise PlaytestError("validated project content hash does not match its canonical snapshot")
    return FrozenPlaytestSnapshot(Path(project_root).resolve(),
                                  bytes(loaded.canonical_json), digest, rng_state,
                                  wait_ticks)


def prepare_runtime_wires(snapshot: FrozenPlaytestSnapshot) -> RuntimeWires:
    """Bind one unchanged frozen project into closed numeric runtime inputs."""
    if type(snapshot) is not FrozenPlaytestSnapshot:
        raise PlaytestError("runtime wires require a frozen playtest snapshot")
    try:
        loaded = load_project(snapshot.project_root)
    except (ContentError, InfrastructureError, OSError) as exc:
        raise PlaytestError(f"frozen project could not be reloaded: {exc}") from exc
    if (loaded.content_hash != snapshot.content_hash or
            loaded.canonical_json != snapshot.canonical_json):
        raise PlaytestError("frozen project changed before runtime binding")
    try:
        binding = bind_m8_content(loaded, expected_ruleset_version="m8-1",
                                  expected_content_digest=snapshot.content_hash)
        sorted_dialogues = tuple(sorted(loaded.dialogues, key=lambda row: str(row.id)))
        dialogue_ids = {str(row.id): index for index, row in
                        enumerate(sorted_dialogues, 1)}
        npc_dialogues = tuple(
            (binding.map_ids[str(world.id)], npc_id,
             dialogue_ids[str(npc.dialogue)])
            for world in sorted(loaded.maps, key=lambda row: str(row.id))
            for npc_id, npc in enumerate(sorted(world.npcs,
                                               key=lambda row: str(row.id)), 1)
            if npc.dialogue is not None)
        return RuntimeWires(snapshot.content_hash,
                            encode_m10_world(binding).text,
                            encode_m10_events(binding).text,
                            encode_m10_m7_species(binding.m7).text,
                            encode_m10_m7_moves(binding.m7).text,
                            encode_m10_dialogue(binding.content_identity,
                                                sorted_dialogues, dialogue_ids,
                                                npc_dialogues).text,
                            encode_m10_boot(binding, rng_state=snapshot.rng_state,
                                            wait_ticks=snapshot.wait_ticks).text)
    except (M8BindingError, M10WorldWireError, M10EventsWireError,
            M10M7SpeciesWireError, M10M7MovesWireError,
            M10DialogueWireError, M10BootWireError) as exc:
        raise PlaytestError(f"frozen project cannot enter the runtime: {exc}") from exc


def start_playtest(snapshot: FrozenPlaytestSnapshot) -> None:
    """Start the compiled M8/M7 runtime when its generic host protocol exists.

    Existing loaded M9 executables are compiled against fixture-specific
    generated catalogs and have no command input protocol. Running one here
    would falsely imply that it exercised this snapshot.
    """
    if type(snapshot) is not FrozenPlaytestSnapshot:
        raise PlaytestError("playtest requires a frozen validated snapshot")
    actual = sha256(snapshot.canonical_json).hexdigest()
    if actual != snapshot.content_hash:
        raise PlaytestError("frozen snapshot content identity mismatch")
    raise PlaytestUnavailable(
        "interactive playtest is unavailable: the compiled Bend runtime has no "
        "generic validated-content and command-input protocol"
    )
