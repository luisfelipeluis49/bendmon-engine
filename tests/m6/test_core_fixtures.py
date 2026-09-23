"""Independent oracle checks for deterministic M6 pure-core fixtures."""

from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from .fixture_loader import FixtureValidationError, load_corpus, load_fixture

ROOT = Path(__file__).resolve().parent
FIXTURES = ROOT / "fixtures"
TIERS = ((40, "perfected", (500, 625)), (30, "master", (400, 500)),
         (20, "expert", (300, 375)), (10, "practiced", (200, 250)),
         (5, "familiar", (100, 125)), (0, "novice", (0, 0)))


def harmony_package(progress: int) -> tuple[str, tuple[int, int]]:
    bounded = min(progress, 40)
    for threshold, tier, package in TIERS:
        if bounded >= threshold:
            return tier, package
    raise AssertionError("zero tier is total")


def training_outcome(case: dict) -> dict:
    if case["in_battle"]:
        reason = "in_battle"
    elif not case["trainer"]:
        reason = "no_trainer"
    elif case["tokens"] == 0:
        reason = "no_token"
    elif not case["observed"]:
        reason = "not_observed"
    elif case["learned"]:
        reason = "already_learned"
    elif not case["compatible"]:
        reason = "missing_recipe"
    elif not case["has_sources"]:
        reason = "missing_source"
    else:
        reason = None
    accepted = reason is None
    return {
        "accepted": accepted,
        "tokens_after": case["tokens"] - int(accepted),
        "progress": 0 if accepted else None,
        "reason": reason,
    }


def oracle(fixture: dict) -> dict:
    kind = fixture["kind"]
    data = fixture["input"]
    if kind == "identity":
        return {"canonical": sorted((data["left"], data["right"]))}
    if kind == "cooldown":
        return {"mixed": [c + c // 2 + c % 2 for c in data["ordinary"]]}
    if kind == "learning":
        sources = set(data["sources"])
        witnesses = sorted({
            witness["id"] for witness in data["witnesses"]
            if witness["active"] and witness["conscious"]
            and sources.issubset(witness["moves"])
        })
        training = [training_outcome(case) for case in data["training"]]
        return {
            "witness_ids": witnesses,
            "observed_after_terminal": sorted(set(witnesses)),
            "training_case_count": len(training),
            "training": training,
        }
    if kind == "harmony":
        pairs = [harmony_package(progress) for progress in data["progress"]]
        return {
            "tiers": [tier for tier, _ in pairs],
            "packages": [list(package) for _, package in pairs],
        }
    raise AssertionError(f"unhandled fixture kind: {kind}")


class M6CoreFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fixtures = load_corpus(FIXTURES)

    def test_corpus_covers_frozen_pure_m6_boundaries(self) -> None:
        self.assertEqual({fixture["kind"] for fixture in self.fixtures}, {
            "identity", "cooldown", "learning", "harmony",
        })
        cooldown = next(f for f in self.fixtures if f["kind"] == "cooldown")
        self.assertIn(60, cooldown["input"]["ordinary"])
        self.assertIn(61, cooldown["input"]["ordinary"])
        self.assertIn(3600, cooldown["input"]["ordinary"])
        learning = next(f for f in self.fixtures if f["kind"] == "learning")
        self.assertEqual(set(learning["input"]["terminal_results"]), {
            "victory", "defeat", "draw", "timeout", "escaped",
        })
        harmony = next(f for f in self.fixtures if f["kind"] == "harmony")
        self.assertTrue({4, 5, 9, 10, 19, 20, 29, 30, 39, 40}.issubset(
            set(harmony["input"]["progress"])))

    def test_fixture_expectations_match_independent_oracle(self) -> None:
        for fixture in self.fixtures:
            expected = fixture["expected"]
            actual = oracle(fixture)
            for key in expected:
                self.assertEqual(actual[key], expected[key], fixture["id"])

    def test_training_failures_are_unchanged_transactions(self) -> None:
        fixture = next(f for f in self.fixtures if f["kind"] == "learning")
        for case in fixture["input"]["training"]:
            actual = training_outcome(case)
            for key in ("accepted", "tokens_after", "progress", "reason"):
                self.assertEqual(actual[key], case[key], f"{case['id']}/{key}")
            if not actual["accepted"]:
                self.assertEqual(actual["tokens_after"], case["tokens"], case["id"])
                self.assertIsNone(actual["progress"], case["id"])

    def test_loader_rejects_unknown_fields_and_invalid_pair(self) -> None:
        fixture_path = FIXTURES / "identity.json"
        value = json.loads(fixture_path.read_text(encoding="utf-8"))
        value["unexpected"] = True
        with tempfile.TemporaryDirectory(prefix="bend-m6-fixture-") as temp:
            path = Path(temp) / "bad.json"
            path.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaisesRegex(FixtureValidationError, "unknown field"):
                load_fixture(path)
            value.pop("unexpected")
            value["input"]["right"] = value["input"]["left"]
            path.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaisesRegex(FixtureValidationError, "distinct"):
                load_fixture(path)


if __name__ == "__main__":
    unittest.main()
