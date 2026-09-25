"""Opt-in, inert binding of validated Content-0 records to M7 runtime IDs.

This module assigns stable IDs and copies approved descriptors only. It does
not interpret creator data as code or supply gameplay formulas.
"""
from __future__ import annotations

from dataclasses import dataclass
from types import MappingProxyType
from typing import Mapping

from .models import (CapacityTier, EvolutionRule, LevelMove, LoadedProject,
                     SpeciesProgression)
from persistence.battle_replay import M7_RULESET_VERSION

DEFAULT_CAPACITY = CapacityTier(6, 4, 1000, 999, 512, 9_999_999)


class M7BindingError(ValueError):
    """Validated inert content cannot be bound at the playable M7 boundary."""


@dataclass(frozen=True, slots=True)
class SpeciesBinding:
    id: int
    progression: SpeciesProgression
    level_moves: tuple[LevelMove, ...]
    evolutions: tuple[EvolutionRule, ...]
    engine_level_moves: tuple[tuple[int, int], ...]
    engine_evolutions: tuple["EngineEvolutionRule", ...]


@dataclass(frozen=True, slots=True)
class EngineEvolutionRule:
    id: int
    target_species: int
    automatic: bool
    predicates: tuple[tuple[str, int], ...]


@dataclass(frozen=True, slots=True)
class ItemBinding:
    id: int
    buy_price: int
    unsellable: bool
    capture_multiplier: tuple[int, int] | None


@dataclass(frozen=True, slots=True)
class EncounterEntryBinding:
    species_id: int
    level: int


@dataclass(frozen=True, slots=True)
class ItemRewardBinding:
    item_id: int
    quantity: int


@dataclass(frozen=True, slots=True)
class EncounterBinding:
    id: int
    entries: tuple[EncounterEntryBinding, ...]
    item_rewards: tuple[ItemRewardBinding, ...]


@dataclass(frozen=True, slots=True)
class MoveBinding:
    id: int


@dataclass(frozen=True, slots=True)
class ShopBinding:
    id: str
    item_ids: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class M7ContentBinding:
    ruleset_version: str
    content_digest: str
    content_identity: int
    species_ids: Mapping[str, int]
    item_ids: Mapping[str, int]
    encounter_ids: Mapping[str, int]
    move_ids: Mapping[str, int]
    evolution_rule_ids: Mapping[str, int]
    flag_ids: Mapping[str, int]
    time_profile_ids: Mapping[str, int]
    recipe_ids: Mapping[str, int]
    species: tuple[SpeciesBinding, ...]
    items: tuple[ItemBinding, ...]
    encounters: tuple[EncounterBinding, ...]
    moves: tuple[MoveBinding, ...]
    shops: tuple[ShopBinding, ...]
    capacity_tiers: tuple[CapacityTier, ...]


@dataclass(frozen=True, slots=True)
class OwnedEvolutionContext:
    """Runtime-owned predicate inputs for one saved individual."""

    individual_id: int
    species_id: int
    items: tuple[int, ...] = ()
    flags: tuple[int, ...] = ()
    time_profile: int = 0
    recipes: tuple[int, ...] = ()
    harmony_tier: int = 0


@dataclass(frozen=True, slots=True)
class PlayableEvolutionInput:
    individual_id: int
    source_species: int
    rules: tuple[EngineEvolutionRule, ...]
    targets: tuple[tuple[int, tuple[int, int, int, int, int, int]], ...]
    items: tuple[int, ...]
    flags: tuple[int, ...]
    time_profile: int
    recipes: tuple[int, ...]
    harmony_tier: int


@dataclass(frozen=True, slots=True)
class PlayableCatalog:
    """Frozen numeric inputs for one engine/m7/playable.bend::open encounter."""

    ruleset: int
    content_identity: int
    learning: tuple[tuple[int, tuple[tuple[int, int], ...]], ...]
    evolution: tuple[PlayableEvolutionInput, ...]


def _ids(values: tuple[object, ...]) -> dict[str, int]:
    return {str(value): index for index, value in enumerate(sorted(map(str, values)), 1)}


def playable_catalog(binding: M7ContentBinding,
                     owners: tuple[OwnedEvolutionContext, ...], *,
                     expected_ruleset_version: str,
                     expected_content_digest: str) -> PlayableCatalog:
    """Bind content only when the caller's saved identity matches exactly."""
    if expected_ruleset_version != M7_RULESET_VERSION:
        raise M7BindingError(
            "playable M7 session requires expected ruleset 'm7-1', "
            f"got {expected_ruleset_version!r}"
        )
    if binding.ruleset_version != M7_RULESET_VERSION:
        raise M7BindingError("playable M7 session requires m7-1 content")
    if (type(expected_content_digest) is not str
            or expected_content_digest != binding.content_digest):
        raise M7BindingError(
            "playable content identity mismatch: expected "
            f"{expected_content_digest!r}, bound {binding.content_digest!r}"
        )
    species_by_id = {row.id: row for row in binding.species}
    if len({row.individual_id for row in owners}) != len(owners):
        raise M7BindingError("duplicate owned individual in playable catalog")
    evolution: list[PlayableEvolutionInput] = []
    for owner in owners:
        species = species_by_id.get(owner.species_id)
        if species is None:
            raise M7BindingError("unknown owned species in playable catalog")
        targets = tuple(
            (target.id, (
                target.progression.base_hp,
                target.progression.base_attack,
                target.progression.base_defense,
                target.progression.base_special_attack,
                target.progression.base_special_defense,
                target.progression.base_speed,
            ))
            for target in binding.species
            if any(rule.target_species == target.id
                   for rule in species.engine_evolutions)
        )
        evolution.append(PlayableEvolutionInput(
            owner.individual_id, owner.species_id, species.engine_evolutions, targets,
            owner.items, owner.flags, owner.time_profile,
            owner.recipes, owner.harmony_tier,
        ))
    return PlayableCatalog(
        7, binding.content_identity,
        tuple((row.id, row.engine_level_moves) for row in binding.species),
        tuple(evolution),
    )


def bind_m7_content(loaded: LoadedProject) -> M7ContentBinding:
    """Bind validated content for explicit M7 play; legacy intake stays inert."""
    missing = sorted(str(row.id) for row in loaded.species
                     if row.progression is None)
    if missing:
        raise M7BindingError(
            "M7 playable binding requires species progression: " + ", ".join(missing)
        )

    species_ids = _ids(tuple(row.id for row in loaded.species))
    item_ids = _ids(tuple(row.id for row in loaded.items))
    encounter_ids = _ids(tuple(row.id for row in loaded.encounters))
    move_ids = _ids(tuple(row.id for row in loaded.moves))
    evolution_rule_ids = _ids(tuple(rule.id for row in loaded.species
                                    for rule in row.evolutions))
    flag_ids = _ids(tuple(predicate.value for row in loaded.species
                          for rule in row.evolutions
                          for predicate in rule.predicates
                          if predicate.kind == "requiredFlag"))
    time_profile_ids = _ids(tuple(predicate.value for row in loaded.species
                                  for rule in row.evolutions
                                  for predicate in rule.predicates
                                  if predicate.kind == "timeProfile"))
    recipe_ids = _ids(tuple(predicate.value for row in loaded.species
                            for rule in row.evolutions
                            for predicate in rule.predicates
                            if predicate.kind == "learnedRecipe"))

    def engine_predicate(kind: str, value: int | str) -> tuple[str, int]:
        references = {"requiredItem": item_ids, "requiredFlag": flag_ids,
                      "timeProfile": time_profile_ids, "knownMove": move_ids,
                      "learnedRecipe": recipe_ids}
        return kind, value if isinstance(value, int) else references[kind][value]

    species = tuple(
        SpeciesBinding(species_ids[str(row.id)], row.progression,
                       row.level_moves, row.evolutions,
                       tuple((entry.level, move_ids[str(entry.move)])
                             for entry in row.level_moves),
                       tuple(EngineEvolutionRule(
                           evolution_rule_ids[rule.id],
                           species_ids[str(rule.target_species)],
                           rule.automatic,
                           tuple(engine_predicate(predicate.kind,
                                                  predicate.value)
                                 for predicate in rule.predicates))
                             for rule in row.evolutions))
        for row in sorted(loaded.species, key=lambda row: str(row.id))
    )
    items = tuple(
        ItemBinding(
            item_ids[str(row.id)], row.buy_price, row.unsellable,
            ((row.capture_multiplier_numerator,
              row.capture_multiplier_denominator)
             if row.capture_multiplier_numerator is not None else None),
        )
        for row in sorted(loaded.items, key=lambda row: str(row.id))
    )
    encounters = tuple(
        EncounterBinding(
            encounter_ids[str(row.id)],
            tuple(EncounterEntryBinding(species_ids[str(entry.species)], entry.level)
                  for entry in row.entries),
            tuple(ItemRewardBinding(item_ids[str(reward.item)], reward.quantity)
                  for reward in row.item_rewards),
        )
        for row in sorted(loaded.encounters, key=lambda row: str(row.id))
    )
    moves = tuple(MoveBinding(move_ids[str(row.id)])
                  for row in sorted(loaded.moves, key=lambda row: str(row.id)))
    shops = tuple(
        ShopBinding(str(row.id), tuple(item_ids[str(item)] for item in row.items))
        for row in sorted(loaded.shops, key=lambda row: str(row.id))
    )
    capacities = loaded.project.capacity_tiers or (DEFAULT_CAPACITY,)
    return M7ContentBinding(
        M7_RULESET_VERSION, loaded.content_hash,
        int(loaded.content_hash, 16),
        MappingProxyType(species_ids), MappingProxyType(item_ids),
        MappingProxyType(encounter_ids), MappingProxyType(move_ids),
        MappingProxyType(evolution_rule_ids), MappingProxyType(flag_ids),
        MappingProxyType(time_profile_ids), MappingProxyType(recipe_ids),
        species, items, encounters, moves, shops, tuple(capacities),
    )
