"""Structural and determinism checks for the approved M3 battle fixture corpus."""

from __future__ import annotations

from pathlib import Path
import json
import tempfile
import unittest

from .fixture_loader import (
    FIXTURE_VERSION,
    SCENARIO_IDS,
    FixtureValidationError,
    load_corpus,
)

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "tests" / "battle" / "fixtures"


class M3FixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fixtures = load_corpus(FIXTURES)

    def test_index_has_exact_stable_scenario_order(self) -> None:
        self.assertEqual(FIXTURE_VERSION, "m3-fixtures-1")
        self.assertEqual([fixture["id"] for fixture in self.fixtures], list(SCENARIO_IDS))

    def test_every_approved_scenario_is_present_once(self) -> None:
        ids = [fixture["id"] for fixture in self.fixtures]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(set(ids), set(SCENARIO_IDS))

    def test_fixture_shape_is_data_only_and_bounded(self) -> None:
        for fixture in self.fixtures:
            self.assertEqual(fixture["fixture_version"], FIXTURE_VERSION)
            self.assertIsInstance(fixture["description"], str)
            self.assertTrue(fixture["description"])
            initial = fixture["initial_state"]
            self.assertIsInstance(initial, dict)
            self.assertEqual(len(initial["rng_state"]), 4)
            self.assertIsInstance(fixture["commands"], list)
            expected = fixture["expected"]
            self.assertIsInstance(expected, dict)
            self.assertIsInstance(expected["result"], str)
            self.assertIsInstance(expected["events"], list)
            self.assertTrue(expected["events"])

    def test_actor_and_event_order_are_explicit_and_stable(self) -> None:
        for fixture in self.fixtures:
            actor_ids = fixture["initial_state"].get("ready_actor_ids", [])
            self.assertEqual(actor_ids, sorted(actor_ids))
            self.assertEqual(len(actor_ids), len(set(actor_ids)))
            for command in fixture["commands"]:
                self.assertIn("actor_id", command)
            for event in fixture["expected"]["events"]:
                self.assertIn("type", event)
                self.assertIsInstance(event["type"], str)

    def test_required_semantic_event_coverage(self) -> None:
        event_types = {
            event["type"]
            for fixture in self.fixtures
            for event in fixture["expected"]["events"]
        }
        self.assertTrue({
            "commands-accepted", "execution-queued", "action-fizzle", "action-cancelled",
            "battle-completed", "wait-scheduled", "command-rejected", "escape-attempted",
            "reinforcement-arrived", "switch-accepted",
        } <= event_types)

    def test_diagnostics_are_strict_and_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for source in FIXTURES.glob("*.json"):
                (root / source.name).write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
            path = root / "draw.json"
            value = json.loads(path.read_text(encoding="utf-8"))
            value["expected"]["events"][0]["unexpected"] = 1
            path.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(FixtureValidationError) as caught:
                load_corpus(root)
            self.assertEqual(
                str(caught.exception),
                "scenario[draw]/expected/events/0: unknown field(s): unexpected",
            )

            value["expected"]["events"][0].pop("unexpected")
            value["initial_state"]["rng_state"][0] = True
            path.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(FixtureValidationError) as caught:
                load_corpus(root)
            self.assertEqual(
                str(caught.exception),
                "scenario[draw]/initial_state/rng_state/0: expected integer",
            )


if __name__ == "__main__":
    unittest.main()
