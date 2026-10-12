from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))
from maker.service import MakerError, MakerService, decode_request
from maker.playtest import PlaytestUnavailable
from maker.runtime_response import RuntimeResponse
from content.m10_command_wire import Activate, ContinueEvent, Move, Traverse
from content.loader import load_project
sys.path.insert(0, str(ROOT / "scripts"))
from run_m10_maker import BROWSER_FILES, browser_asset


class MakerServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="m10-maker-")
        self.service = MakerService(Path(self.temp.name) / "projects")
        self.created = self.service.create_project("Fresh meadow")
        self.project_id = self.created["project"]["id"]

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_create_open_validate_and_export_valid_project(self) -> None:
        project = self.created["project"]
        self.assertEqual(project["name"], "Fresh meadow")
        self.assertEqual(self.service.validate_project(self.project_id)["valid"], True)
        opened = self.service.open_project(self.project_id)["project"]
        self.assertEqual(opened["documents"], project["documents"])
        exported = self.service.export_project(self.project_id)
        self.assertTrue(exported["valid"])
        self.assertEqual(load_project(exported["exportPath"]).content_hash, exported["contentHash"])

    def test_invalid_draft_saves_and_returns_field_diagnostic_but_cannot_export(self) -> None:
        docs = dict(self.created["project"]["documents"])
        docs["project.json"] = dict(docs["project.json"], entryMap="original:missing")
        self.service.save_documents(self.project_id, docs)
        result = self.service.validate_project(self.project_id)
        self.assertFalse(result["valid"])
        self.assertEqual(result["diagnostics"][0]["file"], "project.json")
        self.assertEqual(result["diagnostics"][0]["pointer"], "/entryMap")
        self.assertFalse(self.service.export_project(self.project_id)["valid"])

    def test_document_save_is_all_or_nothing_on_write_failure(self) -> None:
        before = self.service.open_project(self.project_id)["project"]["documents"]
        changed = dict(before["project.json"], name="changed")
        with patch.object(self.service, "_replace_documents", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                self.service.save_documents(self.project_id, {"project.json": changed})
        self.assertEqual(self.service.open_project(self.project_id)["project"]["documents"], before)

    def test_hostile_paths_duplicate_json_and_size_are_rejected(self) -> None:
        for value in ("../project.json", "/project.json", "a/../project.json", "x\\y.json"):
            with self.subTest(path=value), self.assertRaises(MakerError):
                self.service.save_documents(self.project_id, {value: {}})
        with self.assertRaises(MakerError):
            decode_request(b'{"a":1,"a":2}')
        with self.assertRaises(MakerError):
            self.service.save_documents(self.project_id, {"project.json": {"__proto__": {}}})
        with self.assertRaises(MakerError):
            decode_request(b" " * 10, 5)

    def test_asset_import_updates_digest_and_bytes_atomically(self) -> None:
        data = (ROOT / "examples/original-demo/assets/mosskip.ppm").read_bytes()
        result = self.service.import_asset(self.project_id, "assets/imported.ppm",
                                           "image/x-portable-pixmap", base64.b64encode(data).decode())
        project = self.service.project_path(self.project_id)
        manifest = json.loads((project / "manifest.json").read_text())
        asset = manifest["assets"][-1]
        self.assertEqual(asset["sha256"], hashlib.sha256(data).hexdigest())
        self.assertEqual((project / asset["path"]).read_bytes(), data)
        self.assertEqual(self.service.validate_project(self.project_id)["valid"], True)
        self.assertIn(result["assetId"], [item["id"] for item in manifest["assets"]])

    def test_bad_asset_media_and_content_are_rejected_without_changes(self) -> None:
        manifest = self.service.project_path(self.project_id) / "manifest.json"
        before = manifest.read_bytes()
        with self.assertRaises(MakerError):
            self.service.import_asset(self.project_id, "assets/run.js", "application/javascript", "YWJj")
        with self.assertRaises(MakerError):
            self.service.import_asset(self.project_id, "assets/bad.ppm", "image/x-portable-pixmap", "%%%")
        self.assertEqual(manifest.read_bytes(), before)

    def test_document_save_removes_omitted_json_and_preserves_assets(self) -> None:
        project_root = self.service.project_path(self.project_id)
        asset = (project_root / "assets/mosskip.ppm").read_bytes()
        docs = dict(self.created["project"]["documents"])
        docs["maps/unused.json"] = {"draft": True}
        self.service.save_documents(self.project_id, docs)
        self.assertFalse(self.service.validate_project(self.project_id)["valid"])
        self.service.save_documents(self.project_id, self.created["project"]["documents"])
        self.assertFalse((project_root / "maps/unused.json").exists())
        self.assertEqual((project_root / "assets/mosskip.ppm").read_bytes(), asset)
        self.assertTrue(self.service.validate_project(self.project_id)["valid"])

    def test_static_browser_is_served_from_allowlist_only(self) -> None:
        self.assertEqual(set(BROWSER_FILES), {"/", "/index.html", "/main.mjs", "/state.mjs",
                                               "/forms.mjs", "/map.mjs", "/styles.css"})
        for route, (_filename, expected) in BROWSER_FILES.items():
            content_type, payload = browser_asset(route)
            self.assertTrue(content_type.startswith(expected.split(";")[0]))
            self.assertTrue(payload)
        for route in ("/../scripts/run_m10_maker.py", "/%2e%2e/scripts/run_m10_maker.py", "/secret.txt"):
            with self.assertRaises(MakerError):
                browser_asset(route)

    def test_export_uses_validated_frozen_copy_when_source_changes_during_export(self) -> None:
        original = self.service.project_path(self.project_id)
        real_copytree = shutil.copytree

        def mutate_after_copy(source: Path, destination: Path, *args: object, **kwargs: object) -> Path:
            result = real_copytree(source, destination, *args, **kwargs)
            if Path(source) == original:
                doc = json.loads((original / "project.json").read_text())
                doc["name"] = "changed after frozen copy"
                (original / "project.json").write_text(json.dumps(doc))
            return result

        with patch("maker.service.shutil.copytree", side_effect=mutate_after_copy):
            output = self.service.export_project(self.project_id)
        self.assertTrue(output["valid"])
        self.assertNotEqual(load_project(output["exportPath"]).project.name, "changed after frozen copy")

    def test_export_rejects_untrusted_existing_hash_path(self) -> None:
        project = self.service.project_path(self.project_id)
        digest = load_project(project).content_hash
        target = self.service.root / "exports" / f"{self.project_id}-{digest}"
        target.parent.mkdir(exist_ok=True)
        target.symlink_to(self.service.root)
        with self.assertRaisesRegex(MakerError, "existing export path"):
            self.service.export_project(self.project_id)
        self.assertTrue(target.is_symlink())

    def test_playtest_reports_missing_generic_runtime_after_exact_freeze(self) -> None:
        digest = load_project(self.service.project_path(self.project_id)).content_hash
        with self.assertRaisesRegex(MakerError, "generic validated-content"):
            self.service.playtest_project(self.project_id, [1, 2, 3, 4], 60, digest)
        frozen = self.service.root / "exports" / f"{self.project_id}-{digest}"
        self.assertEqual(load_project(frozen).content_hash, digest)
        with self.assertRaisesRegex(MakerError, "validate again"):
            self.service.playtest_project(self.project_id, [1, 2, 3, 4], 60, "0" * 64)

    def _configured_playtest(self, *, clock=None):
        runtime = Path(self.temp.name) / "compiled-m10"
        runtime.write_bytes(b"precompiled test binary")
        runtime.chmod(0o755)
        service = MakerService(Path(self.temp.name) / "runtime-projects",
            template_root=ROOT / "examples/m8-world", runtime_path=runtime,
            **({} if clock is None else {"clock": clock}))
        project_id = service.create_project("Runtime meadow")["project"]["id"]
        documents = service.open_project(project_id)["project"]["documents"]
        documents["project.json"]["entryPoint"] = {"x": 1024, "y": 0, "z": 1024}
        service.save_documents(project_id, documents)
        digest = service.validate_project(project_id)["contentHash"]
        return service, project_id, digest, runtime

    @staticmethod
    def _runtime_response(snapshot, status: str, count: int,
                         scene_x: int = 0) -> RuntimeResponse:
        identity = int(snapshot.content_hash[:8], 16)
        scene = f"1,{identity},1," + ",".join(
            ["0", str(scene_x), "0", "0", "0", "0", "0", "0", "0",
             str(scene_x), "0", "0", "0", "0", "0"])
        return RuntimeResponse(status, snapshot.content_hash, count, None, (),
                               None, scene, "1,0")

    def test_configured_runtime_starts_frozen_session_and_returns_presentation(self) -> None:
        service, project_id, digest, runtime = self._configured_playtest()
        calls = []

        def fake_run(snapshot, commands, *, executable_path):
            calls.append((snapshot, commands, executable_path))
            return self._runtime_response(snapshot, "accepted", 0)

        with patch("maker.service.run_runtime", side_effect=fake_run):
            result = service.playtest_project(project_id, [1, 2, 3, 4], 60, digest)
        self.assertEqual((result["ok"], result["contentHash"], result["status"],
                          result["acceptedCommands"]), (True, digest, "accepted", 0))
        self.assertRegex(result["sessionId"], r"^[a-f0-9]{32}$")
        self.assertTrue(result["sceneCsv"].startswith(
            f"1,{int(digest[:8], 16)},1,"))
        self.assertEqual(result["cuesCsv"], "1,0")
        self.assertIsNone(result["encounterId"])
        self.assertEqual(len(result["presentation"]["maps"]), 1)
        self.assertEqual(calls, [(calls[0][0], (), runtime)])

    def test_step_replays_candidate_and_commits_only_accepted_commands(self) -> None:
        service, project_id, digest, _runtime = self._configured_playtest()
        calls = []

        def fake_run(snapshot, commands, *, executable_path):
            calls.append(commands)
            if not commands:
                return self._runtime_response(snapshot, "accepted", 0)
            if len(calls) == 3:
                return RuntimeResponse("rejected", snapshot.content_hash, 0,
                                       None, (), None, None, None)
            return self._runtime_response(snapshot, "accepted", len(commands),
                                          len(commands))

        with patch("maker.service.run_runtime", side_effect=fake_run):
            initial = service.playtest_project(project_id, [1, 2, 3, 4], 60, digest)
            first = service.step_playtest(initial["sessionId"],
                {"kind": "move", "x": 32, "z": 0,
                 "analog": False, "sprint": False}, 0)
            rejected = service.step_playtest(initial["sessionId"], Activate(1), 1)
            final = service.step_playtest(initial["sessionId"], Traverse(1), 1)
        self.assertEqual((first["acceptedCommands"], first["status"]), (1, "accepted"))
        self.assertEqual(rejected["rejected"], True)
        self.assertEqual(rejected["status"], "rejected")
        self.assertEqual(rejected["acceptedCommands"], 1)
        self.assertEqual(rejected["sceneCsv"], first["sceneCsv"])
        self.assertEqual(rejected["cuesCsv"], "1,0")
        self.assertEqual((final["acceptedCommands"], final["status"]), (2, "accepted"))
        self.assertEqual(len(calls), 4)
        self.assertEqual(calls[0], ())
        self.assertIsInstance(calls[1][0], Move)
        self.assertEqual((calls[1][0].x.magnitude, calls[1][0].z.magnitude),
                         (32, 0))
        self.assertEqual(calls[2], (calls[1][0], Activate(1)))
        self.assertEqual(calls[3], (calls[1][0], Traverse(1)))

    def test_step_requires_expected_accepted_count(self) -> None:
        service, project_id, digest, _runtime = self._configured_playtest()
        with patch("maker.service.run_runtime", side_effect=lambda snapshot, commands,
                   executable_path: self._runtime_response(snapshot, "accepted", len(commands))):
            started = service.playtest_project(project_id, [1, 2, 3, 4], 60, digest)
            with self.assertRaisesRegex(MakerError, "expectedCommands"):
                service.step_playtest(started["sessionId"], ContinueEvent(), 1)

    def test_sessions_expire_and_session_capacity_is_bounded(self) -> None:
        now = [0.0]
        service, project_id, digest, _runtime = self._configured_playtest(
            clock=lambda: now[0])
        with patch("maker.service.run_runtime", side_effect=lambda snapshot, commands,
                   executable_path: self._runtime_response(snapshot, "accepted", len(commands))):
            started = service.playtest_project(project_id, [1, 2, 3, 4], 60, digest)
            now[0] = 3600.0
            with self.assertRaisesRegex(MakerError, "expired"):
                service.step_playtest(started["sessionId"], ContinueEvent(), 0)
        with service._session_lock:
            class ActiveSession:
                last_access = now[0]
            service._sessions.update({f"{index:032x}": ActiveSession()
                                      for index in range(32)})
        with self.assertRaisesRegex(MakerError, "32"):
            service._reserve_session_slot()


if __name__ == "__main__":
    unittest.main()
