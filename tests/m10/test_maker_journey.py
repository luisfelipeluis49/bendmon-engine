"""A created project reaches the precompiled world runtime through the maker."""
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

from maker.service import MakerError, MakerService
from presentation.wire import parse_scene


class MakerJourneyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.build_dir = tempfile.TemporaryDirectory(prefix="m10-journey-binary-")
        cls.runtime = Path(cls.build_dir.name) / "runtime"
        subprocess.run([sys.executable, str(ROOT / "scripts/build_m10_runtime.py"),
                        "--output", str(cls.runtime)], cwd=ROOT, check=True,
                       capture_output=True, text=True, timeout=300)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.build_dir.cleanup()

    def setUp(self) -> None:
        self.workspace = tempfile.TemporaryDirectory(prefix="m10-journey-")
        self.addCleanup(self.workspace.cleanup)
        root = Path(self.workspace.name)
        template = root / "template"
        shutil.copytree(ROOT / "examples/m8-world", template)
        project_file = template / "project.json"
        project = json.loads(project_file.read_text(encoding="utf-8"))
        project["entryPoint"] = {"x": 1024, "y": 0, "z": 1024}
        project_file.write_text(json.dumps(project), encoding="utf-8")
        self.service = MakerService(root / "projects", template_root=template,
                                    runtime_path=self.runtime)

    def test_create_validate_play_move_and_reject_idle_event_step(self) -> None:
        created = self.service.create_project("Fresh section")
        project_id = created["project"]["id"]
        checked = self.service.validate_project(project_id)
        self.assertTrue(checked["valid"], checked.get("diagnostics"))
        started = self.service.playtest_project(project_id, [1, 2, 3, 4], 60,
                                                checked["contentHash"])
        self.assertEqual(started["status"], "accepted")
        initial = parse_scene(started["sceneCsv"])
        self.assertEqual(initial.map_id, 1)
        moved = self.service.step_playtest(started["sessionId"],
            {"kind": "move", "x": 512, "z": 0,
             "analog": False, "sprint": False}, 0)
        self.assertEqual(moved["acceptedCommands"], 1)
        self.assertGreater(parse_scene(moved["sceneCsv"]).x, initial.x)
        with self.assertRaisesRegex(MakerError, "expectedCommands"):
            self.service.step_playtest(started["sessionId"],
                {"kind": "continueEvent"}, 0)
        rejected = self.service.step_playtest(started["sessionId"],
                                               {"kind": "continueEvent"}, 1)
        self.assertTrue(rejected["rejected"])
        self.assertEqual(rejected["sceneCsv"], moved["sceneCsv"])
        self.assertEqual(rejected["acceptedCommands"], 1)

    def test_distant_npc_interaction_rejects_without_runtime_overflow(self) -> None:
        created = self.service.create_project("Distant NPC")
        project_id = created["project"]["id"]
        opened = self.service.open_project(project_id)
        documents = opened["project"]["documents"]
        documents["project.json"]["entryPoint"] = {"x": 30000, "y": 0, "z": 2000}
        self.service.save_documents(project_id, documents)
        checked = self.service.validate_project(project_id)
        self.assertTrue(checked["valid"], checked.get("diagnostics"))
        started = self.service.playtest_project(project_id, [1, 2, 3, 4], 60,
                                                checked["contentHash"])
        rejected = self.service.step_playtest(started["sessionId"],
            {"kind": "interact", "npcId": 1, "facingX": -1024,
             "facingZ": -1024}, 0)
        self.assertTrue(rejected["rejected"])
        self.assertEqual(rejected["acceptedCommands"], 0)

    def test_near_npc_interaction_runs_authored_event(self) -> None:
        created = self.service.create_project("Nearby NPC")
        project_id = created["project"]["id"]
        documents = self.service.open_project(project_id)["project"]["documents"]
        documents["project.json"]["entryPoint"] = {"x": 512, "y": 0, "z": 512}
        self.service.save_documents(project_id, documents)
        checked = self.service.validate_project(project_id)
        self.assertTrue(checked["valid"], checked.get("diagnostics"))
        started = self.service.playtest_project(project_id, [1, 2, 3, 4], 60,
                                                checked["contentHash"])
        interacted = self.service.step_playtest(started["sessionId"],
            {"kind": "interact", "npcId": 1, "facingX": 1024,
             "facingZ": 1024}, 0)
        self.assertEqual(interacted["acceptedCommands"], 1)
        self.assertEqual(interacted["status"], "accepted")
        advanced = interacted
        for expected in range(1, 3):
            advanced = self.service.step_playtest(started["sessionId"],
                                                   {"kind": "continueEvent"}, expected)
        self.assertEqual(advanced["acceptedCommands"], 3)
        self.assertNotEqual(advanced["cuesCsv"], started["cuesCsv"])

    def test_default_creator_template_is_playable_without_source_edits(self) -> None:
        service = MakerService(Path(self.workspace.name) / "default-projects",
                               runtime_path=self.runtime)
        created = service.create_project("My first route")
        project_id = created["project"]["id"]
        checked = service.validate_project(project_id)
        self.assertTrue(checked["valid"], checked.get("diagnostics"))
        started = service.playtest_project(project_id, [1, 2, 3, 4], 60,
                                           checked["contentHash"])
        self.assertEqual(started["status"], "accepted")
        self.assertEqual(started["acceptedCommands"], 0)

    def test_default_creator_talks_through_authored_dialogue(self) -> None:
        service = MakerService(Path(self.workspace.name) / "dialogue-projects",
                               runtime_path=self.runtime)
        project_id = service.create_project("Guide encounter")["project"]["id"]
        checked = service.validate_project(project_id)
        self.assertTrue(checked["valid"], checked.get("diagnostics"))
        result = service.playtest_project(project_id, [1, 2, 3, 4], 60,
                                          checked["contentHash"])
        result = service.step_playtest(result["sessionId"],
            {"kind": "interact", "npcId": 1, "facingX": 1024, "facingZ": 0}, 0)
        self.assertEqual(result["dialogue"]["text"],
                         "Welcome to Mosslight Glade.")
        result = service.step_playtest(result["sessionId"],
            {"kind": "advanceDialogue"}, 1)
        self.assertEqual(result["dialogue"]["text"],
                         "The grass ahead is home to wild Mosskip.")
        result = service.step_playtest(result["sessionId"],
            {"kind": "advanceDialogue"}, 2)
        self.assertIsNone(result["dialogue"])
        self.assertEqual(result["acceptedCommands"], 3)

    def test_default_creator_reaches_authored_encounter(self) -> None:
        service = MakerService(Path(self.workspace.name) / "encounter-projects",
                               runtime_path=self.runtime)
        project_id = service.create_project("Meadow encounter")["project"]["id"]
        checked = service.validate_project(project_id)
        self.assertTrue(checked["valid"], checked.get("diagnostics"))
        result = service.playtest_project(project_id, [1, 2, 3, 4], 60,
                                          checked["contentHash"])
        for index in range(256):
            result = service.step_playtest(result["sessionId"],
                {"kind": "move", "x": 1024 if index % 2 == 0 else -1024,
                 "z": 0, "analog": False, "sprint": True},
                result["acceptedCommands"])
            if result["status"] == "battle":
                break
            self.assertFalse(result.get("rejected"), result)
        self.assertEqual(result["status"], "battle")
        self.assertEqual(result["encounterId"], 1)
        self.assertIsNotNone(parse_scene(result["sceneCsv"]).battle)
        for command in ({"kind": "battleEscape", "actorId": 0},
                        {"kind": "advanceBattle"},
                        {"kind": "advanceBattle"},
                        {"kind": "battleEscape", "actorId": 0},
                        {"kind": "advanceBattle"}):
            result = service.step_playtest(result["sessionId"], command,
                                            result["acceptedCommands"])
            self.assertFalse(result.get("rejected"), result)
        self.assertEqual(result["status"], "accepted")
        self.assertIsNone(parse_scene(result["sceneCsv"]).battle)
        returned_x = parse_scene(result["sceneCsv"]).x
        result = service.step_playtest(result["sessionId"],
            {"kind": "move", "x": 512, "z": 0,
             "analog": False, "sprint": False}, result["acceptedCommands"])
        self.assertEqual(result["status"], "accepted")
        self.assertGreater(parse_scene(result["sceneCsv"]).x, returned_x)


if __name__ == "__main__":
    unittest.main()
