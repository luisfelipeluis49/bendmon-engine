"""Guard the shipped Bend threshold table against the approved generator."""
from __future__ import annotations

import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class XpTableTests(unittest.TestCase):
    def test_bend_table_matches_all_200_generated_thresholds(self) -> None:
        source = (ROOT / "engine/progression/core.bend").read_text(encoding="utf-8")
        match = re.search(r"def xp_thresholds\(\) -> List<&2, U32>:\s*\[([^]]+)\]", source)
        self.assertIsNotNone(match, "production Bend XP table is missing")
        actual = [int(value) for value in re.findall(r"\b\d+\b", match.group(1))]
        generated = json.loads((ROOT / "rules/generated/xp_thresholds.json")
                               .read_text(encoding="utf-8"))["thresholds"]
        self.assertEqual(len(actual), 200)
        self.assertEqual(actual, generated)
        self.assertEqual(actual, [25 * (level - 1) ** 3 + 75 * (level - 1)
                                  for level in range(1, 201)])


if __name__ == "__main__":
    unittest.main()
