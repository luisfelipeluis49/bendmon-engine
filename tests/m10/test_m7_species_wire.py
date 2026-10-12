from __future__ import annotations

import sys
import unittest
from dataclasses import replace
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m7_binding import bind_m7_content
from content.m8_binding import bind_m8_content
from content.m10_m7_species_wire import (M10M7SpeciesWireError,
                                         encode_m10_m7_species)
from content.loader import load_project
from content.models import LevelMove, LoadedProject, MoveId, Species
from tests.content.test_m7_binding import project


class M10M7SpeciesWireTests(unittest.TestCase):
    def test_compact_identity_matches_world_binding(self) -> None:
        loaded = load_project(ROOT / "examples/m8-world")
        world = bind_m8_content(loaded, expected_ruleset_version="m8-1",
                                expected_content_digest=loaded.content_hash)
        wire = encode_m10_m7_species(world.m7)
        self.assertEqual(wire.tokens[2], world.content_identity)

    def test_emits_closed_numeric_progression_records(self) -> None:
        loaded = project()
        species = tuple(
            Species(row.id, row.name, row.sprite, row.progression,
                    (LevelMove(2, MoveId("demo:hit")),))
            for row in loaded.species
        )
        loaded = LoadedProject(
            loaded.project, loaded.assets, loaded.catalogs, species,
            loaded.encounters, loaded.maps, loaded.moves, loaded.mix_recipes,
            loaded.mix_results, loaded.items, loaded.shops,
            loaded.canonical_json, loaded.content_hash,
        )
        wire = encode_m10_m7_species(bind_m7_content(loaded))
        self.assertEqual(wire.tokens[:5], (13, 2, int("a" * 64, 16) & 0xFFFFFFFF, 2, 2))
        self.assertEqual(wire.tokens[5:21], (1, 50, 51, 52, 53, 54, 55,
                                              500, 100, 0, 1, 0, 0, 1, 2, 1))
        self.assertNotIn("demo:", wire.text)
        self.assertEqual(tuple(map(int, wire.text.split())), wire.tokens)

    def test_encodes_one_or_two_combat_types_and_rejects_duplicates(self) -> None:
        binding = bind_m7_content(project())
        typed = replace(binding.species[0], combat_types=(4, 8))
        wire = encode_m10_m7_species(replace(
            binding, species=(typed, *binding.species[1:])))
        self.assertEqual(wire.tokens[15:18], (2, 4, 8))
        malformed = replace(typed, combat_types=(4, 4))
        with self.assertRaisesRegex(M10M7SpeciesWireError, "duplicate combat types"):
            encode_m10_m7_species(replace(
                binding, species=(malformed, *binding.species[1:])))

    def test_rejects_bad_ruleset_and_unbound_progression_reference(self) -> None:
        loaded = project()
        binding = bind_m7_content(loaded)
        with self.assertRaisesRegex(M10M7SpeciesWireError, "m7-1"):
            encode_m10_m7_species(replace(binding, ruleset_version="m8-1"))
        invalid_species = replace(binding.species[0], engine_level_moves=((2, 99),))
        with self.assertRaisesRegex(M10M7SpeciesWireError, "unknown move"):
            encode_m10_m7_species(replace(
                binding, species=(invalid_species, *binding.species[1:])))
        with self.assertRaisesRegex(M10M7SpeciesWireError, "dense and ordered"):
            encode_m10_m7_species(replace(
                binding, species=(replace(binding.species[0], id=3),
                                  *binding.species[1:])))


if __name__ == "__main__":
    unittest.main()
