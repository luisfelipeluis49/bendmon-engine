"""Immutable host-side records for the Content-0 contract."""
from __future__ import annotations

from dataclasses import dataclass
from typing import NewType

ProjectId = NewType("ProjectId", str)
CatalogId = NewType("CatalogId", str)
SpeciesId = NewType("SpeciesId", str)
AssetId = NewType("AssetId", str)
EncounterId = NewType("EncounterId", str)
MapId = NewType("MapId", str)
MoveId = NewType("MoveId", str)
TypeId = NewType("TypeId", int)
RecipeId = NewType("RecipeId", str)
ResultId = NewType("ResultId", str)
ItemId = NewType("ItemId", str)
ShopId = NewType("ShopId", str)
NpcId = NewType("NpcId", str)
TriggerId = NewType("TriggerId", str)
EventId = NewType("EventId", str)
TrainerId = NewType("TrainerId", str)
DialogueId = NewType("DialogueId", str)


@dataclass(frozen=True, slots=True)
class Asset:
    id: AssetId
    path: str
    media_type: str
    bytes: int
    sha256: str


@dataclass(frozen=True, slots=True)
class CameraProfile:
    id: str
    fov_degrees: int
    near_q10: int
    far_q10: int


@dataclass(frozen=True, slots=True)
class AudioBinding:
    signal_kind: int
    asset: AssetId


@dataclass(frozen=True, slots=True)
class MapPresentation:
    camera_profile: str | None = None
    background: AssetId | None = None


@dataclass(frozen=True, slots=True)
class SpeciesProgression:
    base_hp: int
    base_attack: int
    base_defense: int
    base_special_attack: int
    base_special_defense: int
    base_speed: int
    capture_rate: int
    base_xp_yield: int
    base_currency_yield: int


@dataclass(frozen=True, slots=True)
class LevelMove:
    level: int
    move: MoveId


@dataclass(frozen=True, slots=True)
class EvolutionPredicate:
    kind: str
    value: int | str


@dataclass(frozen=True, slots=True)
class EvolutionRule:
    id: str
    target_species: SpeciesId
    automatic: bool
    predicates: tuple[EvolutionPredicate, ...]


@dataclass(frozen=True, slots=True)
class CapacityTier:
    party: int
    moves: int
    storage: int
    item_stack: int
    inventory_entries: int
    currency: int


@dataclass(frozen=True, slots=True)
class ItemRecord:
    id: ItemId
    name: str
    buy_price: int
    unsellable: bool
    capture_multiplier_numerator: int | None
    capture_multiplier_denominator: int | None
    icon: AssetId | None = None


@dataclass(frozen=True, slots=True)
class ShopRecord:
    id: ShopId
    name: str
    items: tuple[ItemId, ...]


@dataclass(frozen=True, slots=True)
class Species:
    id: SpeciesId
    name: str
    sprite: AssetId
    progression: SpeciesProgression | None = None
    level_moves: tuple[LevelMove, ...] = ()
    evolutions: tuple[EvolutionRule, ...] = ()
    combat_types: tuple[TypeId, ...] = (TypeId(0),)


@dataclass(frozen=True, slots=True)
class Catalog:
    id: CatalogId
    species: tuple[Species, ...]


@dataclass(frozen=True, slots=True)
class EncounterEntry:
    species: SpeciesId
    level: int | None = None
    weight: int = 1
    min_level: int = 1
    max_level: int = 200


@dataclass(frozen=True, slots=True)
class ItemReward:
    item: ItemId
    quantity: int


@dataclass(frozen=True, slots=True)
class Encounter:
    id: EncounterId
    entries: tuple[EncounterEntry, ...]
    item_rewards: tuple[ItemReward, ...] = ()


@dataclass(frozen=True, slots=True)
class NavVertex:
    x: int
    y: int
    z: int


@dataclass(frozen=True, slots=True)
class NavTriangle:
    a: int
    b: int
    c: int


@dataclass(frozen=True, slots=True)
class NavLink:
    from_face: int
    to_face: int


@dataclass(frozen=True, slots=True)
class NavSurface:
    vertices: tuple[NavVertex, ...]
    faces: tuple[NavTriangle, ...]
    links: tuple[NavLink, ...]


@dataclass(frozen=True, slots=True)
class NpcRecord:
    id: NpcId
    name: str
    x: int
    y: int
    z: int
    event: EventId | None = None
    sprite: AssetId | None = None
    trainer: TrainerId | None = None
    dialogue: DialogueId | None = None


@dataclass(frozen=True, slots=True)
class TrainerRecord:
    """Inert trainer identity metadata; battle/training behavior is not encoded."""
    id: TrainerId
    name: str


@dataclass(frozen=True, slots=True)
class DialogueLine:
    speaker: str
    text: str


@dataclass(frozen=True, slots=True)
class DialogueRecord:
    """Ordered authored text advanced by the M10 playtest dialogue cursor."""
    id: DialogueId
    lines: tuple[DialogueLine, ...]


@dataclass(frozen=True, slots=True)
class TriggerRecord:
    id: TriggerId
    event: EventId
    vertices: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class EncounterRegion:
    id: str
    encounter: EncounterId
    faces: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class MapTransition:
    id: str
    target_map: MapId
    vertices: tuple[int, ...]
    x: int
    y: int
    z: int


@dataclass(frozen=True, slots=True)
class EventNode:
    id: int
    opcode: str
    arguments: tuple[tuple[str, int], ...]
    next: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class EventGraph:
    id: EventId
    entry: int
    nodes: tuple[EventNode, ...]


@dataclass(frozen=True, slots=True)
class MapRecord:
    id: MapId
    name: str
    width: int
    height: int
    encounters: tuple[EncounterId, ...]
    navigation: NavSurface | None = None
    npcs: tuple[NpcRecord, ...] = ()
    triggers: tuple[TriggerRecord, ...] = ()
    encounter_regions: tuple[EncounterRegion, ...] = ()
    transitions: tuple[MapTransition, ...] = ()
    camera_profile: str | None = None
    presentation: MapPresentation = MapPresentation()


@dataclass(frozen=True, slots=True)
class MoveRecord:
    id: MoveId
    name: str
    accuracy: int | None
    always_hit: bool
    windup: int
    recovery: int
    cooldown: int
    animation: AssetId
    components: tuple[TypeId, ...] | None = None
    power: int | None = None
    damage_category: str = "physical"
    effects: tuple[MoveEffect, ...] = ()
    priority: int = 0


@dataclass(frozen=True, slots=True)
class MoveEffect:
    """Closed inert effect node; kind-specific values are validated at intake."""
    kind: str
    target: str = "target"
    category: str | None = None
    power: int | None = None
    amount: int | None = None
    from_node: int | None = None
    numerator: int | None = None
    denominator: int | None = None
    status: str | None = None
    stat: str | None = None
    direction: str | None = None
    magnitude: int | None = None
    predicate_kind: str | None = None
    predicate_target: str | None = None
    predicate_status: str | None = None
    predicate_node: int | None = None
    then_effects: tuple[MoveEffect, ...] = ()
    else_effects: tuple[MoveEffect, ...] = ()


@dataclass(frozen=True, slots=True)
class MixRecipe:
    id: RecipeId
    source_a: MoveId
    source_b: MoveId
    result: ResultId


@dataclass(frozen=True, slots=True)
class MixResultDescriptor:
    id: ResultId
    name: str
    components: tuple[TypeId, ...]
    power: int
    accuracy: int | None
    always_hit: bool
    windup: int
    recovery: int
    cooldown: int
    animation: AssetId


@dataclass(frozen=True, slots=True)
class EntryPoint:
    x: int
    y: int
    z: int


@dataclass(frozen=True, slots=True)
class BattleStarter:
    species: SpeciesId
    level: int


@dataclass(frozen=True, slots=True)
class Project:
    id: ProjectId
    name: str
    ruleset: str
    entry_map: MapId
    capacity_tiers: tuple[CapacityTier, ...] = ()
    entry_point: EntryPoint | None = None
    starter: BattleStarter | None = None


@dataclass(frozen=True, slots=True)
class LoadedProject:
    project: Project
    assets: tuple[Asset, ...]
    catalogs: tuple[Catalog, ...]
    species: tuple[Species, ...]
    encounters: tuple[Encounter, ...]
    maps: tuple[MapRecord, ...]
    moves: tuple[MoveRecord, ...]
    mix_recipes: tuple[MixRecipe, ...]
    mix_results: tuple[MixResultDescriptor, ...]
    items: tuple[ItemRecord, ...]
    shops: tuple[ShopRecord, ...]
    canonical_json: bytes
    content_hash: str
    events: tuple[EventGraph, ...] = ()
    camera_profiles: tuple[CameraProfile, ...] = ()
    audio_bindings: tuple[AudioBinding, ...] = ()
    trainers: tuple[TrainerRecord, ...] = ()
    dialogues: tuple[DialogueRecord, ...] = ()
