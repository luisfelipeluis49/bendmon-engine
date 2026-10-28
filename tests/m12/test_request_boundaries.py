"""Creator ingress must reject hostile JSON with bounded user-facing errors."""
from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import tracemalloc
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'platform'))
from maker.service import (MAX_PROJECT_SCAN_ENTRIES, MakerError, MakerService,
                           decode_request)
from maker.request_json import MAX_REQUEST_DEPTH, MAX_REQUEST_STRUCTURE
from persistence.m11_replay import ReplayFileError, decode_replay
from persistence.m11_save import M11SaveError, SaveExpectation, decode_m11_save


class RequestBoundaryTests(unittest.TestCase):
    def test_excess_document_bundle_rejects_without_changing_project(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            service = MakerService(temporary)
            created = service.create_project('document budget')['project']
            documents = dict(created['documents'])
            for index in range(64 - len(documents)):
                documents[f'maps/extra-{index}.json'] = {}
            accepted = service.save_documents(created['id'], documents)['project']
            self.assertEqual(len(accepted['documents']), 64)
            documents['maps/over-budget.json'] = {}
            with self.assertRaises(MakerError) as caught:
                service.save_documents(created['id'], documents)
            self.assertEqual(caught.exception.code, 'documents-too-large')
            self.assertEqual(service.open_project(created['id'])['project'], accepted)

    def test_excess_draft_documents_reject_on_open(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            service = MakerService(temporary)
            created = service.create_project('draft document budget')['project']
            root = service.project_path(created['id'])
            for index in range(65):
                (root / f'extra-{index}.json').write_text('{}')
            with self.assertRaises(MakerError) as caught:
                service.open_project(created['id'])
            self.assertEqual(caught.exception.code, 'project-too-large')

    def test_non_json_directory_entries_have_a_scan_budget(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            service = MakerService(temporary)
            created = service.create_project('scan budget')['project']
            root = service.project_path(created['id'])
            extras = root / 'extras'
            extras.mkdir()
            for index in range(MAX_PROJECT_SCAN_ENTRIES + 1):
                (extras / str(index)).touch()
            with self.assertRaises(MakerError) as caught:
                service.open_project(created['id'])
            self.assertEqual(caught.exception.code, 'project-too-large')

    def test_open_draft_rejects_large_file_before_allocating_its_contents(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            service = MakerService(temporary)
            project_id = service.create_project('bounded draft')['project']['id']
            oversized = service.project_path(project_id) / 'maps/oversized.json'
            with oversized.open('wb') as stream:
                stream.truncate(128 * 1024 * 1024)
            tracemalloc.start()
            try:
                with self.assertRaises(MakerError) as caught:
                    service.open_project(project_id)
                _, peak = tracemalloc.get_traced_memory()
            finally:
                tracemalloc.stop()
            self.assertEqual(caught.exception.code, 'project-file')
            self.assertLess(peak, 4 * 1024 * 1024)

    def test_nonobject_draft_stays_editable_and_reports_validation_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            service = MakerService(temporary)
            created = service.create_project('invalid draft')['project']
            documents = created['documents']
            documents['project.json'] = []
            saved = service.save_documents(created['id'], documents)
            self.assertTrue(saved['saved'])
            self.assertEqual(saved['project']['documents']['project.json'], [])
            self.assertFalse(service.validate_project(created['id'])['valid'])

    def test_excessive_depth_and_integer_size_use_declared_request_error(self) -> None:
        for raw in (b'[' * 1500 + b'0' + b']' * 1500,
                    b'{"value":' + b'9' * 5000 + b'}',
                    b'{"value":"\\ud800"}'):
            with self.subTest(prefix=raw[:20]), self.assertRaises(MakerError) as caught:
                decode_request(raw)
            self.assertEqual(caught.exception.code, 'invalid-json')
            self.assertLess(len(caught.exception.message), 512)

    def test_duplicate_large_key_does_not_expand_error_response(self) -> None:
        key = json.dumps('private' * 40_000).encode()
        raw = b'{' + key + b':0,' + key + b':1}'
        with self.assertRaises(MakerError) as caught:
            decode_request(raw)
        self.assertIn('duplicate JSON key', caught.exception.message)
        self.assertLess(len(caught.exception.message), 300)
        with self.assertRaises(ReplayFileError) as replay_error:
            decode_replay(raw)
        self.assertLess(len(str(replay_error.exception)), 300)
        expectation = SaveExpectation('m8-1', 'a' * 64, 'project.demo', 'catalog.main')
        with self.assertRaises(M11SaveError) as save_error:
            decode_m11_save(raw, expectation)
        self.assertLess(len(str(save_error.exception)), 300)
        for error in (caught.exception, replay_error.exception, save_error.exception):
            self.assertNotIn('private', str(error))

    def test_quoted_brackets_do_not_consume_nesting_budget(self) -> None:
        expected = {'text': '[{\\"}]' * 1000, 'documents': [{'name': 'draft'}]}
        self.assertEqual(decode_request(json.dumps(expected).encode()), expected)
        raw = b'[' * MAX_REQUEST_DEPTH + b'0' + b']' * MAX_REQUEST_DEPTH
        self.assertIsInstance(decode_request(raw), list)

    def test_draft_file_decoder_uses_the_same_bounded_boundary(self) -> None:
        with self.assertRaises(MakerError) as caught:
            MakerService._decode_file(b'[' * 1500 + b'0' + b']' * 1500, 'maps/deep.json')
        self.assertEqual(caught.exception.code, 'invalid-project-json')
        self.assertIn('maps/deep.json', caught.exception.message)

    def test_structure_budget_rejects_many_tiny_values_before_decoding(self) -> None:
        raw = b'[' + b'0,' * MAX_REQUEST_STRUCTURE + b'0]'
        with self.assertRaisesRegex(MakerError, 'JSON structure exceeds'):
            decode_request(raw)


if __name__ == '__main__':
    unittest.main()
