"""Contract regressions for self-contained authoring-schema path patterns."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SchemaPatternTests(unittest.TestCase):
    def test_paths_exclude_traversal_and_match_real_extensions(self):
        schema = json.loads((ROOT / 'schemas/content-0/manifest.schema.json').read_text())
        for kind, extension in [('jsonPath', 'json'), ('ppmPath', 'ppm')]:
            pattern = re.compile(schema['$defs'][kind]['pattern'])
            for path in [f'a.{extension}', f'maps/map_01.{extension}', f'a-b/c.d.{extension}']:
                self.assertIsNotNone(pattern.fullmatch(path), (kind, path))
            for path in [f'../x.{extension}', f'./x.{extension}', f'a/../x.{extension}',
                         f'a/./x.{extension}', f'/a.{extension}', f'a//x.{extension}',
                         f'a\\x.{extension}', f'C:/x.{extension}', f'https://x.{extension}',
                         f'no_extension_{extension}', f'a.{extension}\n']:
                self.assertIsNone(pattern.fullmatch(path), (kind, path))

    def test_objects_are_closed(self):
        def walk(value):
            if isinstance(value, dict):
                if value.get('type') == 'object':
                    self.assertIs(value.get('additionalProperties'), False)
                    self.assertEqual(set(value.get('properties', {})), set(value.get('required', [])))
                for child in value.values():
                    walk(child)
            elif isinstance(value, list):
                for child in value:
                    walk(child)
        for path in sorted((ROOT / 'schemas/content-0').glob('*.json')):
            walk(json.loads(path.read_text()))


if __name__ == '__main__':
    unittest.main()
