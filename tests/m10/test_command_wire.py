import unittest
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m10_command_wire import (
    Activate, AdvanceBattle, AdvanceDialogue, BattleEscape, BattleMove, BattleWait,
    ChooseEvent, ContinueEvent, FastTravel, Interact, M10CommandWireError,
    Move, Traverse, encode_m10_commands,
)
from content.m8_binding import SignedCoord


class M10CommandWireTests(unittest.TestCase):
    def test_encodes_closed_command_variants_with_exact_sequences(self):
        commands = (
            Move(SignedCoord(False, 256), SignedCoord(True, 512), True, False),
            Interact(9, SignedCoord(True, 12), SignedCoord(False, 20)),
            Activate(3), Traverse(4), FastTravel(5), ContinueEvent(),
            ChooseEvent(True),
            AdvanceDialogue(),
            BattleWait(0), BattleEscape(0), AdvanceBattle(), BattleMove(0, 1, 7),
        )
        wire = encode_m10_commands(commands)
        self.assertEqual(wire.version, 1)
        self.assertEqual(wire.tokens, (
            14, 1, 12,
            0, 1, 0, 256, 1, 512, 1, 0,
            1, 2, 9, 1, 12, 0, 20,
            2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 1, 7, 8,
            8, 9, 0, 9, 10, 0, 10, 11, 11, 12, 0, 1, 7,
        ))
        self.assertEqual(wire.text, " ".join(map(str, wire.tokens)))

    def test_rejects_noncanonical_or_out_of_bounds_command_values(self):
        invalid = (
            (Move(SignedCoord(True, 0), SignedCoord(False, 0), False, False),),
            (Move(SignedCoord(False, 524289), SignedCoord(False, 0), False, False),),
            (Activate(0),),
            (ChooseEvent(1),),
            (BattleWait(1),), (BattleEscape(False),),
            (BattleMove(0, 0, 7),), (BattleMove(0, 1, 0),),
            (object(),),
        )
        for commands in invalid:
            with self.subTest(commands=commands), self.assertRaises(M10CommandWireError):
                encode_m10_commands(commands)

    def test_rejects_non_tuple_and_overlong_logs(self):
        with self.assertRaisesRegex(M10CommandWireError, "tuple"):
            encode_m10_commands([ContinueEvent()])
        with self.assertRaisesRegex(M10CommandWireError, "4096"):
            encode_m10_commands((ContinueEvent(),) * 4097)

    def test_accepts_exact_command_limit_and_assigns_last_sequence(self):
        wire = encode_m10_commands((ContinueEvent(),) * 4096)
        self.assertEqual(wire.tokens[2], 4096)
        self.assertEqual(wire.tokens[-2:], (4095, 6))


if __name__ == "__main__":
    unittest.main()
