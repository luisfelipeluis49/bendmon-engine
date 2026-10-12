"""Native IO transport probe for a precompiled Bend M10 host."""
from __future__ import annotations

from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
CONTENT_WIRE = "1 1 1 0 1 1 0 1 1 1 1 0 0"


class RuntimeTransportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temp = tempfile.TemporaryDirectory(prefix="m10-runtime-transport-")
        cls.binary = Path(cls.temp.name) / "runtime-transport"
        subprocess.run([str(ROOT / "scripts/bend"),
                        str(ROOT / "platform/maker/runtime_transport.bend"),
                        "-o", str(cls.binary)], cwd=ROOT, check=True,
                       capture_output=True, text=True, timeout=60)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp.cleanup()

    def run_request(self, command_wire: str, content_wire: str = CONTENT_WIRE):
        request = Path(self.temp.name) / "request.txt"
        request.write_text(f"M10RT1\n{content_wire}\n{command_wire}\n",
                           encoding="ascii")
        return subprocess.run([str(self.binary), str(request)], cwd=ROOT,
                              capture_output=True, text=True, timeout=5)

    def test_valid_content_and_commands_cross_the_native_io_boundary(self) -> None:
        result = self.run_request("0 4 5")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout,
                         "M10RT1 ACCEPTED\nACTIONS 3\nMOVE_NORTH\n"
                         "INTERACT\nCONFIRM\n")
        self.assertEqual(result.stderr, "")

    def test_unknown_command_is_rejected(self) -> None:
        result = self.run_request("7")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("M10RT COMMANDS command code is outside 0..6",
                      result.stderr)
        self.assertEqual(result.stdout, "")

    def test_invalid_content_is_rejected_before_acceptance(self) -> None:
        result = self.run_request("0", "1 1 1 2 1 1 0 1 1 1 1 0 0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("M10RT CONTENT semantic validation failed", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_command_count_is_bounded(self) -> None:
        result = self.run_request(" ".join(["0"] * 4097))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("command count exceeds 4096", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_request_bytes_are_bounded(self) -> None:
        request = Path(self.temp.name) / "oversized.txt"
        request.write_text("M10RT1\n" + (" " * 2_097_152), encoding="ascii")
        result = subprocess.run([str(self.binary), str(request)], cwd=ROOT,
                                capture_output=True, text=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("M10RT request exceeds 2097152 bytes", result.stderr)
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
