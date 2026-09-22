"""M5 allocation, modifier, rejection, boundary and cross-target fixture tests."""

from __future__ import annotations

import json
from pathlib import Path
import unittest

from .fixture_loader import FixtureValidationError, load_corpus, load_fixture

ROOT = Path(__file__).resolve().parent
FIXTURES = ROOT / "fixtures"


def oracle(fixture: dict) -> tuple[list[int], list[int], int, str]:
    types = fixture["components"]
    canonical_types = sorted(types)
    count = len(types)
    if not 1 <= count <= 4 or len(types) != len(set(types)) or not 1 <= fixture["power"] <= 200:
        raise FixtureValidationError("rejected")
    quotient, remainder = divmod(fixture["power"], count)
    allocations = [quotient + (canonical_types.index(type_id) < remainder) for type_id in types]
    # Mirror the production exact-rational component chain. The fixture profile
    # defaults to level 50, attack 100 and defense 100.
    damages = []
    actor_types = set(fixture["actor_types"])
    strong = {
        1: {3, 7}, 2: {1, 4}, 3: {2, 4}, 4: {1, 6},
        5: {3, 9}, 6: {2, 5}, 7: {3, 5}, 8: {7, 9},
        9: {8, 6},
    }
    profile = fixture.get("profile", {"level": 50, "attack": 100, "defense": 100})
    for type_id, allocation in zip(types, allocations):
        numerator = allocation * (2 * profile["level"] + 50) * profile["attack"]
        denominator = 300 * profile["defense"]
        if type_id in actor_types:
            numerator *= 3
            denominator *= 2
        for defender in fixture["defender_types"]:
            if defender in strong.get(type_id, set()):
                numerator *= 2
            elif type_id in strong.get(defender, set()):
                denominator *= 2
        damages.append(numerator // denominator)
    canonical = "|".join(f"{type_id}:{allocation}:{damage}" for type_id, allocation, damage in zip(types, allocations, damages))
    return allocations, damages, sum(damages), canonical


class M5FixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fixtures = load_corpus(FIXTURES)

    def test_corpus_has_one_to_four_component_examples(self) -> None:
        counts = {len(fixture["components"]) for fixture in self.fixtures if fixture["id"].startswith("allocation-")}
        self.assertEqual(counts, {1, 2, 3, 4})

    def test_allocation_and_component_modifiers_match_oracle(self) -> None:
        for fixture in self.fixtures:
            if fixture["id"] == "invalid-inputs":
                continue
            actual = oracle(fixture)
            expected = fixture["expected"]
            self.assertEqual(actual[0], expected["allocations"], fixture["id"])
            self.assertEqual(actual[1], expected["component_damage"], fixture["id"])
            self.assertEqual(actual[2], expected["total_damage"], fixture["id"])
            self.assertEqual(actual[3], expected["canonical"], fixture["id"])

    def test_remainder_is_author_order_independent(self) -> None:
        fixture = next(item for item in self.fixtures if item["id"] == "allocation-3")
        reordered = dict(fixture)
        reordered["components"] = list(reversed(fixture["components"]))
        original = dict(zip(fixture["components"], oracle(fixture)[0]))
        reversed_result = dict(zip(reordered["components"], oracle(reordered)[0]))
        self.assertEqual(original, reversed_result)
        self.assertNotEqual(fixture["components"], reordered["components"])

    def test_canonical_registry_order_controls_remainder(self) -> None:
        fixture = next(item for item in self.fixtures if item["id"] == "allocation-2")
        # Authored order is [7, 2], while canonical registry order is [2, 7].
        # The extra power point belongs to type 2 in the canonical order.
        self.assertEqual(oracle(fixture)[0], [50, 51])

    def test_native_and_javascript_canonical_outputs_match(self) -> None:
        for fixture in self.fixtures:
            self.assertEqual(fixture["expected"]["native"], fixture["expected"]["javascript"])

    def test_negative_shape_cases_reject(self) -> None:
        source = FIXTURES / "allocation-1.json"
        value = json.loads(source.read_text(encoding="utf-8"))
        for components, message in (([], "non-empty"), ([1, 1], "duplicate"), ([1, 2, 3, 4, 5], "at most")):
            value["components"] = components
            with self.assertRaisesRegex(FixtureValidationError, message):
                path = FIXTURES / ".temporary-invalid.json"
                path.write_text(json.dumps(value), encoding="utf-8")
                try:
                    load_fixture(path)
                finally:
                    path.unlink()

    def test_invalid_power_and_modifier_boundaries_are_rejected(self) -> None:
        source = FIXTURES / "allocation-1.json"
        value = json.loads(source.read_text(encoding="utf-8"))
        for power in (0, 201):
            value["power"] = power
            path = FIXTURES / ".temporary-invalid.json"
            path.write_text(json.dumps(value), encoding="utf-8")
            try:
                with self.assertRaises(FixtureValidationError):
                    load_fixture(path)
            finally:
                path.unlink()
        value["power"] = 100
        value["defender_types"] = []
        path = FIXTURES / ".temporary-invalid.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        try:
            with self.assertRaises(FixtureValidationError):
                load_fixture(path)
        finally:
            path.unlink()

    def test_duplicate_actor_snapshot_is_rejected(self) -> None:
        source = FIXTURES / "allocation-1.json"
        value = json.loads(source.read_text(encoding="utf-8"))
        value["actor_types"] = [1, 1]
        path = FIXTURES / ".temporary-invalid.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        try:
            with self.assertRaisesRegex(FixtureValidationError, "duplicate"):
                load_fixture(path)
        finally:
            path.unlink()


if __name__ == "__main__":
    unittest.main()
