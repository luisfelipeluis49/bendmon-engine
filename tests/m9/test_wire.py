"""Reject malformed projection/cue records at the host boundary."""
from __future__ import annotations

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "platform"))
from presentation.wire import SceneWireError, parse_cues, parse_scene


class WireTest(unittest.TestCase):
    def test_scene_with_npc_and_battle(self) -> None:
        # version, identity, map, player xyz, facing, NPC, battle actor
        line = ("1,7,1,0,1024,0,0,1,512,2,0,1024,0,0,1,512,1,1,0,2048,0,0,0,3072,1,9,"
                "1,50,0,1,4,1,120,2")
        scene = parse_scene(line)
        self.assertEqual((scene.x, scene.y, scene.z), (1024, 0, -512))
        self.assertEqual(scene.npcs[0].event_id, 9)
        self.assertEqual((scene.battle.tick, scene.battle.actors[0].hp), (50, 120))

    def test_cue_order_and_rejections(self) -> None:
        cues = parse_cues("1,2,3,0,0,7,0,3,1,1,30,0")
        self.assertEqual([(cue.ordinal, cue.index) for cue in cues],
                         [(3, 0), (3, 1)])
        for line in ("1,2,3,0,0,7,0", "1,2,3,0,0,7,0,3,0,1,30,0",
                     "1,0,", "1,0,٠", "2,0"):
            with self.subTest(line=line), self.assertRaises(SceneWireError):
                parse_cues(line)
        for line in ("1,7,1,1,0,0,0,0,0,0,0,0", "1,7,1,0,0,0,0,0,0,4,0,0",
                     "1,7,1,0,0,0,0,0,0,0,0,0,0", "1,7,1,0,0,0,0,0,0,0,65,0"):
            with self.subTest(line=line), self.assertRaises(SceneWireError):
                parse_scene(line)


if __name__ == "__main__":
    unittest.main()
