"""Maker scenes use validated geometry and the existing M9 renderer shape."""
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from maker.playtest import freeze_project
from maker.presentation_content import presentation_content


class PresentationContentTests(unittest.TestCase):
    def test_bound_geometry_matches_frozen_identity(self) -> None:
        snapshot = freeze_project(ROOT / "examples/m8-world",
                                  rng_state=(1, 2, 3, 4), wait_ticks=60)
        content = presentation_content(snapshot)
        self.assertEqual(content["contentIdentity"], int(snapshot.content_hash[:8], 16))
        self.assertEqual(len(content["maps"]), 1)
        self.assertEqual(content["maps"][0]["runtimeId"], 1)
        self.assertEqual(len(content["maps"][0]["faces"]), 1)

    def test_authored_dialogue_lines_keep_runtime_order(self) -> None:
        snapshot = freeze_project(ROOT / "examples/m10-starter",
                                  rng_state=(1, 2, 3, 4), wait_ticks=60)
        content = presentation_content(snapshot)
        self.assertEqual(content["dialogues"][0]["runtimeId"], 1)
        self.assertEqual([line["text"] for line in content["dialogues"][0]["lines"]],
                         ["Welcome to Mosslight Glade.",
                          "The grass ahead is home to wild Mosskip."])
        self.assertEqual(content["starterMoves"],
                         [{"runtimeId": 1, "name": "Moss Strike"}])


if __name__ == "__main__":
    unittest.main()
