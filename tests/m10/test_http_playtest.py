"""The local maker exposes only typed commands to a configured session."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "platform"))

from content.m10_command_wire import Activate
from maker.service import MakerError
from run_m10_maker import M9_RENDERER_ROUTE, browser_asset, dispatch


class RecordingService:
    def __init__(self) -> None:
        self.received = None

    def step_playtest(self, session_id, command, expected_commands):
        self.received = (session_id, command, expected_commands)
        return {"ok": True}


class HttpPlaytestTests(unittest.TestCase):
    def test_routes_only_closed_command_to_service(self) -> None:
        service = RecordingService()
        result = dispatch(service, "POST", "/api/playtests/abc/commands",
                          {"command": {"kind": "activate", "triggerId": 2},
                           "expectedCommands": 0})
        self.assertEqual(result, {"ok": True})
        self.assertEqual(service.received, ("abc", Activate(2), 0))
        with self.assertRaisesRegex(MakerError, "unsupported command"):
            dispatch(service, "POST", "/api/playtests/abc/commands",
                     {"command": {"kind": "runScript"}, "expectedCommands": 0})
        with self.assertRaisesRegex(MakerError, "expectedCommands"):
            dispatch(service, "POST", "/api/playtests/abc/commands",
                     {"command": {"kind": "activate", "triggerId": 2}})

    def test_serves_existing_m9_renderer_by_exact_route(self) -> None:
        content_type, payload = browser_asset(M9_RENDERER_ROUTE)
        self.assertIn("text/javascript", content_type)
        self.assertIn(b"export function renderScene", payload)


if __name__ == "__main__":
    unittest.main()
