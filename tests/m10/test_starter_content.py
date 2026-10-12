"""Explicit starter selection is validated before a creator can battle."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.loader import ContentError, load_project


class StarterContentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.workspace = tempfile.TemporaryDirectory(prefix="m10-starter-")
        self.addCleanup(self.workspace.cleanup)
        self.project = Path(self.workspace.name) / "project"
        shutil.copytree(ROOT / "examples" / "m10-starter", self.project)

    def _edit(self, path: str, change) -> None:
        file = self.project / path
        document = json.loads(file.read_text(encoding="utf-8"))
        change(document)
        file.write_text(json.dumps(document), encoding="utf-8")

    def test_starter_is_loaded_as_a_typed_species_reference(self) -> None:
        loaded = load_project(self.project)
        self.assertEqual(str(loaded.project.starter.species), "original:mosskip")
        self.assertEqual(loaded.project.starter.level, 5)

    def test_unknown_starter_is_rejected_at_project_pointer(self) -> None:
        self._edit("project.json", lambda row: row["starter"].update(
            species="original:missing"))
        with self.assertRaises(ContentError) as caught:
            load_project(self.project)
        self.assertEqual(caught.exception.diagnostics[0].pointer,
                         "/starter/species")

    def test_starter_requires_progression(self) -> None:
        self._edit("catalogs/starter.json", lambda row:
                   row["species"][0].pop("progression"))
        with self.assertRaises(ContentError) as caught:
            load_project(self.project)
        self.assertEqual(caught.exception.diagnostics[0].pointer,
                         "/starter/species")


if __name__ == "__main__":
    unittest.main()
