"""The host emits only validated numeric M8 catalog data for Bend."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.loader import load_project
from content.m8_binding import bind_m8_content
from content.m8_bend_source import render_m8_catalog


class M8BendSourceTests(unittest.TestCase):
    def test_loaded_catalog_uses_closed_constructors_and_exact_identity(self) -> None:
        loaded = load_project(ROOT / "examples/m8-world")
        binding = bind_m8_content(
            loaded, expected_ruleset_version="m8-1",
            expected_content_digest=loaded.content_hash,
        )
        source = render_m8_catalog(binding)
        self.assertIn("Catalog.WorldMap{", source)
        self.assertIn("Events.SetValue{7n, 1n}", source)
        self.assertIn("Handoff.EncounterTable{", source)
        self.assertIn(f"{binding.content_identity}n", source)
        self.assertNotIn("sample:grove", source)
        self.assertNotIn("sample:greeting", source)
        self.assertNotIn("sample:mossling", source)


if __name__ == "__main__":
    unittest.main()
