"""Process output must be exact before it can become a maker playtest result."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from maker.runtime_response import RuntimeResponseError, parse_runtime_response

HASH = "12345678" + "0" * 56
SCENE = "1,305419896,1," + ",".join(["0"] * 15)


class RuntimeResponseTests(unittest.TestCase):
    def test_accepts_typed_m9_projection_under_full_expected_hash(self) -> None:
        output = ("M10PLAY2 ACCEPTED\nIDENTITY 305419896\nCOMMANDS 1\n"
                  f"DIALOGUE 0 0 1\nSCENE {SCENE}\nCUES 1,0\n")
        result = parse_runtime_response(output, expected_content_hash=HASH,
                                        expected_commands=1)
        self.assertEqual((result.status, result.scene.map_id, result.cues),
                         ("accepted", 1, ()))
        self.assertEqual(result.content_hash, HASH)
        self.assertEqual((result.scene_csv, result.cues_csv), (SCENE, "1,0"))

    def test_rejects_mismatched_identity_or_extra_rows(self) -> None:
        output = ("M10PLAY2 ACCEPTED\nIDENTITY 1\nCOMMANDS 1\n"
                  f"DIALOGUE 0 0 1\nSCENE {SCENE}\nCUES 1,0\n")
        with self.assertRaisesRegex(RuntimeResponseError, "mismatches"):
            parse_runtime_response(output, expected_content_hash=HASH,
                                   expected_commands=1)
        with self.assertRaisesRegex(RuntimeResponseError, "wrong row count"):
            parse_runtime_response(output + "EXTRA\n",
                                   expected_content_hash=HASH,
                                   expected_commands=1)

    def test_rejection_has_no_authoritative_scene(self) -> None:
        result = parse_runtime_response("M10PLAY2 REJECTED\n",
                                        expected_content_hash=HASH,
                                        expected_commands=1)
        self.assertEqual(result.status, "rejected")
        self.assertIsNone(result.scene)

    def test_active_dialogue_cursor_is_bounded_and_typed(self) -> None:
        output = ("M10PLAY2 ACCEPTED\nIDENTITY 305419896\nCOMMANDS 2\n"
                  f"DIALOGUE 7 1 0\nSCENE {SCENE}\nCUES 1,0\n")
        result = parse_runtime_response(output, expected_content_hash=HASH,
                                        expected_commands=2)
        self.assertEqual((result.dialogue_id, result.dialogue_line_index,
                          result.dialogue_closed), (7, 1, False))
        for cursor in ("DIALOGUE 0 1 0", "DIALOGUE 7 64 0",
                       "DIALOGUE 7 1 2", "DIALOGUE +7 1 0"):
            with self.subTest(cursor=cursor), self.assertRaisesRegex(
                    RuntimeResponseError, "dialogue cursor"):
                parse_runtime_response(output.replace("DIALOGUE 7 1 0", cursor),
                                       expected_content_hash=HASH,
                                       expected_commands=2)

    def test_rejects_non_ascii_and_zero_encounter_id(self) -> None:
        with self.assertRaisesRegex(RuntimeResponseError, "invalid or oversized"):
            parse_runtime_response("\ud800", expected_content_hash=HASH,
                                   expected_commands=0)
        output = ("M10PLAY2 ENCOUNTER\nIDENTITY 305419896\nCOMMANDS 1\n"
                  f"ENCOUNTER 0\nDIALOGUE 0 0 1\nSCENE {SCENE}\nCUES 1,0\n")
        with self.assertRaisesRegex(RuntimeResponseError, "must be positive"):
            parse_runtime_response(output, expected_content_hash=HASH,
                                   expected_commands=1)


if __name__ == "__main__":
    unittest.main()
