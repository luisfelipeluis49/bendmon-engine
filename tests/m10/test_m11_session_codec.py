from __future__ import annotations

from hashlib import sha256
from dataclasses import replace
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m10_command_wire import (  # noqa: E402
    Activate, AdvanceBattle, AdvanceDialogue, BattleEscape, BattleMove,
    BattleWait, ChooseEvent, ContinueEvent, FastTravel, Interact, Move, Traverse,
    encode_m10_commands,
)
from content.m8_binding import SignedCoord  # noqa: E402
from maker.m11_session_codec import (  # noqa: E402
    M11SessionCodecError,
    build_m11_replay,
    command_from_value,
    command_to_value,
    verify_m11_replay,
)
from maker.playtest import FrozenPlaytestSnapshot  # noqa: E402
from maker.runtime_response import CommandTraceStep, RuntimeResponse  # noqa: E402
from persistence.m11_replay import AcceptedCommand, ReplayFile  # noqa: E402
from persistence.m11_progression import decode_m11_progression  # noqa: E402
from persistence.world_state import WorldSnapshot  # noqa: E402


class M11SessionCodecTests(unittest.TestCase):
    def snapshot(self) -> FrozenPlaytestSnapshot:
        project = b'{"project":1}'
        return FrozenPlaytestSnapshot(Path("/tmp/frozen-project"), project,
                                      sha256(project).hexdigest(), (1, 2, 3, 4), 60)

    def commands(self):
        return (
            Move(SignedCoord(True, 12), SignedCoord(False, 0), False, True),
            Interact(7, SignedCoord(False, 1), SignedCoord(True, 2)),
            Activate(9), Traverse(10), FastTravel(11), ContinueEvent(),
            ChooseEvent(False), AdvanceDialogue(), BattleWait(0), BattleEscape(0),
            BattleMove(0, 1, 3), AdvanceBattle(),
        )

    @staticmethod
    def trace(commands, ticks=None):
        values = tuple(range(len(commands))) if ticks is None else tuple(ticks)
        return tuple(CommandTraceStep(index, tick) for index, tick in enumerate(values))

    def test_all_m10_command_variants_round_trip_as_bool_free_values(self) -> None:
        commands = self.commands()
        for command in commands:
            value = command_to_value(command)
            self.assertTrue(all(type(item) is not bool for item in value.values()))
            self.assertEqual(command_from_value(value), command)
        self.assertEqual(encode_m10_commands(commands).version, 1)

    def test_command_decoder_rejects_malformed_bool_free_payloads(self) -> None:
        for payload in (
            {"kind": "move", "xNegative": True, "xMagnitude": 0,
             "zNegative": 0, "zMagnitude": 0, "analog": 0, "sprint": 0},
            {"kind": "activate", "id": 0},
            {"kind": "advanceBattle", "extra": 1},
            {"kind": "unknown"},
        ):
            with self.subTest(payload=payload), self.assertRaises(M11SessionCodecError):
                command_from_value(payload)

    def test_replay_uses_exact_snapshot_identity_and_maker_barriers(self) -> None:
        snapshot = self.snapshot()
        commands = self.commands()
        trace = self.trace(commands, [0, 0, 2, 2, 2, 2, 2, 2, 9, 9, 9, 10])
        replay = build_m11_replay(snapshot, commands, engine_build="build-42",
                                  command_trace=trace)
        self.assertEqual(replay.header.ruleset_version, "m8-1")
        self.assertEqual(replay.header.content_digest, snapshot.content_hash)
        self.assertEqual(replay.header.initial_state["contentDigest"], snapshot.content_hash)
        self.assertEqual(replay.commands[0].logical_tick, 0)
        self.assertEqual([row.logical_tick for row in replay.commands],
                         [step.logical_tick for step in trace])
        self.assertEqual(replay.commands[0].barrier_id, 1)
        self.assertEqual(replay.commands[-1].barrier_id, len(self.commands()))
        self.assertEqual(replay.commands[-1].command_ordinal, 0)
        self.assertEqual([row.actor_id for row in replay.commands[-4:]], [0, 0, 0, 0])

    def test_replay_preserves_and_checks_battle_actor_id(self) -> None:
        snapshot = self.snapshot()
        commands = (BattleMove(0, 1, 16),)
        trace = self.trace(commands)
        replay = build_m11_replay(snapshot, commands, engine_build="build-42",
                                  command_trace=trace)
        self.assertEqual(replay.commands[0].actor_id,
                         replay.commands[0].payload["actorId"])

        altered = ReplayFile(replay.header,
                             (replace(replay.commands[0], actor_id=1),))
        with self.assertRaisesRegex(M11SessionCodecError, "actor id"):
            verify_m11_replay(altered, snapshot, executable_path="runtime",
                              runtime=Mock())

    def test_trusted_enemy_wait_is_recorded_and_authoritatively_checked(self) -> None:
        snapshot = self.snapshot()
        commands = (BattleMove(0, 1, 16),)
        trace = (CommandTraceStep(0, 15, 15, True),)
        replay = build_m11_replay(snapshot, commands, engine_build="build-42",
                                  command_trace=trace)
        self.assertEqual([(row.barrier_id, row.command_ordinal, row.actor_id,
                           row.logical_tick) for row in replay.commands],
                         [(1, 0, 0, 15), (1, 1, 1, 15)])
        response = RuntimeResponse("battle", snapshot.content_hash, 1,
                                   None, (), None, None, None, command_trace=trace)
        verify_m11_replay(replay, snapshot, executable_path="runtime",
                          runtime=Mock(return_value=response))
        missing_ai = replace(response, command_trace=(CommandTraceStep(0, 15, 15, False),))
        with self.assertRaisesRegex(M11SessionCodecError, "enemy wait"):
            verify_m11_replay(replay, snapshot, executable_path="runtime",
                              runtime=Mock(return_value=missing_ai))
        forged = ReplayFile(replay.header,
                            (replay.commands[0], replace(replay.commands[1], actor_id=0)))
        with self.assertRaisesRegex(M11SessionCodecError, "trusted enemy wait"):
            verify_m11_replay(forged, snapshot, executable_path="runtime",
                              runtime=Mock())

    def test_verify_resubmits_complete_typed_log_to_authoritative_runtime(self) -> None:
        snapshot = self.snapshot()
        commands = self.commands()
        trace = self.trace(commands, [0, 0, 1, 1, 1, 1, 1, 1, 12, 12, 12, 15])
        replay = build_m11_replay(snapshot, commands, engine_build="build-42",
                                  command_trace=trace)
        response = RuntimeResponse("accepted", snapshot.content_hash, len(commands),
                                   None, (), None, None, None,
                                   command_trace=trace)
        runtime = Mock(return_value=response)
        result = verify_m11_replay(replay, snapshot, executable_path="/tmp/bend-runtime",
                                   runtime=runtime)
        runtime.assert_called_once_with(snapshot, commands,
                                       executable_path="/tmp/bend-runtime")
        self.assertEqual(result.response, response)
        self.assertEqual(len(result.replay_digest), 64)

    def test_verify_requires_runtime_trace_to_match_each_replay_tick(self) -> None:
        snapshot = self.snapshot()
        commands = (BattleWait(0), AdvanceBattle())
        trace = self.trace(commands, [0, 17])
        replay = build_m11_replay(snapshot, commands, engine_build="build-42",
                                  command_trace=trace)
        response = RuntimeResponse("accepted", snapshot.content_hash, 2,
                                   None, (), None, None, None,
                                   command_trace=self.trace(commands, [0, 18]))
        with self.assertRaisesRegex(M11SessionCodecError, "timing differs"):
            verify_m11_replay(replay, snapshot, executable_path="runtime",
                              runtime=Mock(return_value=response))

    def test_verify_rejects_snapshot_mismatch_or_runtime_refusal(self) -> None:
        snapshot = self.snapshot()
        commands = (AdvanceBattle(),)
        replay = build_m11_replay(snapshot, commands, engine_build="build-42",
                                  command_trace=self.trace(commands))
        changed = FrozenPlaytestSnapshot(snapshot.project_root, snapshot.canonical_json,
                                         snapshot.content_hash, (5, 6, 7, 8), 60)
        with self.assertRaisesRegex(M11SessionCodecError, "initial state"):
            verify_m11_replay(replay, changed, executable_path="runtime",
                              runtime=Mock())
        rejected = RuntimeResponse("rejected", snapshot.content_hash, 0,
                                  None, (), None, None, None)
        with self.assertRaisesRegex(M11SessionCodecError, "did not accept"):
            verify_m11_replay(replay, snapshot, executable_path="runtime",
                              runtime=Mock(return_value=rejected))

    def test_verify_rejects_non_maker_timing_convention(self) -> None:
        snapshot = self.snapshot()
        commands = (BattleWait(0),)
        built = build_m11_replay(snapshot, commands, engine_build="build-42",
                                 command_trace=self.trace(commands))
        altered = ReplayFile(built.header,
                             (AcceptedCommand(1, 2, 0, 0,
                                              command_to_value(BattleWait(0))),))
        with self.assertRaisesRegex(M11SessionCodecError, "maker barrier"):
            verify_m11_replay(altered, snapshot, executable_path="runtime", runtime=Mock())

    def test_verify_rejects_unproven_terminal_claim(self) -> None:
        snapshot = self.snapshot()
        commands = (BattleWait(0),)
        built = build_m11_replay(snapshot, commands, engine_build="build-42",
                                 command_trace=self.trace(commands))
        altered = ReplayFile(built.header, built.commands, terminal=True)
        with self.assertRaisesRegex(M11SessionCodecError, "terminal result"):
            verify_m11_replay(altered, snapshot, executable_path="runtime", runtime=Mock())

    def test_replay_carries_and_revalidates_authoritative_restore_anchor(self) -> None:
        snapshot = self.snapshot()
        world = WorldSnapshot(1, 1024, 0, 1024, None, 0, 0, 0,
                              snapshot.rng_state, (), ())
        commands = (AdvanceDialogue(),)
        trace = self.trace(commands)
        replay = build_m11_replay(snapshot, commands, engine_build="build-42",
                                  command_trace=trace, restore_snapshot=world)
        response = RuntimeResponse("accepted", snapshot.content_hash, 1,
                                   None, (), None, None, None,
                                   command_trace=trace)
        runtime = Mock(return_value=response)
        verify_m11_replay(replay, snapshot, executable_path="runtime", runtime=runtime)
        runtime.assert_called_once_with(snapshot, (AdvanceDialogue(),),
                                        executable_path="runtime", restore_snapshot=world)

    def test_postbattle_progression_anchor_round_trips_and_binds_content_identity(self) -> None:
        snapshot = self.snapshot()
        world = WorldSnapshot(1, 1024, 0, 1024, None, 0, 0, 0,
                              snapshot.rng_state, (), ())
        capacity = {"party": 12, "moves": 8, "storage": 10000,
                    "stack": 9999, "entries": 4096, "currency": 999999999}
        progression = decode_m11_progression({
            "economy": {"capacity": capacity, "tier": 0, "party": 0,
                         "storage": 0, "equippedMoves": 0, "currency": 0,
                         "inventory": []},
            "roster": {"capacity": capacity, "party": [], "storage": []},
            "owned": [], "ledger": {"completedEncounters": [7]},
            "ruleset": 7, "contentIdentity": int(snapshot.content_hash[:8], 16),
        })
        commands = (AdvanceBattle(),)
        trace = self.trace(commands)
        replay = build_m11_replay(snapshot, commands, engine_build="build-42",
                                  command_trace=trace, restore_snapshot=world,
                                  restore_progression=progression)
        self.assertEqual(replay.header.initial_state["restoreProgression"]["ledger"],
                         {"completedEncounters": [7]})
        response = RuntimeResponse("accepted", snapshot.content_hash, 1,
                                   None, (), None, None, None, command_trace=trace)
        runtime = Mock(return_value=response)
        verify_m11_replay(replay, snapshot, executable_path="runtime", runtime=runtime)
        runtime.assert_called_once_with(snapshot, commands, executable_path="runtime",
                                        restore_snapshot=world,
                                        restore_progression=progression)

        altered_initial = dict(replay.header.initial_state)
        altered_progression = dict(altered_initial["restoreProgression"])
        altered_progression["contentIdentity"] ^= 1
        altered_initial["restoreProgression"] = altered_progression
        altered = ReplayFile(replace(replay.header, initial_state=altered_initial),
                             replay.commands)
        with self.assertRaisesRegex(M11SessionCodecError, "identity"):
            verify_m11_replay(altered, snapshot, executable_path="runtime", runtime=Mock())


if __name__ == "__main__":
    unittest.main()
