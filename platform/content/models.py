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


@dataclass(frozen=True, slots=True)
class Asset:
    id: AssetId
    path: str
    media_type: str
    bytes: int
    sha256: str


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


@dataclass(frozen=True, slots=True)
class Catalog:
    id: CatalogId
    species: tuple[Species, ...]


@dataclass(frozen=True, slots=True)
class EncounterEntry:
    species: SpeciesId
    level: int


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
class MapRecord:
    id: MapId
    name: str
    width: int
    height: int
    encounters: tuple[EncounterId, ...]


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
class Project:
    id: ProjectId
    name: str
    ruleset: str
    entry_map: MapId
    capacity_tiers: tuple[CapacityTier, ...] = ()


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
