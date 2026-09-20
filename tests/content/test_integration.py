"""Actual native-kernel integration and hostile authoring-data regressions."""
from dataclasses import FrozenInstanceError
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'platform'))
from content.loader import ContentError, InfrastructureError, load_project


class ContentIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='content-integration.')
        self.project = Path(self.temp.name) / 'project'
        shutil.copytree(ROOT / 'examples/original-demo', self.project)

    def tearDown(self):
        self.temp.cleanup()

    def edit(self, name, change):
        p = self.project / name
        data = json.loads(p.read_text())
        change(data)
        p.write_text(json.dumps(data))

    def rejected(self, code=None):
        with self.assertRaises(ContentError) as caught:
            load_project(self.project)
        if code:
            self.assertEqual(caught.exception.diagnostics[0].code, code)
        return caught.exception

    def test_original_fixture_real_bend_and_immutable_result(self):
        loaded = load_project(self.project)
        self.assertEqual((len(loaded.species), len(loaded.maps), len(loaded.encounters)), (2, 1, 1))
        self.assertEqual(loaded.content_hash, hashlib.sha256(loaded.canonical_json).hexdigest())
        with self.assertRaises(FrozenInstanceError):
            loaded.maps[0].width = 1

    def test_unknown_and_wrong_kind_references_reach_bend(self):
        cases = [('project.json', lambda d: d.update(entryMap='original:missing'), 'kernel-6'),
                 ('catalogs/starter.json', lambda d: d['species'][0].update(sprite='original:glade'), 'kernel-1'),
                 ('encounters/glade-edge.json', lambda d: d['entries'][0].update(species='original:glade'), 'kernel-2'),
                 ('maps/glade.json', lambda d: d.update(encounters=['original:mosskip']), 'kernel-5')]
        for file, mutate, code in cases:
            with self.subTest(file=file):
                p = self.project / file; before = p.read_bytes()
                self.edit(file, mutate); self.rejected(code); p.write_bytes(before)

    def test_height_error_has_correct_source_pointer(self):
        self.edit('maps/glade.json', lambda d: d.update(height=513))
        error = self.rejected('kernel-4')
        self.assertEqual(error.diagnostics[0].pointer, '/height')

    def test_level_cap_uses_bend(self):
        self.edit('encounters/glade-edge.json', lambda d: d['entries'][0].update(level=201))
        error = self.rejected('kernel-3')
        self.assertEqual(error.diagnostics[0].pointer, '/entries/0/level')

    def test_invalid_json_numeric_and_unicode_forms(self):
        file = self.project / 'project.json'; original = file.read_bytes()
        cases = [b'\xff', b'{"schemaVersion":"content-0","x":NaN}',
                 b'{"schemaVersion":"content-0","x":1.5}', b'{"schemaVersion":"content-0","x":1e0}',
                 b'{"schemaVersion":"content-0","x":Infinity}', b'{"schemaVersion":"content-0","\\ud800":1}',
                 b'{"schemaVersion":"content-0","name":"\\udfff"}',
                 b'{"a":1,"a":2}', b'[' * 10000 + b'0' + b']' * 10000]
        for raw in cases:
            with self.subTest(raw=raw[:60]):
                file.write_bytes(raw); self.rejected()
                result = subprocess.run([sys.executable, str(ROOT / 'scripts/validate_project.py'), str(self.project)], capture_output=True, text=True, timeout=15)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse(json.loads(result.stdout)['ok'])
                self.assertNotIn('Traceback', result.stderr)
        file.write_bytes(original)

    def test_unknown_missing_and_rule_override_fields(self):
        p = self.project / 'project.json'; original = p.read_bytes()
        for mutate in [lambda d: d.update(script='exit(0)'), lambda d: d.update(LEVEL_MAX=999),
                       lambda d: d.pop('entryMap'), lambda d: d.update(ruleset='anything'),
                       lambda d: d.update(schemaVersion='content-1')]:
            self.edit('project.json', mutate); self.rejected(); p.write_bytes(original)
        self.edit('maps/glade.json', lambda d: d.update(width=True)); self.rejected('integer')

    def test_manifest_paths_are_never_executed_or_escaped(self):
        p = self.project / 'manifest.json'; original = p.read_bytes()
        for path in ['../outside.json', './x.json', '/tmp/x.json', 'C:/x.json', 'a\\x.json',
                     'https://x/x.json', 'a//x.json', '$(touch BAD).json']:
            with self.subTest(path=path):
                self.edit('manifest.json', lambda d: d.update(catalogs=[path]))
                self.rejected('path'); p.write_bytes(original)

    def test_ancestor_symlink_root_rejected(self):
        parent = Path(self.temp.name)
        (parent / 'via').symlink_to(parent, target_is_directory=True)
        with self.assertRaises(ContentError):
            load_project(parent / 'via' / 'project')

    def test_identity_ignores_declaration_order_and_document_location(self):
        before = load_project(self.project)
        self.edit('catalogs/starter.json', lambda d: d['species'].reverse())
        p = self.project / 'catalogs/starter.json'
        p.rename(p.with_name('renamed.json'))
        self.edit('manifest.json', lambda d: d.update(catalogs=['catalogs/renamed.json']))
        after = load_project(self.project)
        self.assertEqual(before.content_hash, after.content_hash)
        self.assertEqual(before.catalogs, after.catalogs)
        self.edit('encounters/glade-edge.json', lambda d: d['entries'].reverse())
        self.assertNotEqual(after.content_hash, load_project(self.project).content_hash)

    def test_duplicate_entities_paths_and_references(self):
        cases = [('catalogs/starter.json', lambda d: d['species'].append(dict(d['species'][0]))),
                 ('manifest.json', lambda d: d['maps'].append(d['maps'][0])),
                 ('maps/glade.json', lambda d: d['encounters'].append(d['encounters'][0]))]
        for file, change in cases:
            p = self.project / file; before = p.read_bytes()
            self.edit(file, change); self.rejected('duplicate'); p.write_bytes(before)

    def test_resource_limits_before_external_work(self):
        p = self.project / 'project.json'; before = p.read_bytes()
        p.write_bytes(b' ' * (1024 * 1024 + 1)); self.rejected('file-size'); p.write_bytes(before)
        p = self.project / 'manifest.json'; before = p.read_bytes()
        self.edit('manifest.json', lambda d: d.update(maps=[f'maps/{i}.json' for i in range(65)]))
        self.rejected('file-count'); p.write_bytes(before)
        self.edit('encounters/glade-edge.json', lambda d: d.update(entries=[d['entries'][0]] * 257)); self.rejected('limit')

    def test_hash_and_media_validation(self):
        p = self.project / 'manifest.json'; before = p.read_bytes()
        self.edit('manifest.json', lambda d: d['assets'][0].update(sha256='0' * 64)); self.rejected('asset-integrity'); p.write_bytes(before)
        self.edit('manifest.json', lambda d: d['assets'][0].update(mediaType='application/javascript')); self.rejected('media-type'); p.write_bytes(before)
        asset = self.project / 'assets/mosskip.ppm'
        data = b'P6\n999 999\n255\nabc'; asset.write_bytes(data)
        self.edit('manifest.json', lambda d: d['assets'][0].update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
        self.rejected('ppm')

    def test_infrastructure_failure_does_not_accept_content(self):
        for result in [subprocess.CompletedProcess([], 0, b'OK\nextra', b''),
                       subprocess.CompletedProcess([], 0, b'OK\n', b'warning'),
                       subprocess.CompletedProcess([], 2, b'ERR 9 0 0\n', b''),
                       subprocess.CompletedProcess([], 2, b'ERR 1 999 0\n', b'')]:
            with patch('content.loader.subprocess.run', return_value=result), self.assertRaises(InfrastructureError):
                load_project(self.project)
        with patch('content.loader.subprocess.run', side_effect=subprocess.TimeoutExpired('kernel', 15)), self.assertRaises(InfrastructureError):
            load_project(self.project)


if __name__ == '__main__':
    unittest.main()
