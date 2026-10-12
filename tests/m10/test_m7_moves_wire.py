from __future__ import annotations

import sys
import unittest
from dataclasses import replace
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m7_binding import bind_m7_content
from content.models import MoveEffect
from content.m10_m7_moves_wire import (M10M7MovesWireError,
                                       encode_m10_m7_moves)
from tests.content.test_m7_binding import project


class M10M7MovesWireTests(unittest.TestCase):
    def test_encodes_closed_move_descriptors(self) -> None:
        binding = bind_m7_content(project())
        binding = replace(binding, moves=(
            replace(binding.moves[0], recovery=30, cooldown=60),
            replace(binding.moves[1], recovery=30, cooldown=60, power=75,
                    components=(2, 4), damage_category="special"),
        ))
        wire = encode_m10_m7_moves(binding)
        self.assertEqual(wire.tokens[:4], (15, 3, 0xAAAAAAAA, 2))
        self.assertEqual(wire.tokens[4:19], (1, 0, 1, 0, 0, 30, 60, 0, 0, 0, 0, 0, 0, 8, 0))
        self.assertEqual(wire.tokens[19:34], (2, 75, 0, 9000, 1, 30, 60, 2, 2, 4, 0, 0, 1, 8, 0))
        self.assertEqual(tuple(map(int, wire.text.split())), wire.tokens)

    def test_encodes_explicit_closed_effect_nodes_and_priority(self) -> None:
        binding = bind_m7_content(project())
        row = replace(binding.moves[0], recovery=30, cooldown=60, power=None,
                      components=None, priority=-3,
                      effects=(MoveEffect("applyStatus", "target", status="burn"),))
        wire = encode_m10_m7_moves(replace(binding, moves=(row,)))
        self.assertEqual(wire.version, 3)
        self.assertEqual(wire.tokens[17:], (5, 1, 4, 1, 0, 0, 0, 0, 0))

    def test_rejects_invalid_hit_mode_or_missing_m7_component_shape(self) -> None:
        binding = bind_m7_content(project())
        binding = replace(binding, moves=tuple(replace(row, recovery=30, cooldown=60)
                                                for row in binding.moves))
        malformed = replace(binding.moves[0], accuracy=None, always_hit=False)
        with self.assertRaisesRegex(M10M7MovesWireError, "hit mode"):
            encode_m10_m7_moves(replace(binding, moves=(malformed, *binding.moves[1:])))
        malformed = replace(binding.moves[0], components=(2, 2))
        with self.assertRaisesRegex(M10M7MovesWireError, "duplicate"):
            encode_m10_m7_moves(replace(binding, moves=(malformed, *binding.moves[1:])))
        damaging_without_components = replace(binding.moves[1], power=75)
        with self.assertRaisesRegex(M10M7MovesWireError, "requires type components"):
            encode_m10_m7_moves(replace(
                binding, moves=(binding.moves[0], damaging_without_components)))
        invalid_category = replace(binding.moves[0], damage_category="status")
        with self.assertRaisesRegex(M10M7MovesWireError, "damage category"):
            encode_m10_m7_moves(replace(binding, moves=(invalid_category, *binding.moves[1:])))


if __name__ == "__main__":
    unittest.main()
