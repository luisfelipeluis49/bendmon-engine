"""An authored playtest start remains part of validated content identity."""
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.loader import ContentError, load_project
from content.m8_binding import bind_m8_content


class EntryPointTests(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.project_root = Path(self.workspace.name) / "world"
        shutil.copytree(ROOT / "examples" / "m8-world", self.project_root)

    def set_entry_point(self, x, y, z):
        path = self.project_root / "project.json"
        project = json.loads(path.read_text(encoding="utf-8"))
        project["entryPoint"] = {"x": x, "y": y, "z": z}
        path.write_text(json.dumps(project), encoding="utf-8")

    def test_valid_entry_point_changes_exact_identity_and_binding(self):
        original = load_project(self.project_root)
        self.assertIsNone(original.project.entry_point)
        self.set_entry_point(1024, 0, 1024)
        changed = load_project(self.project_root)
        self.assertNotEqual(changed.content_hash, original.content_hash)
        bound = bind_m8_content(changed, expected_ruleset_version="m8-1",
                                expected_content_digest=changed.content_hash)
        self.assertEqual(bound.entry_point.x.magnitude, 1024)
        self.assertFalse(bound.entry_point.x.negative)

    def test_point_outside_entry_surface_has_project_diagnostic(self):
        self.set_entry_point(65536, 0, 65536)
        with self.assertRaises(ContentError) as raised:
            load_project(self.project_root)
        diagnostic = raised.exception.diagnostics[0]
        self.assertEqual((diagnostic.file, diagnostic.pointer),
                         ("project.json", "/entryPoint"))

    def test_entry_point_rejects_boolean_and_extra_field(self):
        self.set_entry_point(True, 0, 1024)
        with self.assertRaises(ContentError):
            load_project(self.project_root)
        path = self.project_root / "project.json"
        project = json.loads(path.read_text(encoding="utf-8"))
        project["entryPoint"] = {"x": 1024, "y": 0, "z": 1024, "debug": 1}
        path.write_text(json.dumps(project), encoding="utf-8")
        with self.assertRaises(ContentError):
            load_project(self.project_root)


if __name__ == "__main__":
    unittest.main()
