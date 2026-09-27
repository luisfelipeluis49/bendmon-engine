from __future__ import annotations

import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.battle_replay import (
    BattleReplayError, BattleReplayHeader, M8_RULESET_VERSION, RNG_VERSION,
    require_exact_identity as require_replay,
)
from persistence.save_identity import (
    SaveIdentity, SaveIdentityError, require_exact_identity as require_save,
)


class M8IdentityTests(unittest.TestCase):
    def test_world_save_and_replay_require_same_m8_content(self) -> None:
        digest = "a" * 64
        save = SaveIdentity(1, M8_RULESET_VERSION, digest)
        replay = BattleReplayHeader(
            M8_RULESET_VERSION, digest, 30, RNG_VERSION, (1, 2, 3, 4),
        )
        require_save(save, expected_ruleset_version=M8_RULESET_VERSION,
                     expected_content_digest=digest)
        require_replay(replay, ruleset_version=M8_RULESET_VERSION,
                       content_digest=digest)
        with self.assertRaisesRegex(SaveIdentityError, "identity mismatch"):
            require_save(save, expected_ruleset_version=M8_RULESET_VERSION,
                         expected_content_digest="b" * 64)
        with self.assertRaisesRegex(BattleReplayError, "identity mismatch"):
            require_replay(replay, ruleset_version=M8_RULESET_VERSION,
                           content_digest="b" * 64)

    def test_m7_and_m8_semantics_cannot_substitute(self) -> None:
        digest = "a" * 64
        save = SaveIdentity(1, M8_RULESET_VERSION, digest)
        replay = BattleReplayHeader(
            M8_RULESET_VERSION, digest, 30, RNG_VERSION, (1, 2, 3, 4),
        )
        with self.assertRaisesRegex(SaveIdentityError, "ruleset version mismatch"):
            require_save(save, expected_ruleset_version="m7-1",
                         expected_content_digest=digest)
        with self.assertRaisesRegex(BattleReplayError, "ruleset version mismatch"):
            require_replay(replay, ruleset_version="m7-1",
                           content_digest=digest)


if __name__ == "__main__":
    unittest.main()
