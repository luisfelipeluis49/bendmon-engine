"""Load failures retain useful locations without exporting unbounded input."""
from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'platform'))
sys.path.insert(0, str(ROOT / 'scripts'))
from content.loader import ContentError, load_project
from m12_corpus import write_project


class LoadDiagnosticTests(unittest.TestCase):
    def test_unknown_large_key_has_bounded_distinguishable_location(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project = write_project(Path(temporary) / 'project', 'small')
            path = project / 'project.json'
            value = json.loads(path.read_text())
            key = 'unknown' * 40_000
            value[key] = 'inert'
            path.write_text(json.dumps(value))
            with self.assertRaises(ContentError) as caught:
                load_project(project)
            row = caught.exception.diagnostics[0].as_dict()
            self.assertEqual((row['code'], row['file']), ('unknown-field', 'project.json'))
            self.assertEqual(row['message'], 'unknown field')
            self.assertLessEqual(len(row['pointer']), 512)
            self.assertIn('[sha256:', row['pointer'])
            self.assertLess(len(json.dumps(row)), 1200)

    def test_malformed_claimed_entity_id_is_not_exported_as_raw_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project = write_project(Path(temporary) / 'project', 'small')
            path = project / 'catalogs/starter.json'
            value = json.loads(path.read_text())
            value['species'][0]['id'] = {'raw': ['x' * 20_000]}
            value['species'][0]['types'] = []
            path.write_text(json.dumps(value))
            with self.assertRaises(ContentError) as caught:
                load_project(project)
            row = caught.exception.diagnostics[0].as_dict()
            self.assertEqual(row['code'], 'species-types')
            self.assertEqual(row['pointer'], '/species/0/types')
            self.assertIsNone(row['entityId'])
            self.assertLess(len(json.dumps(row)), 1200)


if __name__ == '__main__':
    unittest.main()
