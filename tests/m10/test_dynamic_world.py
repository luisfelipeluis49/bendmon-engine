import unittest
from pathlib import Path
import sys
from dataclasses import replace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m8_binding import (
    BoundEncounter, BoundEventGraph, BoundMap, BoundNpc, BoundPoint,
    BoundRegion, BoundTransition, BoundTrigger, M8ContentBinding, SignedCoord,
)
from content.m10_world_wire import M10WorldWireError, encode_m10_world


def point(x: int, y: int, z: int) -> BoundPoint:
    def coord(value: int) -> SignedCoord:
        return SignedCoord(value < 0, abs(value))
    return BoundPoint(coord(x), coord(y), coord(z))


def binding() -> M8ContentBinding:
    row = BoundMap(
        1,
        (point(0, 0, 0), point(1, 0, 0), point(0, 0, 1), point(1, 0, 1)),
        ((0, 1, 2), (1, 3, 2)), ((0, 1),),
        (BoundRegion(1, 2, (0,)),),
        (BoundNpc(1, point(0, 0, 0), 5),),
        (BoundTrigger(1, (0, 1, 3), 5),),
        (BoundTransition(1, 1, (0, 1, 3), point(1, 0, 1)),),
    )
    return M8ContentBinding("m8-1", "0" * 64, 123, 1, (row,),
                            (BoundEventGraph(5, 0, ()),),
                            (BoundEncounter(2, ()),),
                            {}, {}, {}, {}, None)


class DynamicWorldWireTests(unittest.TestCase):
    def test_encodes_versioned_bound_world_records(self):
        wire = encode_m10_world(binding())
        self.assertEqual(wire.version, 2)
        self.assertEqual(wire.tokens, (
            10, 2, 123, 1, 1, 1, 4, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 2, 0, 1, 2, 1, 3, 2,
            1, 0, 1, 1, 1, 2, 1, 0, 1, 1, 5, 0, 0, 0, 0, 0, 0, 1, 1, 5,
            3, 0, 1, 3, 1, 1, 1, 0, 1, 0, 0, 0, 1, 3, 0, 1, 3,
        ))
        self.assertEqual(wire.text, " ".join(map(str, wire.tokens)))

    def test_rejects_unknown_transition_target(self):
        source = binding()
        row = replace(source.maps[0], transitions=(
            BoundTransition(1, 99, (0, 1, 3), point(1, 0, 1)),))
        invalid = replace(source, maps=(row,))
        with self.assertRaisesRegex(M10WorldWireError, "target map"):
            encode_m10_world(invalid)

    def test_rejects_region_face_out_of_range(self):
        source = binding()
        row = replace(source.maps[0], regions=(BoundRegion(1, 2, (2,)),))
        with self.assertRaisesRegex(M10WorldWireError, "region face"):
            encode_m10_world(replace(source, maps=(row,)))

    def test_rejects_polygon_duplicate_indices(self):
        source = binding()
        row = replace(source.maps[0], triggers=(BoundTrigger(1, (0, 0, 3), 5),))
        with self.assertRaisesRegex(M10WorldWireError, "duplicate vertex"):
            encode_m10_world(replace(source, maps=(row,)))

    def test_rejects_zero_area_trigger_polygon(self):
        source = binding()
        row = replace(source.maps[0],
                      vertices=(point(0, 0, 0), point(1, 0, 0),
                                point(2, 0, 0), point(0, 0, 1)),
                      triggers=(BoundTrigger(1, (0, 1, 2), 5),))
        with self.assertRaisesRegex(M10WorldWireError, "zero horizontal area"):
            encode_m10_world(replace(source, maps=(row,)))

    def test_rejects_self_intersecting_transition_polygon(self):
        source = binding()
        row = replace(source.maps[0],
                      vertices=(point(0, 0, 0), point(2, 0, 0),
                                point(2, 0, 2), point(0, 0, 2),
                                point(1, 0, 1)),
                      transitions=(BoundTransition(1, 1, (0, 1, 3, 4, 2),
                                                   point(1, 0, 1)),))
        with self.assertRaisesRegex(M10WorldWireError, "self-intersecting"):
            encode_m10_world(replace(source, maps=(row,)))

    def test_rejects_overlapping_region_faces(self):
        source = binding()
        row = replace(source.maps[0], regions=(BoundRegion(1, 2, (0,)),
                                               BoundRegion(2, 2, (0,))))
        with self.assertRaisesRegex(M10WorldWireError, "regions overlap"):
            encode_m10_world(replace(source, maps=(row,)))

    def test_dense_world_ids_include_256_and_reject_zero(self):
        source = binding()
        row = replace(source.maps[0], npcs=(BoundNpc(256, point(0, 0, 0), None),))
        self.assertEqual(encode_m10_world(replace(source, maps=(row,))).version, 2)
        invalid = replace(source.maps[0], npcs=(BoundNpc(0, point(0, 0, 0), None),))
        with self.assertRaisesRegex(M10WorldWireError, "NPC id"):
            encode_m10_world(replace(source, maps=(invalid,)))


if __name__ == "__main__":
    unittest.main()
