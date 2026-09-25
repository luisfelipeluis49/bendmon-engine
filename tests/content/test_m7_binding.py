from __future__ import annotations

import sys
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m7_binding import (DEFAULT_CAPACITY, M7BindingError,
                                OwnedEvolutionContext, bind_m7_content,
                                playable_catalog)
from content.models import (CapacityTier, Encounter, EncounterEntry, EncounterId,
                            EvolutionPredicate, EvolutionRule, ItemId, ItemRecord,
                            ItemReward, LevelMove, LoadedProject,
                            MapId, MoveId, MoveRecord, Project, ProjectId,
                            ShopId, ShopRecord, Species, SpeciesId,
                            SpeciesProgression, AssetId)
from tests.content.test_loader import make_kernel, make_project, write_json
from content.loader import load_project


def project(*, species: tuple[Species, ...] | None = None) -> LoadedProject:
    profile = SpeciesProgression(50, 51, 52, 53, 54, 55, 500, 100, 0)
    fox = Species(SpeciesId("demo:fox"), "Fox", AssetId("demo:fox_sprite"), profile)
    cat = Species(SpeciesId("demo:cat"), "Cat", AssetId("demo:cat_sprite"), profile)
    items = (
        ItemRecord(ItemId("demo:stone"), "Stone", 50, False, 3, 2),
        ItemRecord(ItemId("demo:ball"), "Ball", 100, True, 1, 1),
    )
    encounters = (
        Encounter(EncounterId("demo:night"), (EncounterEntry(SpeciesId("demo:fox"), 7),),
                  (ItemReward(ItemId("demo:stone"), 2),)),
        Encounter(EncounterId("demo:day"), (EncounterEntry(SpeciesId("demo:cat"), 3),)),
    )
    moves = (
        MoveRecord(MoveId("demo:zap"), "Zap", 9000, False, 1, 2, 3,
                   AssetId("demo:animation")),
        MoveRecord(MoveId("demo:hit"), "Hit", None, True, 0, 1, 2,
                   AssetId("demo:animation")),
    )
    return LoadedProject(
        Project(ProjectId("demo:game"), "Game", "unassigned", MapId("demo:start")),
        (), (), species if species is not None else (fox, cat), encounters, (), moves,
        (), (), items, (ShopRecord(ShopId("demo:shop"), "Shop",
                                   (ItemId("demo:ball"), ItemId("demo:stone"))),),
        b"{}", "a" * 64,
    )


class M7BindingTests(unittest.TestCase):
    def test_real_loaded_content_binds_into_m7_catalog(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = make_project(Path(temporary) / "project")
            kernel = make_kernel(Path(temporary))
            catalog_path = root / "data/catalog.json"
            catalog = json.loads(catalog_path.read_text())
            catalog["species"][0]["progression"] = {
                "baseStats": {"hp": 50, "attack": 51, "defense": 52,
                              "specialAttack": 53, "specialDefense": 54,
                              "speed": 55},
                "captureRate": 500, "baseXpYield": 100,
                "baseCurrencyYield": 2,
            }
            write_json(catalog_path, catalog)
            manifest_path = root / "manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest["items"] = ["data/item.json"]
            manifest["shops"] = ["data/shop.json"]
            write_json(manifest_path, manifest)
            write_json(root / "data/item.json", {
                "schemaVersion": "content-0", "id": "demo:capsule",
                "name": "Capsule", "buyPrice": 100,
                "captureMultiplier": {"numerator": 3, "denominator": 2},
            })
            write_json(root / "data/shop.json", {
                "schemaVersion": "content-0", "id": "demo:market",
                "name": "Market", "items": ["demo:capsule"],
            })
            encounter_path = root / "data/encounter.json"
            encounter = json.loads(encounter_path.read_text())
            encounter["itemRewards"] = [{"item": "demo:capsule",
                                         "quantity": 2}]
            write_json(encounter_path, encounter)

            loaded = load_project(root, kernel)
            bound = bind_m7_content(loaded)
            self.assertEqual(bound.content_digest, loaded.content_hash)
            self.assertEqual(bound.species[0].progression.capture_rate, 500)
            self.assertEqual(bound.items[0].capture_multiplier, (3, 2))
            self.assertEqual(bound.encounters[0].item_rewards[0].item_id, 1)
            self.assertEqual(bound.shops[0].item_ids, (1,))

    def test_sorted_ids_descriptors_and_identity_are_deterministic(self) -> None:
        loaded = project()
        first = bind_m7_content(loaded)
        reversed_loaded = LoadedProject(
            loaded.project, loaded.assets, loaded.catalogs,
            tuple(reversed(loaded.species)), tuple(reversed(loaded.encounters)),
            loaded.maps, tuple(reversed(loaded.moves)), loaded.mix_recipes,
            loaded.mix_results, tuple(reversed(loaded.items)), loaded.shops,
            loaded.canonical_json, loaded.content_hash,
        )
        second = bind_m7_content(reversed_loaded)
        self.assertEqual(first, second)
        self.assertEqual(dict(first.species_ids), {"demo:cat": 1, "demo:fox": 2})
        self.assertEqual(dict(first.item_ids), {"demo:ball": 1, "demo:stone": 2})
        self.assertEqual(dict(first.encounter_ids), {"demo:day": 1, "demo:night": 2})
        self.assertEqual(dict(first.move_ids), {"demo:hit": 1, "demo:zap": 2})
        self.assertEqual(first.ruleset_version, "m7-1")
        self.assertEqual(first.content_digest, loaded.content_hash)
        self.assertEqual(first.content_identity, int(loaded.content_hash, 16))
        self.assertEqual(first.capacity_tiers, (DEFAULT_CAPACITY,))
        self.assertEqual(first.items[1].capture_multiplier, (3, 2))
        self.assertEqual(first.encounters[1].entries[0].species_id, 2)
        self.assertEqual(first.encounters[1].item_rewards[0].quantity, 2)
        self.assertEqual(first.shops[0].item_ids, (1, 2))
        with self.assertRaises(TypeError):
            first.species_ids["demo:new"] = 3  # type: ignore[index]

    def test_creator_capacity_tiers_are_preserved(self) -> None:
        loaded = project()
        tier = CapacityTier(8, 5, 2000, 1000, 600, 20_000_000)
        loaded = LoadedProject(
            Project(loaded.project.id, loaded.project.name, loaded.project.ruleset,
                    loaded.project.entry_map, (tier,)),
            loaded.assets, loaded.catalogs, loaded.species, loaded.encounters,
            loaded.maps, loaded.moves, loaded.mix_recipes, loaded.mix_results,
            loaded.items, loaded.shops, loaded.canonical_json, loaded.content_hash,
        )
        self.assertEqual(bind_m7_content(loaded).capacity_tiers, (tier,))

    def test_learning_and_evolution_references_bind_to_engine_ids(self) -> None:
        loaded = project()
        fox, cat = loaded.species
        fox = Species(fox.id, fox.name, fox.sprite, fox.progression,
                      (LevelMove(2, MoveId("demo:zap")),),
                      (EvolutionRule("demo:evolve", cat.id, True,
                                     (EvolutionPredicate("minimumLevel", 2),
                                      EvolutionPredicate("knownMove", "demo:zap"))),))
        loaded = LoadedProject(loaded.project, loaded.assets, loaded.catalogs,
                               (fox, cat), loaded.encounters, loaded.maps,
                               loaded.moves, loaded.mix_recipes, loaded.mix_results,
                               loaded.items, loaded.shops, loaded.canonical_json,
                               loaded.content_hash)
        bound = bind_m7_content(loaded)
        fox_binding = next(row for row in bound.species if row.id == 2)
        self.assertEqual(fox_binding.engine_level_moves, ((2, 2),))
        self.assertEqual(bound.evolution_rule_ids["demo:evolve"], 1)
        self.assertEqual(fox_binding.engine_evolutions[0].target_species, 1)
        self.assertEqual(fox_binding.engine_evolutions[0].predicates,
                         (("minimumLevel", 2), ("knownMove", 2)))
        playable = playable_catalog(
            bound, (OwnedEvolutionContext(77, 2),),
            expected_ruleset_version=bound.ruleset_version,
            expected_content_digest=bound.content_digest,
        )
        self.assertEqual(playable.ruleset, 7)
        self.assertEqual(playable.content_identity, bound.content_identity)
        self.assertEqual(playable.learning[1], (2, ((2, 2),)))
        self.assertEqual(playable.evolution[0].individual_id, 77)
        self.assertEqual(playable.evolution[0].source_species, 2)
        self.assertEqual(playable.evolution[0].targets[0][0], 1)
        self.assertEqual(playable.evolution[0].targets[0][1][0], 50)

    def test_playable_catalog_rejects_unknown_or_duplicate_owners(self) -> None:
        bound = bind_m7_content(project())
        with self.assertRaisesRegex(M7BindingError, "unknown owned species"):
            playable_catalog(
                bound, (OwnedEvolutionContext(77, 999),),
                expected_ruleset_version=bound.ruleset_version,
                expected_content_digest=bound.content_digest,
            )
        with self.assertRaisesRegex(M7BindingError, "duplicate owned individual"):
            playable_catalog(
                bound, (OwnedEvolutionContext(77, 1), OwnedEvolutionContext(77, 2)),
                expected_ruleset_version=bound.ruleset_version,
                expected_content_digest=bound.content_digest,
            )

    def test_playable_catalog_requires_exact_saved_m7_content_identity(self) -> None:
        bound = bind_m7_content(project())
        owners = (OwnedEvolutionContext(77, 1),)
        with self.assertRaisesRegex(M7BindingError, "expected ruleset 'm7-1'"):
            playable_catalog(
                bound, owners, expected_ruleset_version="m6-1",
                expected_content_digest=bound.content_digest,
            )
        with self.assertRaisesRegex(M7BindingError, "content identity mismatch"):
            playable_catalog(
                bound, owners, expected_ruleset_version="m7-1",
                expected_content_digest="b" * 64,
            )

    def test_missing_progression_rejects_only_at_playable_binding(self) -> None:
        legacy = Species(SpeciesId("demo:legacy"), "Legacy", AssetId("demo:sprite"))
        with self.assertRaisesRegex(M7BindingError, "demo:legacy"):
            bind_m7_content(project(species=(legacy,)))


if __name__ == "__main__":
    unittest.main()
