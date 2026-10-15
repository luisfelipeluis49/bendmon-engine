"""Build, verify, tamper-check and launch the copied M11 package."""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import package_m11
import verify_m11_package


class M11PackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temporary = tempfile.TemporaryDirectory(prefix="m11-package-test-")
        cls.root = Path(cls.temporary.name)
        cls.package = package_m11.package(cls.root / "package")

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temporary.cleanup()

    def test_package_manifest_and_starter_are_verified(self) -> None:
        report = verify_m11_package.verify(self.package)
        self.assertTrue(report["ok"])
        self.assertEqual(report["target"], "linux-x86_64")
        manifest = json.loads((self.package / "package.json").read_text())
        self.assertGreaterEqual(len(manifest["files"]), 30)
        self.assertEqual(report["contentHash"], manifest["contentHash"])

    def test_altered_file_extra_file_and_unsafe_manifest_path_reject(self) -> None:
        target = self.package / "build/content-kernel"
        original = target.read_bytes()
        try:
            target.write_bytes(original + b"tampered")
            with self.assertRaisesRegex(ValueError, "size mismatch"):
                verify_m11_package.verify(self.package)
        finally:
            target.write_bytes(original)
            target.chmod(0o755)
        extra = self.package / "unexpected.bin"
        extra.write_bytes(b"extra")
        try:
            with self.assertRaisesRegex(ValueError, "file set differs"):
                verify_m11_package.verify(self.package)
        finally:
            extra.unlink()
        manifest_path = self.package / "package.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["files"][0]["path"] = "../escape"
        manifest_path.write_text(json.dumps(manifest))
        try:
            with self.assertRaisesRegex(ValueError, "unsafe path"):
                verify_m11_package.verify(self.package)
        finally:
            # Reassemble the canonical package manifest after the negative check.
            package_m11.package(self.root / "restored")
            shutil.rmtree(self.package)
            os.replace(self.root / "restored", self.package)

    def test_copy_launches_service_and_runs_starter_playtest(self) -> None:
        clean = self.root / "clean-install" / "bend-maker"
        clean.parent.mkdir()
        shutil.copytree(self.package, clean)
        environment = {"PATH": "/usr/bin:/bin", "HOME": str(self.root / "home"),
                       "LANG": "C", "LC_ALL": "C", "PYTHONDONTWRITEBYTECODE": "1"}
        Path(environment["HOME"]).mkdir()
        self.assertIsNone(shutil.which("bend", path=environment["PATH"]))
        self.assertIsNone(shutil.which("bun", path=environment["PATH"]))
        subprocess.run([sys.executable, str(clean / "scripts/verify_m11_package.py"),
                        "--package", str(clean)], cwd=self.root, env=environment,
                       check=True, capture_output=True, text=True, timeout=45)
        journey = r'''import json, socket, sys
from pathlib import Path

def network_unavailable(*args, **kwargs):
    raise AssertionError("offline package journey attempted a network connection")

socket.socket.connect = network_unavailable
socket.socket.connect_ex = network_unavailable
socket.create_connection = network_unavailable

package = Path(sys.argv[1])
sys.path.insert(0, str(package / "platform"))
from maker.service import MakerService
from persistence.save_identity import SaveIdentity
from persistence.world_state import encode_world_state
from presentation.wire import parse_scene
service = MakerService(Path(sys.argv[2]), template_root=package / "examples/m10-starter",
                       runtime_path=package / "build/m10_dynamic_runtime")
created = service.create_project("Clean install")["project"]
project_id = created["id"]
validation = service.validate_project(project_id)
assert validation["valid"], validation
playtest = service.playtest_project(project_id, [1, 2, 3, 4], 60,
                                    validation["contentHash"])
assert playtest["status"] == "accepted", playtest
assert playtest["contentHash"] == validation["contentHash"]
progressed = service.step_playtest(playtest["sessionId"],
    {"kind": "move", "x": 0, "z": -1024, "analog": False, "sprint": False}, 0)
assert progressed["acceptedCommands"] == 1, progressed
service.save_playtest(progressed["sessionId"], "manual-01")
loaded = service.load_playtest(project_id, "manual-01", validation["contentHash"])
assert loaded["acceptedCommands"] == 1, loaded
replay = service.export_replay(progressed["sessionId"])
verified = service.verify_project_replay(project_id, validation["contentHash"],
                                         replay["replayBase64"])
assert verified["valid"] and verified["acceptedCommands"] == 1, verified

# Seed an exact-identity M8 v1 save at the progressed world and prove that the
# package migrates it, restores it in Bend, and continues command replay.
world = service._sessions[progressed["sessionId"]].response.save_snapshot
assert world is not None
legacy_path = Path(sys.argv[2]) / ".saves" / project_id / "manual-02.json"
legacy_path.parent.mkdir(parents=True, exist_ok=True)
legacy_path.write_bytes(encode_world_state(
    SaveIdentity(1, "m8-1", validation["contentHash"]), world))
migrated = service.migrate_save(project_id, "manual-02", validation["contentHash"], 60)
assert migrated["migrated"] and migrated["acceptedCommands"] == 0, migrated
continued = service.step_playtest(migrated["sessionId"],
    {"kind": "move", "x": 1024, "z": 0, "analog": False, "sprint": False}, 0)
assert continued["acceptedCommands"] == 1, continued
service.save_playtest(continued["sessionId"], "manual-03")
migrated_reloaded = service.load_playtest(project_id, "manual-03", validation["contentHash"])
assert migrated_reloaded["sceneCsv"] == continued["sceneCsv"]
migrated_replay = service.export_replay(continued["sessionId"])
migrated_verified = service.verify_project_replay(
    project_id, validation["contentHash"], migrated_replay["replayBase64"])
assert migrated_verified["valid"] and migrated_verified["acceptedCommands"] == 1

scene = parse_scene(continued["sceneCsv"])
assert scene.content_identity == int(validation["contentHash"][:8], 16)
print(json.dumps({"status": continued["status"],
                  "contentHash": playtest["contentHash"]}))
'''
        result = subprocess.run([sys.executable, "-c", journey, str(clean),
                                 str(self.root / "clean-projects")],
            cwd=self.root, env=environment, check=False, capture_output=True,
            text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["status"], "accepted")


if __name__ == "__main__":
    unittest.main()
