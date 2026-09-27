from __future__ import annotations

import sys
from dataclasses import replace
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.battle_replay import M8_RULESET_VERSION
from persistence.save_identity import SaveIdentity
from persistence.world_state import (
    WorldSnapshot, WorldStateError, decode_world_state, encode_world_state,
    replay_world_commands,
)


class WorldStateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.identity = SaveIdentity(1, M8_RULESET_VERSION, "a" * 64)
        self.state = WorldSnapshot(
            map_id=3, x=-12, y=2, z=99, region_id=4, weighted_distance=180,
            encounter_threshold=100_000, safe_distance=15,
            rng_state=(1, 2, 3, 4),
            persistent_values=((2, 1), (9, 42), (2, 0)),
            persistent_entities=(7, 7, 12),
        )

    def test_round_trip_and_canonical_bytes(self) -> None:
        encoded = encode_world_state(self.identity, self.state)
        self.assertEqual(encoded, encode_world_state(self.identity, self.state))
        self.assertEqual(self.state, decode_world_state(encoded, self.identity))

    def test_identity_and_stable_boundary_are_exact(self) -> None:
        encoded = encode_world_state(self.identity, self.state)
        other = SaveIdentity(1, M8_RULESET_VERSION, "b" * 64)
        with self.assertRaisesRegex(WorldStateError, "identity mismatch"):
            decode_world_state(encoded, other)
        for field in ("pending_encounter", "event_active", "battle_active"):
            unstable = replace(self.state, **{field: True})
            with self.subTest(field=field), self.assertRaisesRegex(WorldStateError, "requires no"):
                encode_world_state(self.identity, unstable)

    def test_rejects_noncanonical_duplicate_and_invalid_meter_or_flags(self) -> None:
        encoded = encode_world_state(self.identity, self.state)
        with self.assertRaisesRegex(WorldStateError, "not canonical"):
            decode_world_state(encoded + b" ", self.identity)
        duplicate = encoded.replace(b'"mapId":3', b'"mapId":3,"mapId":3')
        with self.assertRaisesRegex(WorldStateError, "duplicate JSON"):
            decode_world_state(duplicate, self.identity)
        with self.assertRaisesRegex(WorldStateError, "persistent value"):
            encode_world_state(self.identity, replace(
                self.state, persistent_values=((9, -1),)
            ))
        with self.assertRaisesRegex(WorldStateError, "position x"):
            encode_world_state(self.identity, replace(self.state, x=524_289))
        with self.assertRaisesRegex(WorldStateError, "positive bound map"):
            encode_world_state(self.identity, replace(self.state, map_id=0))

    def test_replay_produces_repeatable_per_command_hashes(self) -> None:
        def step(state: WorldSnapshot, command: dict[str, int]) -> WorldSnapshot:
            dx = command["dx"]
            return replace(state, x=state.x + dx,
                           weighted_distance=state.weighted_distance + abs(dx))

        commands = ({"dx": 4}, {"dx": -1}, {"dx": 2})
        first = replay_world_commands(self.state, commands, step)
        second = replay_world_commands(self.state, commands, step)
        self.assertEqual(first, second)
        self.assertEqual(len(first[1]), len(commands))


if __name__ == "__main__":
    unittest.main()
