"""Host encoder checks and native/JavaScript parity for M10 event wire v1."""
from __future__ import annotations

from dataclasses import replace
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m8_binding import (
    BoundEncounter, BoundEncounterEntry, BoundEventGraph, BoundEventNode,
    M8ContentBinding,
)
from content.m10_events_wire import M10EventsWireError, encode_m10_events


def binding(*, graphs=None, encounters=None):
    graph = BoundEventGraph(1, 0, (
        BoundEventNode(0, "setValue", (("key", 7), ("value", 9)), (1,)),
        BoundEventNode(1, "addEntity", (("entity", 3), ("bytes", 5)), (2,)),
        BoundEventNode(2, "emitSignal", (("kind", 4), ("bytes", 8)), (3,)),
        BoundEventNode(3, "wait", (("ticks", 6),), (4,)),
        BoundEventNode(4, "choice", (("prompt", 7),), (5, 6)),
        BoundEventNode(5, "stop", (), ()),
        BoundEventNode(6, "stop", (), ()),
    ))
    encounter = BoundEncounter(9, (BoundEncounterEntry(3, 4, 2, 4),))
    return M8ContentBinding(
        "m8-1", "0" * 64, 123, 1, (),
        (graph,) if graphs is None else graphs,
        (encounter,) if encounters is None else encounters,
        {}, {}, {}, {}, None,
    )


class M10EventsWireTests(unittest.TestCase):
    def test_encodes_closed_events_and_encounter_tables(self) -> None:
        wire = encode_m10_events(binding())
        self.assertEqual(wire.version, 1)
        self.assertEqual(wire.tokens, (
            12, 1, 123, 1,
            1, 0, 7,
            0, 0, 7, 9, 1,
            1, 1, 3, 5, 2,
            2, 2, 4, 8, 3,
            3, 3, 6, 4,
            4, 4, 7, 5, 6,
            5, 5,
            6, 5,
            1, 9, 1, 3, 4, 2, 4,
        ))
        self.assertEqual(wire.text, " ".join(map(str, wire.tokens)))

    def test_rejects_nonclosed_or_bad_graph_shape(self) -> None:
        source = binding()
        graph = source.events[0]
        bad_opcode = replace(graph.nodes[0], opcode="runHostCode")
        with self.assertRaisesRegex(M10EventsWireError, "unknown closed opcode"):
            encode_m10_events(binding(graphs=(replace(
                graph, nodes=(bad_opcode,) + graph.nodes[1:]),)))
        bad_successor = replace(graph.nodes[0], successors=(99,))
        with self.assertRaisesRegex(M10EventsWireError, "successor"):
            encode_m10_events(binding(graphs=(replace(
                graph, nodes=(bad_successor,) + graph.nodes[1:]),)))

    def test_rejects_cycles_duplicate_ids_and_invalid_encounter_values(self) -> None:
        graph = binding().events[0]
        cyclic = replace(graph.nodes[6], opcode="wait",
                         arguments=(("ticks", 1),), successors=(0,))
        with self.assertRaisesRegex(M10EventsWireError, "immediate cycle"):
            encode_m10_events(binding(graphs=(replace(
                graph, nodes=graph.nodes[:-1] + (cyclic,)),)))
        with self.assertRaisesRegex(M10EventsWireError, "unique"):
            encode_m10_events(binding(encounters=(
                BoundEncounter(9, (BoundEncounterEntry(3, 1, 1, 1),)),
                BoundEncounter(9, (BoundEncounterEntry(4, 1, 1, 1),)),
            )))
        with self.assertRaisesRegex(M10EventsWireError, "minimum level"):
            encode_m10_events(binding(encounters=(BoundEncounter(
                9, (BoundEncounterEntry(3, 1, 201, 201),)),)))
        with self.assertRaisesRegex(M10EventsWireError, "invalid entry"):
            encode_m10_events(binding(encounters=(BoundEncounter(
                9, (BoundEncounterEntry(3, 0, 2, 4),)),)))

    def test_bend_fixture_has_native_and_javascript_parity(self) -> None:
        fixture = ROOT / "tests/m10/dynamic_events_test.bend"
        native = subprocess.run([str(ROOT / "scripts/bend"), str(fixture)],
                                cwd=ROOT, check=True, capture_output=True,
                                text=True, timeout=60)
        self.assertIn("True{}", native.stdout)
        with tempfile.TemporaryDirectory(prefix="m10-events-wire-") as tmp:
            js_file = Path(tmp) / "dynamic-events.js"
            subprocess.run([str(ROOT / "scripts/bend"), str(fixture),
                            "-o", str(js_file)], cwd=ROOT, check=True,
                           capture_output=True, text=True, timeout=60)
            run = subprocess.run(["node", str(js_file)], cwd=ROOT,
                                 capture_output=True, text=True, timeout=10)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn("true", run.stdout.lower())


if __name__ == "__main__":
    unittest.main()
