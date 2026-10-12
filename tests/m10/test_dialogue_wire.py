from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from content.m10_dialogue_wire import M10DialogueWireError, encode_m10_dialogue
from content.models import DialogueId, DialogueLine, DialogueRecord


class DialogueWireTests(unittest.TestCase):
    def test_encodes_identity_and_authored_unicode_in_order(self) -> None:
        rows = (DialogueRecord(DialogueId("demo:greeting"),
                               (DialogueLine("Mira", "Oi 🌱"),)),)
        wire = encode_m10_dialogue(88, rows, {"demo:greeting": 1}, ((1, 2, 1),))
        self.assertEqual(wire.tokens[:6], (16, 1, 88, 1, 1, 1))
        self.assertEqual(wire.tokens[6:12], (4, 77, 105, 114, 97, 4))
        self.assertEqual(wire.tokens[-4:], (1, 1, 2, 1))
        self.assertIn(127793, wire.tokens)

    def test_rejects_wrong_identity_table_and_non_printable_text(self) -> None:
        rows = (DialogueRecord(DialogueId("demo:greeting"),
                               (DialogueLine("Mira", "Oi"),)),)
        with self.assertRaisesRegex(M10DialogueWireError, "ID table"):
            encode_m10_dialogue(88, rows, {"demo:other": 1})
        invalid = (DialogueRecord(DialogueId("demo:greeting"),
                                  (DialogueLine("Mira", "bad\ntext"),)),)
        with self.assertRaisesRegex(M10DialogueWireError, "non-printable"):
            encode_m10_dialogue(88, invalid, {"demo:greeting": 1})

    def test_progression_has_native_and_javascript_parity(self) -> None:
        fixture = ROOT / "tests/m10/dialogue_test.bend"
        native = subprocess.run([str(ROOT / "scripts/bend"), str(fixture)],
                                cwd=ROOT, check=True, capture_output=True,
                                text=True, timeout=60)
        self.assertIn("True{}", native.stdout)
        with tempfile.TemporaryDirectory(prefix="m10-dialogue-") as tmp:
            js_file = Path(tmp) / "dialogue.js"
            subprocess.run([str(ROOT / "scripts/bend"), str(fixture), "-o",
                            str(js_file)], cwd=ROOT, check=True,
                            capture_output=True, text=True, timeout=60)
            run = subprocess.run(["node", str(js_file)], cwd=ROOT,
                                 capture_output=True, text=True, timeout=10)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn("true", run.stdout.lower())


if __name__ == "__main__":
    unittest.main()
