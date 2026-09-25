from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.battle_replay import (  # noqa: E402
    BattleReplayError, BattleReplayHeader, M6_RULESET_VERSION,
    M7_RULESET_VERSION, RNG_VERSION, require_exact_identity as require_replay,
)
from persistence.save_identity import (  # noqa: E402
    SaveIdentity, SaveIdentityError, require_exact_identity as require_save,
)
from persistence.learning_state import (  # noqa: E402
    IndividualLearning, encode_learning_state, decode_learning_state,
    LearningStateCodecError,
)


class M7IdentityTests(unittest.TestCase):
    def test_learning_state_round_trip_uses_exact_m7_identity(self) -> None:
        identity = SaveIdentity(1, M7_RULESET_VERSION, "a" * 64)
        records = (IndividualLearning(7, (), ()),)
        encoded = encode_learning_state(identity, (7,), records,
                                        known_recipe_ids=())
        self.assertEqual(decode_learning_state(encoded, identity, (7,),
                                               known_recipe_ids=()), records)
        with self.assertRaisesRegex(LearningStateCodecError,
                                    "ruleset version mismatch"):
            decode_learning_state(encoded,
                                  SaveIdentity(1, M6_RULESET_VERSION, "a" * 64),
                                  (7,), known_recipe_ids=())

    def test_new_ruleset_is_exact_and_legacy_remains_explicit(self) -> None:
        digest = "a" * 64
        other = "b" * 64
        save = SaveIdentity(1, M7_RULESET_VERSION, digest)
        replay = BattleReplayHeader(M7_RULESET_VERSION, digest, 30,
                                    RNG_VERSION, (1, 2, 3, 4))
        require_save(save, expected_ruleset_version=M7_RULESET_VERSION,
                     expected_content_digest=digest)
        require_replay(replay, ruleset_version=M7_RULESET_VERSION,
                       content_digest=digest)
        with self.assertRaisesRegex(SaveIdentityError,
                                    "expected 'm6-1', actual 'm7-1'"):
            require_save(save, expected_ruleset_version=M6_RULESET_VERSION,
                         expected_content_digest=digest)
        with self.assertRaisesRegex(BattleReplayError,
                                    "expected 'm6-1', actual 'm7-1'"):
            require_replay(replay, ruleset_version=M6_RULESET_VERSION,
                           content_digest=digest)
        with self.assertRaisesRegex(SaveIdentityError,
                                    "project content identity mismatch"):
            require_save(save, expected_ruleset_version=M7_RULESET_VERSION,
                         expected_content_digest=other)
        with self.assertRaisesRegex(BattleReplayError,
                                    "project content identity mismatch"):
            require_replay(replay, ruleset_version=M7_RULESET_VERSION,
                           content_digest=other)


if __name__ == "__main__":
    unittest.main()
