"""Subprocess acceptance tests for the M10 Bend runtime response contract."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m10_command_wire import (AdvanceBattle, AdvanceDialogue,
                                      BattleEscape, BattleMove, BattleWait,
                                      Interact, Move)
from content.m8_binding import SignedCoord
from maker.playtest import freeze_project, prepare_runtime_wires
from maker.runtime_request import assemble_runtime_request
from maker.runtime_process import run_runtime
from maker.m11_session_codec import build_m11_replay, verify_m11_replay
from maker.runtime_response import parse_runtime_response
from presentation.wire import parse_cues, parse_scene


class DynamicRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temp = tempfile.TemporaryDirectory(prefix="m10-dynamic-runtime-")
        cls.root = Path(cls.temp.name)
        cls.binary = cls.root / "dynamic-runtime"
        subprocess.run([sys.executable, str(ROOT / "scripts/build_m10_runtime.py"),
                        "--output", str(cls.binary)], cwd=ROOT, check=True,
                       capture_output=True, text=True, timeout=300)
        cls.project = cls.root / "project"
        shutil.copytree(ROOT / "examples/m8-world", cls.project)
        project_file = cls.project / "project.json"
        project = json.loads(project_file.read_text(encoding="utf-8"))
        project["entryPoint"] = {"x": 1024, "y": 0, "z": 1024}
        project_file.write_text(json.dumps(project), encoding="utf-8")
        snapshot = freeze_project(cls.project, rng_state=(1, 2, 3, 4),
                                  wait_ticks=60)
        cls.wires = prepare_runtime_wires(snapshot)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp.cleanup()

    def run_payload(self, payload: bytes) -> subprocess.CompletedProcess[str]:
        request = self.root / "request.txt"
        request.write_bytes(payload)
        return subprocess.run([str(self.binary), str(request)], cwd=ROOT,
                              capture_output=True, text=True, timeout=10)

    def test_frozen_authored_entrypoint_runs_through_join_boot_and_replay(self) -> None:
        request = assemble_runtime_request(self.wires,
            (Move(SignedCoord(False, 512), SignedCoord(False, 0), False, False),))
        result = self.run_payload(request.payload)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        identity = int(self.wires.content_hash[:8], 16)
        lines = result.stdout.splitlines()
        self.assertEqual(lines[:3], ["M10PLAY2 ACCEPTED", f"IDENTITY {identity}",
                                     "COMMANDS 1"])
        self.assertEqual(len(lines), 10)
        self.assertEqual(lines[3], "DIALOGUE 0 0 1")
        self.assertTrue(lines[4].startswith("SCENE "))
        self.assertTrue(lines[5].startswith("CUES "))
        self.assertTrue(lines[6].startswith("SAVE "))
        self.assertEqual(lines[7], "PROGRESSION 0")
        self.assertEqual(lines[8], "TRACE 2,1")
        self.assertEqual(lines[9], "TRACE_STEP 0,0,0,0")
        response = parse_runtime_response(result.stdout,
                                          expected_content_hash=self.wires.content_hash,
                                          expected_commands=1)
        self.assertIsNotNone(response.save_snapshot)
        self.assertEqual(tuple((step.command_index, step.logical_tick)
                               for step in response.command_trace), ((0, 0),))
        scene = parse_scene(lines[4][6:])
        self.assertEqual((scene.content_identity, scene.map_id, scene.facing),
                         (identity, 1, 0))
        self.assertEqual((scene.x, scene.y, scene.z), (1062, 0, 1024))
        self.assertEqual(scene.camera_anchor, (1062, 0, 1024))
        self.assertEqual(len(scene.npcs), 1)
        self.assertEqual(parse_cues(lines[5][5:]), ())

    def test_rejects_extra_rows_and_multiple_trailing_newlines(self) -> None:
        request = assemble_runtime_request(self.wires, ())
        for suffix in (b"unexpected\n", b"\n"):
            with self.subTest(suffix=suffix):
                result = self.run_payload(request.payload + suffix)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "M10PLAY2 REJECTED\n")
                self.assertEqual(result.stderr, "")

    def test_starter_npc_dialogue_advances_and_closes(self) -> None:
        snapshot = freeze_project(ROOT / "examples/m10-starter",
                                  rng_state=(1, 2, 3, 4), wait_ticks=60)
        wires = prepare_runtime_wires(snapshot)
        talk = Interact(1, SignedCoord(False, 1024), SignedCoord(False, 0))
        for commands, expected in (
                ((talk,), (1, 0, False)),
                ((talk, AdvanceDialogue()), (1, 1, False)),
                ((talk, AdvanceDialogue(), AdvanceDialogue()), (1, 1, True))):
            with self.subTest(commands=len(commands)):
                request = assemble_runtime_request(wires, commands)
                result = self.run_payload(request.payload)
                response = parse_runtime_response(
                    result.stdout, expected_content_hash=snapshot.content_hash,
                    expected_commands=len(commands))
                self.assertEqual((response.dialogue_id,
                                  response.dialogue_line_index,
                                  response.dialogue_closed), expected)

    def test_starter_encounter_enters_real_m7_battle_scene(self) -> None:
        snapshot = freeze_project(ROOT / "examples/m10-starter",
                                  rng_state=(1, 2, 3, 4), wait_ticks=60)
        commands = tuple(Move(SignedCoord(index % 2 == 1, 1024),
                              SignedCoord(False, 0), False, True)
                         for index in range(203))
        request = assemble_runtime_request(prepare_runtime_wires(snapshot), commands)
        response = parse_runtime_response(
            self.run_payload(request.payload).stdout,
            expected_content_hash=snapshot.content_hash,
            expected_commands=len(commands))
        self.assertEqual((response.status, response.encounter_id), ("battle", 1))
        self.assertIsNotNone(response.scene.battle)
        advanced = commands + (AdvanceBattle(),)
        next_request = assemble_runtime_request(prepare_runtime_wires(snapshot),
                                                advanced)
        next_response = parse_runtime_response(
            self.run_payload(next_request.payload).stdout,
            expected_content_hash=snapshot.content_hash,
            expected_commands=len(advanced))
        self.assertEqual(next_response.status, "battle")
        self.assertIsNotNone(next_response.scene.battle)
        returned = commands + (BattleEscape(0), AdvanceBattle(),
                               AdvanceBattle(), BattleEscape(0),
                               AdvanceBattle())
        return_request = assemble_runtime_request(prepare_runtime_wires(snapshot),
                                                  returned)
        return_response = parse_runtime_response(
            self.run_payload(return_request.payload).stdout,
            expected_content_hash=snapshot.content_hash,
            expected_commands=len(returned))
        self.assertEqual(return_response.status, "accepted")
        self.assertIsNone(return_response.scene.battle)
        self.assertIsNotNone(return_response.save_snapshot)
        self.assertIsNotNone(return_response.progression)
        self.assertEqual(len(return_response.command_trace), len(returned))
        ticks = tuple(step.logical_tick for step in return_response.command_trace)
        self.assertEqual(ticks, tuple(sorted(ticks)))
        self.assertGreater(ticks[-1], ticks[0])
        restored = run_runtime(snapshot, (), executable_path=self.binary,
                               restore_snapshot=return_response.save_snapshot,
                               restore_progression=return_response.progression)
        self.assertEqual(restored.save_snapshot, return_response.save_snapshot)
        self.assertEqual(restored.progression, return_response.progression)
        continued = run_runtime(snapshot,
            (Move(SignedCoord(False, 512), SignedCoord(False, 0),
                  False, False),), executable_path=self.binary,
            restore_snapshot=return_response.save_snapshot,
            restore_progression=return_response.progression)
        self.assertEqual(continued.status, "accepted")
        self.assertEqual(continued.progression, return_response.progression)
        self.assertGreater(continued.scene.x, return_response.scene.x)
        second_approach = tuple(
            Move(SignedCoord(index % 2 == 1, 1024),
                 SignedCoord(False, 0), False, True)
            for index in range(317))
        second = run_runtime(snapshot, second_approach,
                             executable_path=self.binary,
                             restore_snapshot=return_response.save_snapshot,
                             restore_progression=return_response.progression)
        self.assertEqual(second.status, "battle")
        self.assertIsNotNone(second.scene.battle)
        self.assertEqual(len(second.command_trace), len(second_approach))
        saved_hp = return_response.progression.owned[0].individual.current_hp
        self.assertEqual(next(actor.hp for actor in second.scene.battle.actors
                              if actor.id == 0), saved_hp)
        replay = build_m11_replay(snapshot, second_approach,
                                  engine_build="m11-1",
                                  command_trace=second.command_trace,
                                  restore_snapshot=return_response.save_snapshot,
                                  restore_progression=return_response.progression)
        verified = verify_m11_replay(replay, snapshot,
                                     executable_path=str(self.binary))
        self.assertEqual(verified.response.status, "battle")
        moved = returned + (Move(SignedCoord(False, 512),
                                 SignedCoord(False, 0), False, False),)
        move_request = assemble_runtime_request(prepare_runtime_wires(snapshot),
                                                moved)
        move_response = parse_runtime_response(
            self.run_payload(move_request.payload).stdout,
            expected_content_hash=snapshot.content_hash,
            expected_commands=len(moved))
        self.assertEqual(move_response.status, "accepted")
        self.assertGreater(move_response.scene.x, return_response.scene.x)

    def test_authored_move_damages_wild_target_after_battle_advance(self) -> None:
        snapshot = freeze_project(ROOT / "examples/m10-starter",
                                  rng_state=(1, 2, 3, 4), wait_ticks=60)
        wires = prepare_runtime_wires(snapshot)
        approach = tuple(Move(SignedCoord(index % 2 == 1, 1024),
                              SignedCoord(False, 0), False, True)
                         for index in range(203))

        def play(commands):
            request = assemble_runtime_request(wires, commands)
            return parse_runtime_response(self.run_payload(request.payload).stdout,
                expected_content_hash=snapshot.content_hash,
                expected_commands=len(commands))

        entered = play(approach)
        self.assertEqual(entered.status, "battle")
        initial_hp = next(actor.hp for actor in entered.scene.battle.actors
                          if actor.id == 1)
        submitted = play(approach + (BattleMove(0, 1, 1),))
        self.assertEqual(submitted.status, "battle")
        self.assertEqual(next(actor.hp for actor in submitted.scene.battle.actors
                              if actor.id == 1), initial_hp)
        self.assertTrue(submitted.command_trace[-1].enemy_wait)
        battle_commands = approach + (BattleMove(0, 1, 1),)
        battle_replay = build_m11_replay(snapshot, battle_commands,
                                         engine_build="m11-1",
                                         command_trace=submitted.command_trace)
        self.assertEqual(len(battle_replay.commands), len(battle_commands) + 1)
        self.assertEqual(battle_replay.commands[-1].payload,
                         {"kind": "battleWait", "actorId": 1})
        self.assertEqual(verify_m11_replay(
            battle_replay, snapshot, executable_path=str(self.binary)
        ).response.command_trace, submitted.command_trace)
        resolved = play(approach + (BattleMove(0, 1, 1), AdvanceBattle()))
        self.assertEqual(resolved.status, "battle")
        self.assertLess(next(actor.hp for actor in resolved.scene.battle.actors
                             if actor.id == 1), initial_hp)

    def test_authored_effect_program_applies_damage_and_recoil(self) -> None:
        project = self.root / "effect-project"
        shutil.copytree(ROOT / "examples/m10-starter", project)
        move_file = next((project / "moves").glob("*.json"))
        move = json.loads(move_file.read_text(encoding="utf-8"))
        del move["power"]
        move["priority"] = 2
        move["effects"] = [
            {"kind": "damage", "target": "target", "category": "special",
             "power": 80},
            {"kind": "recoil", "target": "source", "fromNode": 0,
             "numerator": 1, "denominator": 2},
        ]
        move_file.write_text(json.dumps(move), encoding="utf-8")
        snapshot = freeze_project(project, rng_state=(1, 2, 3, 4), wait_ticks=60)
        wires = prepare_runtime_wires(snapshot)
        approach = tuple(Move(SignedCoord(index % 2 == 1, 1024),
                              SignedCoord(False, 0), False, True)
                         for index in range(203))

        def play(commands):
            request = assemble_runtime_request(wires, commands)
            return parse_runtime_response(self.run_payload(request.payload).stdout,
                expected_content_hash=snapshot.content_hash,
                expected_commands=len(commands))

        entered = play(approach)
        resolved = play(approach + (BattleMove(0, 1, 1), AdvanceBattle()))
        self.assertEqual((entered.status, resolved.status), ("battle", "battle"))
        before = {actor.id: actor.hp for actor in entered.scene.battle.actors}
        after = {actor.id: actor.hp for actor in resolved.scene.battle.actors}
        self.assertLess(after[1], before[1])
        self.assertLess(after[0], before[0])
        # The enemy may be Ready while actor 0 is recovering. Advance must
        # supply its trusted wait so the command barrier cannot deadlock.
        finished = play(approach + (BattleMove(0, 1, 1), AdvanceBattle(),
            AdvanceBattle(), BattleWait(0), AdvanceBattle(), AdvanceBattle(),
            BattleMove(0, 1, 1), AdvanceBattle()))
        self.assertEqual(finished.status, "accepted")
        self.assertIsNone(finished.scene.battle)
        self.assertIsNotNone(finished.progression)
        self.assertEqual(len(finished.progression.owned), 1)
        self.assertGreater(finished.progression.owned[0].individual.xp, 0)


if __name__ == "__main__":
    unittest.main()
