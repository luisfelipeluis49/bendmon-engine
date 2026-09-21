"""Structural and arithmetic checks for the bounded M3 calculation vectors."""

from __future__ import annotations

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
VECTORS = ROOT / "tests" / "battle" / "vectors"
VECTOR_VERSION = "m3-vectors-1"


def load(name: str) -> dict:
    return json.loads((VECTORS / name).read_text(encoding="utf-8"))


def integer(value: object, path: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise AssertionError(f"{path}: expected strict integer")
    return value


class CombatVectorTests(unittest.TestCase):
    def test_index_and_vector_files_have_stable_closed_shape(self) -> None:
        index = load("index.json")
        self.assertEqual(index, {
            "vector_version": VECTOR_VERSION,
            "files": ["accuracy.json", "critical.json", "damage.json"],
        })
        ids: list[str] = []
        for filename in index["files"]:
            document = load(filename)
            self.assertEqual(set(document), {"vector_version", "kind", "vectors"})
            self.assertEqual(document["vector_version"], VECTOR_VERSION)
            self.assertIsInstance(document["kind"], str)
            self.assertTrue(document["vectors"])
            for vector in document["vectors"]:
                self.assertEqual(set(vector), {"id", "inputs", "expected"})
                self.assertIsInstance(vector["id"], str)
                self.assertNotIn(vector["id"], ids)
                ids.append(vector["id"])
                self.assertIsInstance(vector["inputs"], dict)
                self.assertIsInstance(vector["expected"], dict)

    def test_accuracy_vectors_use_floor_then_probability_clamp(self) -> None:
        document = load("accuracy.json")
        for vector in document["vectors"]:
            inputs = vector["inputs"]
            expected = vector["expected"]
            base = integer(inputs["base_chance"], f'{vector["id"]}/base_chance')
            attacker = integer(inputs["attacker_accuracy_stage"], f'{vector["id"]}/attacker_accuracy_stage')
            evasion = integer(inputs["target_evasion_stage"], f'{vector["id"]}/target_evasion_stage')
            before = attacker - evasion
            self.assertEqual(expected["net_stage_before_clamp"], before)
            if inputs["always_hit"]:
                self.assertEqual(expected["rng_draws"], 0)
                self.assertIsNone(expected["chance"])
                continue
            stage = max(-6, min(6, before))
            if stage >= 0:
                numerator, denominator = 3 + stage, 3
            else:
                numerator, denominator = 3, 3 + abs(stage)
            pre_clamp = base * numerator // denominator
            chance = max(500, min(10000, pre_clamp))
            self.assertEqual(expected["net_stage"], stage)
            self.assertEqual(expected["factor_numerator"], numerator)
            self.assertEqual(expected["factor_denominator"], denominator)
            self.assertEqual(expected["pre_clamp_chance"], pre_clamp)
            self.assertEqual(expected["chance"], chance)
            self.assertEqual(expected["hit"], inputs["sample"] < chance)
            self.assertEqual(expected["rng_draws"], 1)

    def test_critical_vectors_use_baseline_cap_and_double(self) -> None:
        for vector in load("critical.json")["vectors"]:
            inputs = vector["inputs"]
            expected = vector["expected"]
            if not inputs["damaging"] or not inputs["nonimmune"]:
                self.assertEqual(expected["rng_draws"], 0)
                continue
            base = 625
            uncapped = base + integer(inputs["critical_bonus"], f'{vector["id"]}/critical_bonus')
            chance = min(2500, uncapped)
            critical = inputs["sample"] < chance
            damage = integer(inputs["damage_before_critical"], f'{vector["id"]}/damage_before_critical')
            self.assertEqual(expected["uncapped_chance"], uncapped)
            self.assertEqual(expected["chance"], chance)
            self.assertEqual(expected["critical"], critical)
            self.assertEqual(expected["damage_after"], damage * 2 if critical else damage)
            self.assertEqual(expected["rng_draws"], 1)

    def test_damage_vectors_preserve_integer_intermediates_and_zero_distinction(self) -> None:
        for vector in load("damage.json")["vectors"]:
            inputs = vector["inputs"]
            expected = vector["expected"]
            power = integer(inputs["power"], f'{vector["id"]}/power')
            level = integer(inputs["level"], f'{vector["id"]}/level')
            attack = integer(inputs["captured_attack"], f'{vector["id"]}/captured_attack')
            defense = integer(inputs["current_defense"], f'{vector["id"]}/current_defense')
            numerator = power * (2 * level + 50) * attack
            denominator = 300 * defense
            damage = numerator // denominator
            self.assertEqual(expected["numerator"], numerator)
            self.assertEqual(expected["denominator"], denominator)
            self.assertEqual(expected["damage"], damage)
            self.assertEqual(expected["outcome"], "Damage" if damage else "NoDamage")


if __name__ == "__main__":
    unittest.main()
