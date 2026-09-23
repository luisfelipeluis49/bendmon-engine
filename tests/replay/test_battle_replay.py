from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.battle_replay import (  # noqa: E402
    BattleReplayError,
    BattleReplayHeader,
    M6_RULESET_VERSION,
    RNG_VERSION,
    RULESET_VERSION,
    require_exact_identity,
)
from persistence.canonical_json import canonical_json_sha256  # noqa: E402


class BattleReplayHeaderTests(unittest.TestCase):
    def header(self, **changes: object) -> BattleReplayHeader:
        values: dict[str, object] = {
            "ruleset_version": RULESET_VERSION,
            "content_digest": "a" * 64,
            "wait_ticks": 60,
            "rng_version": RNG_VERSION,
            "rng_state": (1, 2, 3, 4),
        }
        values.update(changes)
        return BattleReplayHeader(**values)  # type: ignore[arg-type]

    def test_canonical_header_preserves_all_identity_fields(self) -> None:
        value = self.header().canonical_value()
        self.assertEqual(value["waitTicks"], 60)
        self.assertEqual(value["rng"]["state"], [1, 2, 3, 4])
        self.assertEqual(len(canonical_json_sha256(value)), 64)

    def test_exact_content_identity_is_required(self) -> None:
        require_exact_identity(self.header(), content_digest="a" * 64)
        with self.assertRaises(BattleReplayError) as caught:
            require_exact_identity(self.header(), content_digest="b" * 64)
        self.assertEqual(
            str(caught.exception),
            f"project content identity mismatch: expected {'b' * 64!r}, actual {'a' * 64!r}",
        )

    def test_m6_replay_identity_requires_explicit_runtime_selection(self) -> None:
        m6_header = self.header(ruleset_version=M6_RULESET_VERSION)
        require_exact_identity(
            m6_header,
            content_digest="a" * 64,
            ruleset_version=M6_RULESET_VERSION,
        )
        with self.assertRaisesRegex(
            BattleReplayError, "expected 'm3-1', actual 'm6-1'"
        ):
            require_exact_identity(m6_header, content_digest="a" * 64)

    def test_ruleset_mismatch_reports_expected_and_actual(self) -> None:
        with self.assertRaisesRegex(
            BattleReplayError, "expected 'm6-1', actual 'm3-1'"
        ):
            require_exact_identity(
                self.header(),
                content_digest="a" * 64,
                ruleset_version=M6_RULESET_VERSION,
            )

    def test_invalid_wait_rng_and_versions_reject(self) -> None:
        invalid = (
            {"wait_ticks": 45},
            {"rng_state": (0, 0, 0, 0)},
            {"rng_state": (1, 2, 3, 2**32)},
            {"rng_version": "other"},
            {"ruleset_version": "other"},
        )
        for changes in invalid:
            with self.subTest(changes=changes), self.assertRaises(BattleReplayError):
                self.header(**changes)


if __name__ == "__main__":
    unittest.main()
