"""Closed authored boot input before crossing into the Bend runtime."""
import unittest
from dataclasses import replace
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m8_binding import BoundPoint, M8ContentBinding, SignedCoord
from content.m10_boot_wire import M10BootWireError, encode_m10_boot


def binding(entry_point):
    return M8ContentBinding("m8-1", "0" * 64, 123, 1, (), (), (),
                            {}, {}, {}, {}, None, entry_point)


class M10BootWireTests(unittest.TestCase):
    def test_authored_start_rng_and_wait_have_exact_numeric_envelope(self):
        start = BoundPoint(SignedCoord(False, 1024), SignedCoord(False, 0),
                           SignedCoord(True, 512))
        wire = encode_m10_boot(binding(start), rng_state=(1, 2, 3, 4),
                               wait_ticks=60)
        self.assertEqual(wire.tokens, (11, 2, 123, 1, 0, 1024, 0, 0, 1,
                                       512, 1, 2, 3, 4, 60, 0, 0))
        self.assertEqual(wire.text, " ".join(map(str, wire.tokens)))

    def test_authored_starter_is_bounded_and_explicit(self):
        start = BoundPoint(SignedCoord(False, 1024), SignedCoord(False, 0),
                           SignedCoord(False, 1024))
        row = encode_m10_boot(replace(binding(start), starter_species_id=2,
                                      starter_level=5),
                              rng_state=(1, 2, 3, 4), wait_ticks=60)
        self.assertEqual(row.tokens[-2:], (2, 5))
        with self.assertRaisesRegex(M10BootWireError, "both be present"):
            encode_m10_boot(replace(binding(start), starter_species_id=2),
                            rng_state=(1, 2, 3, 4), wait_ticks=60)

    def test_missing_start_and_invalid_rng_or_wait_reject(self):
        with self.assertRaisesRegex(M10BootWireError, "entryPoint"):
            encode_m10_boot(binding(None), rng_state=(1, 2, 3, 4), wait_ticks=60)
        start = BoundPoint(SignedCoord(False, 1024), SignedCoord(False, 0),
                           SignedCoord(False, 1024))
        with self.assertRaisesRegex(M10BootWireError, "all zero"):
            encode_m10_boot(binding(start), rng_state=(0, 0, 0, 0), wait_ticks=60)
        with self.assertRaisesRegex(M10BootWireError, "Wait pacing"):
            encode_m10_boot(binding(start), rng_state=(1, 2, 3, 4), wait_ticks=31)

    def test_noncanonical_coordinate_and_entry_map_reject(self):
        start = BoundPoint(SignedCoord(True, 0), SignedCoord(False, 0),
                           SignedCoord(False, 1024))
        with self.assertRaisesRegex(M10BootWireError, "negative zero"):
            encode_m10_boot(binding(start), rng_state=(1, 2, 3, 4), wait_ticks=60)
        good = replace(start, x=SignedCoord(False, 1024))
        with self.assertRaisesRegex(M10BootWireError, "entry map ID"):
            encode_m10_boot(replace(binding(good), entry_map_id=0),
                            rng_state=(1, 2, 3, 4), wait_ticks=60)


if __name__ == "__main__":
    unittest.main()
