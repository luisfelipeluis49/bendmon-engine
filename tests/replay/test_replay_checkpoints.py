from __future__ import annotations

import hashlib
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.canonical_json import canonical_json  # noqa: E402
from persistence.replay_checkpoints import (  # noqa: E402
    CHECKPOINT_INTERVAL,
    ReplayCheckpointError,
    checkpoint_counts,
    replay_checkpoints,
    validate_checkpoint_counts,
)


class ReplayCheckpointTests(unittest.TestCase):
    def test_empty_log_has_no_optional_checkpoint(self) -> None:
        self.assertEqual(replay_checkpoints({"seed": 1}, []), ())

    def test_terminal_completion_hashes_empty_and_partial_logs(self) -> None:
        empty = replay_checkpoints({"seed": 1}, [], terminal=True)
        self.assertEqual(tuple(point.command_count for point in empty), (0,))
        partial = replay_checkpoints({"seed": 1}, [{"n": i} for i in range(3)], terminal=True)
        self.assertEqual(tuple(point.command_count for point in partial), (3,))

    def test_exact_1024_boundary_emits_one_checkpoint(self) -> None:
        commands = [{"n": i} for i in range(CHECKPOINT_INTERVAL)]
        points = replay_checkpoints({"seed": 1}, commands, terminal=True)
        self.assertEqual(tuple(point.command_count for point in points), (1024,))

    def test_long_log_emits_only_fixed_boundaries_and_terminal(self) -> None:
        commands = [{"n": i} for i in range(1025)]
        points = replay_checkpoints({"seed": 1}, commands, terminal=True)
        self.assertEqual(tuple(point.command_count for point in points), (1024, 1025))

    def test_checkpoint_digest_is_canonical_and_mutation_sensitive(self) -> None:
        initial = {"z": 2, "a": 1}
        commands = [{"actor": "a", "payload": [1, 2]}]
        point = replay_checkpoints(initial, commands, terminal=True)[0]
        expected_bytes = canonical_json({"acceptedCommands": commands, "initialState": initial})
        self.assertEqual(point.digest, hashlib.sha256(expected_bytes).hexdigest())
        changed = replay_checkpoints(initial, [{"actor": "a", "payload": [1, 3]}], terminal=True)
        self.assertNotEqual(point.digest, changed[0].digest)

    def test_generator_commands_are_supported(self) -> None:
        points = replay_checkpoints({"seed": 1}, ({"n": i} for i in range(1024)))
        self.assertEqual(len(points), 1)
        self.assertEqual(points[0].command_count, 1024)

    def test_malformed_checkpoint_intervals_are_rejected(self) -> None:
        self.assertEqual(checkpoint_counts(2049, terminal=True), (1024, 2048, 2049))
        with self.assertRaises(ReplayCheckpointError):
            validate_checkpoint_counts((1024, 2049), 2049, terminal=True)
        with self.assertRaises(ReplayCheckpointError):
            validate_checkpoint_counts((0,), 0)
        with self.assertRaises(ReplayCheckpointError):
            checkpoint_counts(-1)
        with self.assertRaises(ReplayCheckpointError):
            checkpoint_counts(10, terminal=1)  # type: ignore[arg-type]


if __name__ == "__main__":
    unittest.main()
