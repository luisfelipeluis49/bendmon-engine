"""Creator actions become only closed bounded world commands."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m10_command_wire import (Activate, AdvanceBattle, BattleEscape, BattleMove,
                                      BattleWait, Move)
from maker.command_input import CommandInputError, parse_command


class CommandInputTests(unittest.TestCase):
    def test_parses_typed_move_and_trigger(self) -> None:
        move = parse_command({"kind": "move", "x": -1024, "z": 0,
                              "analog": False, "sprint": True})
        self.assertIsInstance(move, Move)
        self.assertTrue(move.x.negative)
        self.assertEqual(move.x.magnitude, 1024)
        self.assertEqual(parse_command({"kind": "activate", "triggerId": 3}),
                         Activate(3))

    def test_rejects_boolean_coordinates_extra_fields_and_unknown_kind(self) -> None:
        for command in ({"kind": "move", "x": True, "z": 0,
                         "analog": False, "sprint": False},
                        {"kind": "activate", "triggerId": 1, "script": "run"},
                        {"kind": "unknown"}):
            with self.subTest(command=command), self.assertRaises(CommandInputError):
                parse_command(command)

    def test_parses_exact_battle_command_shapes(self) -> None:
        self.assertEqual(parse_command({"kind": "battleWait", "actorId": 0}),
                         BattleWait(0))
        self.assertEqual(parse_command({"kind": "battleEscape", "actorId": 0}),
                         BattleEscape(0))
        self.assertEqual(parse_command({"kind": "advanceBattle"}), AdvanceBattle())
        self.assertEqual(parse_command({"kind": "battleMove", "actorId": 0,
                                        "targetId": 1, "moveId": 7}), BattleMove(0, 1, 7))

    def test_rejects_nonzero_battle_actor_and_extra_fields(self) -> None:
        for command in ({"kind": "battleWait", "actorId": 1},
                        {"kind": "battleEscape", "actorId": False},
                        {"kind": "battleMove", "actorId": 0, "targetId": 0, "moveId": 7},
                        {"kind": "battleMove", "actorId": 0, "targetId": 1, "moveId": True},
                        {"kind": "advanceBattle", "actorId": 0}):
            with self.subTest(command=command), self.assertRaises(CommandInputError):
                parse_command(command)


if __name__ == "__main__":
    unittest.main()
