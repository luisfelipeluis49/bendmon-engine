from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))
from content.loader import ContentError, InfrastructureError, load_project


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")


def make_project(root: Path) -> Path:
    ppm = b"P6\n1 1\n255\n\x10\x20\x30"
    (root / "assets").mkdir(parents=True)
    (root / "assets/pixel.ppm").write_bytes(ppm)
    write_json(root / "project.json", {"schemaVersion": "content-0", "id": "demo:project", "name": "Demo", "ruleset": "unassigned", "entryMap": "demo:start"})
    write_json(root / "manifest.json", {"schemaVersion": "content-0", "catalogs": ["data/catalog.json"], "maps": ["data/map.json"], "encounters": ["data/encounter.json"], "moves": [], "assets": [{"id": "demo:pixel", "path": "assets/pixel.ppm", "mediaType": "image/x-portable-pixmap", "bytes": len(ppm), "sha256": hashlib.sha256(ppm).hexdigest()}]})
    write_json(root / "data/catalog.json", {"schemaVersion": "content-0", "id": "demo:catalog", "species": [{"id": "demo:fox", "name": "Fox", "sprite": "demo:pixel"}]})
    write_json(root / "data/encounter.json", {"schemaVersion": "content-0", "id": "demo:field", "entries": [{"species": "demo:fox", "level": 1}]})
    write_json(root / "data/map.json", {"schemaVersion": "content-0", "id": "demo:start", "name": "Start", "width": 8, "height": 8, "encounters": ["demo:field"]})
    return root


def make_kernel(root: Path, output: str = "OK\n", status: int = 0) -> Path:
    kernel = root / "kernel"
    stream = "sys.stdout" if status == 0 else "sys.stderr"
    kernel.write_text("#!/usr/bin/env python3\nimport pathlib,sys\nassert sys.argv[1]=='--' and len(sys.argv)==3\np=pathlib.Path(sys.argv[2])\nassert p.is_absolute()\nassert p.read_text().split()[0]=='1'\n" + stream + ".write(" + repr(output) + ")\nsys.exit(" + str(status) + ")\n", encoding="utf-8")
    kernel.chmod(kernel.stat().st_mode | stat.S_IXUSR)
    return kernel


class LoaderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = make_project(Path(self.temp.name) / "project")
        self.kernel = make_kernel(Path(self.temp.name))

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_valid_load_is_immutable_and_calls_kernel(self) -> None:
        loaded = load_project(self.root, self.kernel)
        self.assertEqual(str(loaded.project.id), "demo:project")
        self.assertEqual(hashlib.sha256(loaded.canonical_json).hexdigest(), loaded.content_hash)
        with self.assertRaisesRegex(Exception, "cannot assign"):
            loaded.project.name = "changed"  # type: ignore[misc]

    def test_encounter_level_rejects_values_outside_playable_range(self) -> None:
        path = self.root / "data/encounter.json"
        encounter = json.loads(path.read_text())
        for level in (0, 201):
            with self.subTest(level=level):
                encounter["entries"][0]["level"] = level
                write_json(path, encounter)
                with self.assertRaises(ContentError) as caught:
                    load_project(self.root, self.kernel)
                self.assertEqual(caught.exception.diagnostics[0].pointer,
                                 "/entries/0/level")

    def test_species_progression_is_bounded_and_changes_content_identity(self) -> None:
        original = load_project(self.root, self.kernel).content_hash
        catalog_path = self.root / "data/catalog.json"
        catalog = json.loads(catalog_path.read_text())
        profile = {
            "baseStats": {"hp": 80, "attack": 55, "defense": 40,
                          "specialAttack": 70, "specialDefense": 45,
                          "speed": 65},
            "captureRate": 500, "baseXpYield": 1000,
            "baseCurrencyYield": 0,
        }
        catalog["species"][0]["progression"] = profile
        write_json(catalog_path, catalog)
        loaded = load_project(self.root, self.kernel)
        self.assertNotEqual(original, loaded.content_hash)
        self.assertEqual(loaded.species[0].progression.base_hp, 80)
        self.assertEqual(loaded.species[0].progression.base_xp_yield, 1000)
        self.assertEqual(json.loads(loaded.canonical_json)["catalogs"][0]
                         ["species"][0]["progression"]["captureRate"], 500)
        catalog["species"][0]["progression"] = dict(reversed(list(profile.items())))
        write_json(catalog_path, catalog)
        self.assertEqual(loaded.content_hash, load_project(self.root, self.kernel).content_hash)

        for key, invalid, pointer in (
            ("captureRate", 499, "/species/0/progression/captureRate"),
            ("baseXpYield", 1001, "/species/0/progression/baseXpYield"),
            ("baseCurrencyYield", -1, "/species/0/progression/baseCurrencyYield"),
        ):
            bad = dict(profile, **{key: invalid})
            catalog["species"][0]["progression"] = bad
            write_json(catalog_path, catalog)
            with self.subTest(key=key), self.assertRaises(ContentError) as caught:
                load_project(self.root, self.kernel)
            self.assertEqual(caught.exception.diagnostics[0].pointer, pointer)
        catalog["species"][0]["progression"] = dict(
            profile, baseStats=dict(profile["baseStats"], hp=True))
        write_json(catalog_path, catalog)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer,
                         "/species/0/progression/baseStats/hp")

    def test_capacity_tiers_are_bounded_monotone_and_hashed(self) -> None:
        before = load_project(self.root, self.kernel).content_hash
        path = self.root / "project.json"
        project = json.loads(path.read_text())
        base = {"party": 6, "moves": 4, "storage": 1000,
                "itemStack": 999, "inventoryEntries": 512, "currency": 9999999}
        project["capacityTiers"] = [base, dict(base, party=12, moves=8)]
        write_json(path, project)
        loaded = load_project(self.root, self.kernel)
        self.assertNotEqual(before, loaded.content_hash)
        self.assertEqual(loaded.project.capacity_tiers[1].party, 12)
        project["capacityTiers"][1]["moves"] = 3
        write_json(path, project)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "capacity-tier")
        project["capacityTiers"][1]["moves"] = 9
        write_json(path, project)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer,
                         "/capacityTiers/1/moves")

    def test_capture_item_price_and_exact_multiplier_are_hashed(self) -> None:
        before = load_project(self.root, self.kernel).content_hash
        manifest_path = self.root / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["items"] = ["data/capsule.json"]
        write_json(manifest_path, manifest)
        item_path = self.root / "data/capsule.json"
        item = {"schemaVersion": "content-0", "id": "demo:capsule",
                "name": "Capsule", "buyPrice": 100,
                "icon": "demo:pixel",
                "captureMultiplier": {"numerator": 3, "denominator": 2}}
        write_json(item_path, item)
        loaded = load_project(self.root, self.kernel)
        self.assertNotEqual(before, loaded.content_hash)
        self.assertEqual(loaded.items[0].capture_multiplier_numerator, 3)
        self.assertEqual(loaded.items[0].icon, "demo:pixel")
        item["captureMultiplier"]["numerator"] = 8
        item["captureMultiplier"]["denominator"] = 1
        write_json(item_path, item)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code,
                         "capture-multiplier")
        item["captureMultiplier"] = {"numerator": 1, "denominator": 2}
        item["buyPrice"] = True
        write_json(item_path, item)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/buyPrice")
        item["buyPrice"] = 100
        item["icon"] = "demo:missing"
        write_json(item_path, item)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/icon")

    def test_shop_offers_resolve_items_and_enter_digest(self) -> None:
        item = {"schemaVersion": "content-0", "id": "demo:capsule",
                "name": "Capsule", "buyPrice": 100}
        write_json(self.root / "data/item.json", item)
        shop = {"schemaVersion": "content-0", "id": "demo:market",
                "name": "Market", "items": ["demo:capsule"]}
        write_json(self.root / "data/shop.json", shop)
        manifest_path = self.root / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["items"] = ["data/item.json"]
        manifest["shops"] = ["data/shop.json"]
        write_json(manifest_path, manifest)
        loaded = load_project(self.root, self.kernel)
        self.assertEqual(loaded.shops[0].items, ("demo:capsule",))
        before = loaded.content_hash
        shop["name"] = "New Market"
        write_json(self.root / "data/shop.json", shop)
        self.assertNotEqual(before, load_project(self.root, self.kernel).content_hash)
        shop["items"] = ["demo:missing"]
        write_json(self.root / "data/shop.json", shop)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/items/0")

    def test_level_moves_resolve_and_sort_canonically(self) -> None:
        move = {"schemaVersion": "content-0", "id": "demo:quick",
                "name": "Quick", "alwaysHit": True, "windup": 0,
                "recovery": 30, "cooldown": 60, "animation": "demo:pixel"}
        write_json(self.root / "data/move.json", move)
        manifest_path = self.root / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["moves"] = ["data/move.json"]
        write_json(manifest_path, manifest)
        catalog_path = self.root / "data/catalog.json"
        catalog = json.loads(catalog_path.read_text())
        catalog["species"][0]["levelMoves"] = [
            {"level": 20, "move": "demo:quick"},
            {"level": 5, "move": "demo:quick"},
        ]
        write_json(catalog_path, catalog)
        loaded = load_project(self.root, self.kernel)
        self.assertEqual([entry.level for entry in loaded.species[0].level_moves],
                         [5, 20])
        catalog["species"][0]["levelMoves"].reverse()
        write_json(catalog_path, catalog)
        self.assertEqual(loaded.content_hash,
                         load_project(self.root, self.kernel).content_hash)
        catalog["species"][0]["levelMoves"][0]["move"] = "demo:missing"
        write_json(catalog_path, catalog)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "reference")
    def test_evolution_rules_validate_and_sort_by_rule_id(self) -> None:
        catalog_path = self.root / "data/catalog.json"
        catalog = json.loads(catalog_path.read_text())
        catalog["species"].append({"id": "demo:wolf", "name": "Wolf",
                                   "sprite": "demo:pixel"})
        rules = [
            {"id": "demo:late", "targetSpecies": "demo:wolf",
             "automatic": False,
             "predicates": [{"kind": "minimumLevel", "value": 30}]},
            {"id": "demo:early", "targetSpecies": "demo:wolf",
             "automatic": True,
             "predicates": [{"kind": "minimumLevel", "value": 10}]},
        ]
        catalog["species"][0]["evolutions"] = rules
        write_json(catalog_path, catalog)
        loaded = load_project(self.root, self.kernel)
        self.assertEqual(loaded.species[0].evolutions[0].id, "demo:late")
        canonical_rules = json.loads(loaded.canonical_json)["catalogs"][0]
        self.assertEqual([rule["id"] for rule in canonical_rules["species"][0]
                          ["evolutions"]], ["demo:early", "demo:late"])
        rules.reverse()
        write_json(catalog_path, catalog)
        self.assertEqual(loaded.content_hash,
                         load_project(self.root, self.kernel).content_hash)
        rules[0]["targetSpecies"] = "demo:missing"
        write_json(catalog_path, catalog)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "reference")
        rules[0]["targetSpecies"] = "demo:wolf"
        rules[0]["predicates"] = [
            {"kind": "minimumLevel", "value": 1} for _ in range(5)]
        write_json(catalog_path, catalog)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "limit")
        rules[0]["predicates"] = [
            {"kind": "minimumLevel", "value": 10},
            {"kind": "minimumLevel", "value": 20}]
        write_json(catalog_path, catalog)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "duplicate")

    def test_encounter_item_rewards_are_bounded_and_resolve(self) -> None:
        item = {"schemaVersion": "content-0", "id": "demo:ore",
                "name": "Ore", "buyPrice": 0, "unsellable": True}
        write_json(self.root / "data/item.json", item)
        manifest_path = self.root / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["items"] = ["data/item.json"]
        write_json(manifest_path, manifest)
        encounter_path = self.root / "data/encounter.json"
        encounter = json.loads(encounter_path.read_text())
        encounter["itemRewards"] = [{"item": "demo:ore", "quantity": 1}]
        write_json(encounter_path, encounter)
        loaded = load_project(self.root, self.kernel)
        self.assertEqual(loaded.encounters[0].item_rewards[0].quantity, 1)
        encounter["itemRewards"][0]["quantity"] = 10000
        write_json(encounter_path, encounter)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer,
                         "/itemRewards/0/quantity")
        encounter["itemRewards"][0] = {"item": "demo:missing", "quantity": 1}
        write_json(encounter_path, encounter)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer,
                         "/itemRewards/0/item")

    def test_authored_move_timing_accuracy_and_animation_reference(self) -> None:
        move = {"schemaVersion": "content-0", "id": "demo:quick", "name": "Quick",
                "accuracy": 500, "windup": 0, "recovery": 30, "cooldown": 60,
                "animation": "demo:pixel"}
        write_json(self.root / "data/move.json", move)
        manifest = json.loads((self.root / "manifest.json").read_text())
        manifest["moves"] = ["data/move.json"]
        write_json(self.root / "manifest.json", manifest)
        loaded = load_project(self.root, self.kernel)
        self.assertEqual(loaded.moves[0].accuracy, 500)
        self.assertEqual((loaded.moves[0].windup, loaded.moves[0].recovery,
                          loaded.moves[0].cooldown), (0, 30, 60))

    def test_move_ranges_always_hit_and_animation_reference_are_checked(self) -> None:
        move = {"schemaVersion": "content-0", "id": "demo:quick", "name": "Quick",
                "alwaysHit": True, "windup": 601, "recovery": 30, "cooldown": 60,
                "animation": "demo:missing"}
        write_json(self.root / "data/move.json", move)
        manifest = json.loads((self.root / "manifest.json").read_text())
        manifest["moves"] = ["data/move.json"]
        write_json(self.root / "manifest.json", manifest)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/windup")
        move["windup"] = 0
        write_json(self.root / "data/move.json", move)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/animation")

    def test_move_shape_and_accuracy_mode_reject_as_content_errors(self) -> None:
        manifest = json.loads((self.root / "manifest.json").read_text())
        manifest["moves"] = ["data/move.json"]
        write_json(self.root / "manifest.json", manifest)
        write_json(self.root / "data/move.json", 7)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "shape")
        write_json(self.root / "data/move.json", {
            "schemaVersion": "content-0", "id": "demo:quick", "name": "Quick",
            "windup": 0, "recovery": 30, "cooldown": 60,
            "animation": "demo:pixel",
        })
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "accuracy-mode")

    def test_authored_mix_recipe_validates_unordered_base_pair_and_result(self) -> None:
        base = {"schemaVersion": "content-0", "name": "Base", "accuracy": 9000,
                "windup": 0, "recovery": 30, "cooldown": 60,
                "animation": "demo:pixel", "components": [2]}
        result = {"schemaVersion": "content-0", "id": "demo:result", "name": "Result",
                  "components": [1, 4], "power": 200, "accuracy": 8500,
                  "windup": 30, "recovery": 60, "cooldown": 90,
                  "animation": "demo:pixel"}
        recipe = {"schemaVersion": "content-0", "id": "demo:recipe",
                  "sourceA": "demo:a", "sourceB": "demo:b", "result": "demo:result"}
        for file, value in [("a.json", dict(base, id="demo:a")),
                            ("b.json", dict(base, id="demo:b")),
                            ("result.json", result), ("recipe.json", recipe)]:
            write_json(self.root / "data" / file, value)
        manifest = json.loads((self.root / "manifest.json").read_text())
        manifest.update(moves=["data/a.json", "data/b.json"],
                        mixRecipes=["data/recipe.json"], mixResults=["data/result.json"])
        write_json(self.root / "manifest.json", manifest)
        loaded = load_project(self.root, self.kernel)
        self.assertEqual(loaded.mix_recipes[0].source_a, "demo:a")
        self.assertEqual(loaded.mix_results[0].components, (1, 4))
        self.assertEqual(json.loads(loaded.canonical_json)["mixResults"][0]["power"], 200)

    def test_mix_pair_is_unordered_and_sources_need_single_component(self) -> None:
        base = {"schemaVersion": "content-0", "name": "Base", "accuracy": 9000,
                "windup": 0, "recovery": 30, "cooldown": 60,
                "animation": "demo:pixel", "components": [2]}
        result = {"schemaVersion": "content-0", "id": "demo:result", "name": "Result",
                  "components": [1], "power": 1, "alwaysHit": True,
                  "windup": 0, "recovery": 30, "cooldown": 60,
                  "animation": "demo:pixel"}
        recipe = {"schemaVersion": "content-0", "id": "demo:recipe",
                  "sourceA": "demo:a", "sourceB": "demo:b", "result": "demo:result"}
        for file, value in [("a.json", dict(base, id="demo:a")),
                            ("b.json", dict(base, id="demo:b")),
                            ("result.json", result), ("recipe.json", recipe)]:
            write_json(self.root / "data" / file, value)
        reversed_recipe = dict(recipe, id="demo:reversed", sourceA="demo:b", sourceB="demo:a")
        write_json(self.root / "data/reversed.json", reversed_recipe)
        manifest = json.loads((self.root / "manifest.json").read_text())
        manifest.update(moves=["data/a.json", "data/b.json"],
                        mixRecipes=["data/recipe.json", "data/reversed.json"], mixResults=["data/result.json"])
        write_json(self.root / "manifest.json", manifest)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "duplicate")
        manifest["mixRecipes"] = ["data/recipe.json"]
        write_json(self.root / "manifest.json", manifest)
        write_json(self.root / "data/b.json", dict(base, id="demo:b", components=[2, 3]))
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "mix-source-components")

    def test_mix_recipe_hash_canonicalizes_reversed_source_order(self) -> None:
        base = {"schemaVersion": "content-0", "name": "Base", "accuracy": 9000,
                "windup": 0, "recovery": 30, "cooldown": 60,
                "animation": "demo:pixel", "components": [2]}
        result = {"schemaVersion": "content-0", "id": "demo:result", "name": "Result",
                  "components": [1], "power": 20, "alwaysHit": True,
                  "windup": 0, "recovery": 30, "cooldown": 60,
                  "animation": "demo:pixel"}
        recipe = {"schemaVersion": "content-0", "id": "demo:recipe",
                  "sourceA": "demo:a", "sourceB": "demo:b", "result": "demo:result"}
        for file, value in [("a.json", dict(base, id="demo:a")),
                            ("b.json", dict(base, id="demo:b")),
                            ("result.json", result), ("recipe.json", recipe)]:
            write_json(self.root / "data" / file, value)
        manifest = json.loads((self.root / "manifest.json").read_text())
        manifest.update(moves=["data/a.json", "data/b.json"],
                        mixRecipes=["data/recipe.json"], mixResults=["data/result.json"])
        write_json(self.root / "manifest.json", manifest)
        before = load_project(self.root, self.kernel).content_hash
        write_json(self.root / "data/recipe.json", dict(recipe, sourceA="demo:b", sourceB="demo:a"))
        self.assertEqual(before, load_project(self.root, self.kernel).content_hash)

    def test_mix_result_rejects_effects_and_power_over_200(self) -> None:
        result = {"schemaVersion": "content-0", "id": "demo:result", "name": "Result",
                  "components": [1], "power": 201, "alwaysHit": True,
                  "windup": 0, "recovery": 30, "cooldown": 60,
                  "animation": "demo:pixel"}
        write_json(self.root / "data/result.json", result)
        manifest = json.loads((self.root / "manifest.json").read_text())
        manifest["mixResults"] = ["data/result.json"]
        write_json(self.root / "manifest.json", manifest)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "integer")
        result["power"] = 200
        result["effects"] = []
        write_json(self.root / "data/result.json", result)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "unknown-field")

    def test_canonical_identity_ignores_json_keys_and_manifest_order(self) -> None:
        first = load_project(self.root, self.kernel).content_hash
        manifest = json.loads((self.root / "manifest.json").read_text())
        write_json(self.root / "manifest.json", dict(reversed(list(manifest.items()))))
        catalog = json.loads((self.root / "data/catalog.json").read_text())
        write_json(self.root / "data/catalog.json", dict(reversed(list(catalog.items()))))
        self.assertEqual(first, load_project(self.root, self.kernel).content_hash)

    def test_duplicate_key_rejected(self) -> None:
        (self.root / "project.json").write_text('{"schemaVersion":"content-0","schemaVersion":"content-0"}', encoding="utf-8")
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "json")

    def test_deep_json_and_escaped_surrogate_rejected_as_content(self) -> None:
        (self.root / "project.json").write_text("[" * 1100 + "]" * 1100, encoding="utf-8")
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "json")
        (self.root / "project.json").write_bytes(b'{"schemaVersion":"content-0","id":"demo:project","name":"\\ud800","ruleset":"unassigned","entryMap":"demo:start"}')
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "json")

    def test_bool_is_not_an_integer(self) -> None:
        doc = json.loads((self.root / "data/map.json").read_text())
        doc["width"] = True
        write_json(self.root / "data/map.json", doc)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/width")

    def test_unknown_key_uses_a_valid_json_pointer(self) -> None:
        doc = json.loads((self.root / "project.json").read_text())
        doc["a/b~c"] = 1
        write_json(self.root / "project.json", doc)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/a~1b~0c")

    def test_symlink_and_hardlink_rejected(self) -> None:
        source = self.root / "data/map.json"
        target = self.root / "data/real.json"
        source.rename(target)
        source.symlink_to("real.json")
        with self.assertRaises(ContentError):
            load_project(self.root, self.kernel)
        source.unlink(); os.link(target, source)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "file-type")

    def test_symlink_in_project_root_ancestry_is_rejected(self) -> None:
        alias = Path(self.temp.name) / "alias"
        alias.symlink_to(self.root.parent, target_is_directory=True)
        with self.assertRaises(ContentError) as caught:
            load_project(alias / self.root.name, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "root")

    @unittest.skipUnless(hasattr(os, "mkfifo"), "FIFO unsupported")
    def test_fifo_is_rejected_without_blocking(self) -> None:
        (self.root / "data/map.json").unlink()
        os.mkfifo(self.root / "data/map.json")
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "file-type")

    def test_kernel_semantic_error_maps_to_source(self) -> None:
        bad = make_kernel(Path(self.temp.name), "ERR 3 0 0\n", 2)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, bad)
        diagnostic = caught.exception.diagnostics[0]
        self.assertEqual((diagnostic.file, diagnostic.pointer, diagnostic.entity_id), ("data/encounter.json", "/entries/0/level", "demo:field"))

    def test_kernel_dimension_error_points_to_height_when_width_is_valid(self) -> None:
        doc = json.loads((self.root / "data/map.json").read_text())
        doc["height"] = 0
        write_json(self.root / "data/map.json", doc)
        bad = make_kernel(Path(self.temp.name), "ERR 4 0 0\n", 2)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, bad)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/height")

    def test_kernel_wire_failure_is_infrastructure(self) -> None:
        bad = make_kernel(Path(self.temp.name), "WIRE bad-token\n", 2)
        with self.assertRaises(InfrastructureError):
            load_project(self.root, bad)

    def test_cli_exit_codes_and_json(self) -> None:
        installed = ROOT / "build/content-kernel"
        self.assertTrue(installed.is_file(), "build the native content kernel first")
        result = subprocess.run([sys.executable, ROOT / "scripts/validate_project.py", self.root], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["ok"])
        (self.root / "project.json").write_text("{}", encoding="utf-8")
        result = subprocess.run([sys.executable, ROOT / "scripts/validate_project.py", self.root], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse(json.loads(result.stdout)["ok"])


if __name__ == "__main__":
    unittest.main()
