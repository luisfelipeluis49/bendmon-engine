"""Independent wire-boundary tests against the compiled Bend content validator."""
import os
from pathlib import Path
import random
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
KERNEL = ROOT / 'build/content-kernel'


def encode(assets=1, species=(0,), encounters=(((0, 1),),), maps=((8, 8, (0,)),), entry=0):
    words = [1, assets, len(species), *species, len(encounters)]
    for roster in encounters:
        words.append(len(roster))
        for ref, level in roster:
            words.extend((ref, level))
    words.append(len(maps))
    for width, height, refs in maps:
        words.extend((width, height, len(refs), *refs))
    words.append(entry)
    return ' '.join(map(str, words))


class NativeContentTests(unittest.TestCase):
    def call(self, wire, threads=1):
        with tempfile.TemporaryDirectory(prefix='content-wire-test.') as directory:
            path = Path(directory) / 'input.txt'
            path.write_bytes(wire.encode('ascii') if isinstance(wire, str) else wire)
            return subprocess.run([str(KERNEL), '--threads', str(threads), '--', str(path)],
                                  capture_output=True, text=True, timeout=15)

    def valid(self, wire):
        result = self.call(wire)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout, 'OK\n')

    def bad(self, wire, marker):
        result = self.call(wire)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(marker, result.stdout + result.stderr)

    def test_minimal_valid_and_empty_optional_catalogs(self):
        self.valid(encode())
        self.valid(encode(assets=0, species=(), encounters=(), maps=((1, 1, ()),)))

    def test_every_reference_kind_is_checked(self):
        self.bad(encode(assets=0), 'ERR 1 0 0')
        self.bad(encode(species=(), encounters=(((0, 1),),)), 'ERR 2 0 0')
        self.bad(encode(encounters=()), 'ERR 5 0 0')
        self.bad(encode(entry=1), 'ERR 6 0 0')
        self.bad(encode(maps=(), entry=0), 'ERR 6 0 0')

    def test_level_and_dimensions_boundaries(self):
        for level in (1, 200):
            self.valid(encode(encounters=(((0, level),),)))
        for level in (0, 201, 4294967295):
            self.bad(encode(encounters=(((0, level),),)), 'ERR 3 0 0')
        self.valid(encode(maps=((512, 512, (0,)),)))
        for width, height in ((0, 1), (1, 0), (513, 1), (1, 513)):
            self.bad(encode(maps=((width, height, (0,)),)), 'ERR 4 0 0')

    def test_ordered_item_diagnostic(self):
        self.bad(encode(encounters=(((0, 1), (1, 1)),)), 'ERR 2 0 1')
        self.bad(encode(maps=((8, 8, (0, 1)),)), 'ERR 5 0 1')

    def test_wire_not_an_expression_language(self):
        for value in ('', '1', '2 0 0 0 0 0', encode() + ' 0', encode()[:-1],
                      '1 -1', '1 4294967296', '1 1.0', '1 1e0', '1 true',
                      '1 __import__("os")', '1 257', '1 0 257', '1 0 0 257'):
            with self.subTest(wire=value):
                self.bad(value, 'WIRE')
        self.bad(b'\xff\xfe\x00', 'WIRE')

    def test_wire_resource_ceiling(self):
        self.bad(b' ' * (2 * 1024 * 1024 + 1), 'WIRE')
        self.bad('é'.encode() * 1_100_000, 'WIRE file-size')
        self.bad(('0 ' * 140001), 'WIRE')

    def test_generated_valid_inputs_and_parallel_order(self):
        generator = random.Random(32002)
        for _ in range(12):
            n = generator.randint(1, 8)
            rosters = tuple(tuple((generator.randrange(n), generator.randint(1, 200))
                                 for _ in range(generator.randint(0, 8))) for _ in range(n))
            maps = tuple((generator.randint(1, 512), generator.randint(1, 512), tuple(range(n))) for _ in range(n))
            wire = encode(assets=n, species=tuple(range(n)), encounters=rosters, maps=maps, entry=n-1)
            self.valid(wire)
        wire = encode(assets=0, encounters=(((5, 201),),), maps=((0, 8, (4,)),), entry=4)
        baseline = self.call(wire, 1)
        self.assertNotEqual(baseline.returncode, 0)
        for threads in (2, 4):
            result = self.call(wire, threads)
            self.assertEqual((result.returncode, result.stdout, result.stderr),
                             (baseline.returncode, baseline.stdout, baseline.stderr))

    def test_bad_cli_path(self):
        result = subprocess.run([str(KERNEL), '--', '/nonexistent-bend-content-input'],
                                capture_output=True, text=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')
        self.assertEqual(result.stderr, 'WIRE open\n')


if __name__ == '__main__':
    unittest.main()
