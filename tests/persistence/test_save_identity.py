from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.battle_replay import (  # noqa: E402
    LEGACY_RULESET_VERSION, RULESET_VERSION,
)
from persistence.save_identity import (  # noqa: E402
    SaveIdentity,
    SaveIdentityError,
    require_exact_identity,
)


class SaveIdentityTests(unittest.TestCase):
    def identity(self, **changes: object) -> SaveIdentity:
        values: dict[str, object] = {
            "schema_version": 1,
            "ruleset_version": LEGACY_RULESET_VERSION,
            "content_digest": "a" * 64,
        }
        values.update(changes)
        return SaveIdentity(**values)  # type: ignore[arg-type]

    def test_canonical_identity_has_schema_ruleset_and_content(self) -> None:
        self.assertEqual(
            self.identity().canonical_value(),
            {
                "saveSchemaVersion": 1,
                "rulesetVersion": "m3-1",
                "contentDigest": "a" * 64,
            },
        )

    def test_exact_identity_accepts_match_and_reports_both_mismatch_values(self) -> None:
        identity = self.identity()
        require_exact_identity(identity,
                               expected_ruleset_version=LEGACY_RULESET_VERSION,
                               expected_content_digest="a" * 64)
        with self.assertRaises(SaveIdentityError) as caught:
            require_exact_identity(identity,
                                   expected_ruleset_version=LEGACY_RULESET_VERSION,
                                   expected_content_digest="b" * 64)
        self.assertEqual(
            str(caught.exception),
            f"project content identity mismatch: expected {'b' * 64!r}, actual {'a' * 64!r}",
        )
        with self.assertRaisesRegex(
            SaveIdentityError, "expected 'm6-1', actual 'm3-1'"
        ):
            require_exact_identity(identity, expected_content_digest="a" * 64)

    def test_legacy_identity_requires_explicit_legacy_runtime(self) -> None:
        identity = self.identity(ruleset_version=LEGACY_RULESET_VERSION)
        require_exact_identity(
            identity,
            expected_ruleset_version=LEGACY_RULESET_VERSION,
            expected_content_digest="a" * 64,
        )
        with self.assertRaisesRegex(SaveIdentityError, "expected 'm6-1'"):
            require_exact_identity(identity, expected_content_digest="a" * 64)

    def test_new_runtime_defaults_to_m6(self) -> None:
        identity = self.identity(ruleset_version=RULESET_VERSION)
        require_exact_identity(identity, expected_content_digest="a" * 64)
        with self.assertRaisesRegex(
            SaveIdentityError, "expected 'm3-1', actual 'm6-1'"
        ):
            require_exact_identity(identity,
                                   expected_ruleset_version=LEGACY_RULESET_VERSION,
                                   expected_content_digest="a" * 64)

    def test_invalid_identity_is_rejected(self) -> None:
        invalid = (
            {"schema_version": 0},
            {"schema_version": True},
            {"ruleset_version": "future"},
            {"content_digest": "A" * 64},
        )
        for changes in invalid:
            with self.subTest(changes=changes), self.assertRaises(SaveIdentityError):
                self.identity(**changes)


if __name__ == "__main__":
    unittest.main()
