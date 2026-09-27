"""The loaded M8 map reaches the CPU renderer without changing game state."""
from __future__ import annotations

import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.loader import load_project
from presentation.composer import render_frame
from presentation.wire import ActorView, BattleView, CueView, NpcView, SceneView


class ComposerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.library = Path(os.environ.get("M9_RASTER_LIBRARY", ROOT / "build/m9-raster.so"))
        cls.root = ROOT / "examples/m8-world"
        cls.loaded = load_project(cls.root)

    def scene(self, *, x: int = 2048) -> SceneView:
        return SceneView(int(self.loaded.content_hash[:8], 16), 1,
                         x, 0, 2048, 0,
                         (NpcView(1, 1024, 0, 1024, 1),), None)

    def test_loaded_world_frame_and_cue_effect(self) -> None:
        original_hash = self.loaded.content_hash
        still = render_frame(self.root, self.loaded, self.scene(), (),
                             self.library, 320, 180)
        moved = render_frame(self.root, self.loaded, self.scene(x=4096), (),
                             self.library, 320, 180)
        signalled = render_frame(self.root, self.loaded, self.scene(),
                                 (CueView(1, 0, 0, 7, 0),),
                                 self.library, 320, 180)
        self.assertEqual(len(still), 320 * 180 * 4)
        self.assertNotEqual(still, moved)
        self.assertNotEqual(still, signalled)
        self.assertEqual(self.loaded.content_hash, original_hash)

    def test_rejects_wrong_identity_and_map(self) -> None:
        scene = self.scene()
        with self.assertRaisesRegex(ValueError, "content identity"):
            render_frame(self.root, self.loaded,
                         SceneView(scene.content_identity + 1, scene.map_id,
                                   scene.x, scene.y, scene.z, scene.facing,
                                   scene.npcs, scene.battle), (), self.library, 64, 64)
        with self.assertRaisesRegex(ValueError, "validated map"):
            render_frame(self.root, self.loaded,
                         SceneView(scene.content_identity, 2,
                                   scene.x, scene.y, scene.z, scene.facing,
                                   scene.npcs, scene.battle), (), self.library, 64, 64)

    def test_battle_projection_has_distinct_frame(self) -> None:
        world = self.scene()
        battle = SceneView(world.content_identity, world.map_id,
                           world.x, world.y, world.z, world.facing,
                           world.npcs, BattleView(42, 1,
                               (ActorView(1, 0, 30, 0), ActorView(2, 1, 20, 1))))
        world_frame = render_frame(self.root, self.loaded, world, (),
                                   self.library, 320, 180)
        battle_frame = render_frame(self.root, self.loaded, battle, (),
                                    self.library, 320, 180)
        self.assertNotEqual(world_frame, battle_frame)


if __name__ == "__main__":
    unittest.main()
