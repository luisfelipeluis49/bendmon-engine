"""Regression checks for the generated U06 cumulative XP table."""
import importlib.util
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
TABLE_PATH = ROOT / "rules" / "generated" / "xp_thresholds.json"
GENERATOR_PATH = ROOT / "scripts" / "generate_xp_table.py"
_SPEC = importlib.util.spec_from_file_location("generate_xp_table", GENERATOR_PATH)
assert _SPEC is not None and _SPEC.loader is not None
GENERATOR = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(GENERATOR)


class XPTableTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = json.loads(TABLE_PATH.read_text(encoding="utf-8"))
        cls.thresholds = cls.document["thresholds"]

    def test_has_200_entries_and_level_one_is_zero(self):
        self.assertEqual(len(self.thresholds), 200)
        self.assertEqual(self.thresholds[0], 0)

    def test_thresholds_are_strictly_increasing_after_level_one(self):
        self.assertTrue(all(a < b for a, b in zip(self.thresholds, self.thresholds[1:])))

    def test_every_entry_matches_the_integer_formula(self):
        expected = [GENERATOR.xp_for_level(level) for level in range(1, 201)]
        self.assertEqual(self.thresholds, expected)

    def test_all_entries_are_u32_safe(self):
        self.assertTrue(all(0 <= threshold <= GENERATOR.U32_MAX for threshold in self.thresholds))

    def test_level_200_is_the_cap(self):
        self.assertEqual(self.document["level200Cap"], self.thresholds[-1])
        self.assertEqual(self.thresholds[-1], 197_029_900)


if __name__ == "__main__":
    unittest.main()
