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

    def test_parses_per_command_logical_timing_trace(self) -> None:
        output = ("M10PLAY2 ACCEPTED\nIDENTITY 305419896\nCOMMANDS 2\n"
                  f"DIALOGUE 0 0 1\nSCENE {SCENE}\nCUES 1,0\n"
                  "TRACE 2,2\nTRACE_STEP 0,0,5,1\nTRACE_STEP 1,5,7,0\n")
        response = parse_runtime_response(output, expected_content_hash=HASH,
                                          expected_commands=2)
        self.assertEqual([(step.command_index, step.logical_tick, step.post_tick,
                           step.enemy_wait) for step in response.command_trace],
                         [(0, 0, 5, True), (1, 5, 7, False)])
        for tail in ("TRACE 2,1\nTRACE_STEP 0,0,5,0\n",
                     "TRACE 2,2\nTRACE_STEP 1,0,5,0\nTRACE_STEP 0,5,7,0\n",
                     "TRACE 2,2\nTRACE_STEP 0,0,7,0\nTRACE_STEP 1,6,7,0\n",
                     "TRACE 2,2\nTRACE_STEP 0,0,5,2\nTRACE_STEP 1,5,7,0\n"):
            with self.subTest(tail=tail), self.assertRaises(RuntimeResponseError):
                parse_runtime_response(output.rsplit("TRACE 2,2\n", 1)[0] + tail,
                                       expected_content_hash=HASH,
                                       expected_commands=2)

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

    def test_save_projection_is_typed_and_rejected_during_dialogue(self) -> None:
        save = "SAVE 1,305419896,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0"
        output = ("M10PLAY2 ACCEPTED\nIDENTITY 305419896\nCOMMANDS 0\n"
                  f"DIALOGUE 0 0 1\nSCENE {SCENE}\nCUES 1,0\n{save}\n")
        result = parse_runtime_response(output, expected_content_hash=HASH,
                                        expected_commands=0)
        self.assertEqual(result.save_snapshot.map_id, 1)
        self.assertEqual(result.save_snapshot.rng_state, (1, 0, 0, 0))
        with self.assertRaisesRegex(RuntimeResponseError, "cannot be saved"):
            parse_runtime_response(output.replace("DIALOGUE 0 0 1", "DIALOGUE 2 0 0"),
                                   expected_content_hash=HASH, expected_commands=0)
        with self.assertRaisesRegex(RuntimeResponseError, "entity count"):
            parse_runtime_response(output.replace(save, save[:-1] + "9"),
                                   expected_content_hash=HASH, expected_commands=0)

    def test_optional_progression_row_decodes_typed_wire_and_absence(self) -> None:
        payload = (6, 4, 1000, 999, 512, 9999999, 0, 0, 0, 0, 0, 0,
                   6, 4, 1000, 999, 512, 9999999, 0, 0, 0, 0, 7, 305419896)
        tokens = (1, len(payload), *payload)
        row = "PROGRESSION 1," + ",".join(map(str, tokens))
        output = ("M10PLAY2 ACCEPTED\nIDENTITY 305419896\nCOMMANDS 1\n"
                  f"DIALOGUE 0 0 1\nSCENE {SCENE}\nCUES 1,0\n{row}\n")
        result = parse_runtime_response(output, expected_content_hash=HASH,
                                        expected_commands=1)
        self.assertEqual(result.progression.ruleset, 7)
        self.assertEqual(result.progression.content_identity, 305419896)
        self.assertEqual(result.progression.roster.party, ())
        absent = parse_runtime_response(output.replace(row, "PROGRESSION 0"),
                                        expected_content_hash=HASH,
                                        expected_commands=1)
        self.assertIsNone(absent.progression)
        with self.assertRaisesRegex(RuntimeResponseError, "matching world identity"):
            parse_runtime_response(output.replace(row, row.rsplit(",", 1)[0] + ",1"),
                                   expected_content_hash=HASH, expected_commands=1)

    def test_progression_row_rejects_malformed_or_duplicate_records(self) -> None:
        output = ("M10PLAY2 ACCEPTED\nIDENTITY 305419896\nCOMMANDS 1\n"
                  f"DIALOGUE 0 0 1\nSCENE {SCENE}\nCUES 1,0\nPROGRESSION 0\n")
        for tail in ("PROGRESSION 1,01", "PROGRESSION 2", "PROGRESSION 0\nPROGRESSION 0"):
            with self.subTest(tail=tail), self.assertRaises(RuntimeResponseError):
                parse_runtime_response(output.replace("PROGRESSION 0", tail),
                                       expected_content_hash=HASH,
                                       expected_commands=1)


if __name__ == "__main__":
    unittest.main()
