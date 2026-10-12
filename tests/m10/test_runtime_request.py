"""The process request retains full host identity and exact numeric framing."""
from dataclasses import replace
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from maker.playtest import RuntimeWires
from maker.runtime_request import RuntimeRequestError, assemble_runtime_request
from content.m10_command_wire import Activate


class RuntimeRequestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.wires = RuntimeWires("12345678" + "0" * 56,
                                  "10 2 305419896 1 1", "12 1 305419896 0 0",
                                  "13 2 305419896 1 0", "15 3 305419896 0",
                                  "16 1 305419896 0 0", "11 2 305419896 1")

    def test_exact_frame_and_command_sequence(self) -> None:
        request = assemble_runtime_request(self.wires, (Activate(3),))
        self.assertEqual(request.content_hash, self.wires.content_hash)
        self.assertEqual(request.command_count, 1)
        self.assertEqual(request.payload.splitlines(), [
            b"M10PLAY2", b"10 2 305419896 1 1", b"12 1 305419896 0 0",
            b"13 2 305419896 1 0", b"15 3 305419896 0",
            b"16 1 305419896 0 0", b"11 2 305419896 1",
            b"14 1 1 0 3 3"])

    def test_rejects_forged_identity_and_noncanonical_row(self) -> None:
        with self.assertRaisesRegex(RuntimeRequestError, "mismatched identity"):
            assemble_runtime_request(replace(self.wires, species="13 2 9 1 0"), ())
        with self.assertRaisesRegex(RuntimeRequestError, "canonical numeric"):
            assemble_runtime_request(replace(self.wires, boot="11  1 305419896"), ())
        with self.assertRaisesRegex(RuntimeRequestError, "non-U32"):
            assemble_runtime_request(replace(self.wires,
                world=self.wires.world + " 4294967296"), ())
        with self.assertRaisesRegex(RuntimeRequestError, "unexpected header"):
            assemble_runtime_request(replace(self.wires,
                events="12 2 305419896 0 0"), ())


if __name__ == "__main__":
    unittest.main()
