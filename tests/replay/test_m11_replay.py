from __future__ import annotations

import sys
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.battle_replay import RNG_VERSION, RULESET_VERSION  # noqa: E402
from persistence.m11_replay import (  # noqa: E402
    MAX_REPLAY_BYTES,
    AcceptedCommand,
    ReplayCheckpoint,
    ReplayFile,
    ReplayFileError,
    ReplayHeader,
    ReplayRunStep,
    decode_replay,
    encode_replay,
    verify_replay,
)


class M11ReplayTests(unittest.TestCase):
    def header(self, **changes: object) -> ReplayHeader:
        values: dict[str, object] = {
            "ruleset_version": RULESET_VERSION,
            "content_digest": "a" * 64,
            "rng_version": RNG_VERSION,
            "rng_state": (1, 2, 3, 4),
            "wait_ticks": 60,
            "engine_build": "dev-test",
            "initial_state": {"world": {"map": 2}, "party": [4, 5]},
        }
        values.update(changes)
        return ReplayHeader(**values)  # type: ignore[arg-type]

    @staticmethod
    def command(tick: int = 0, barrier: int = 0, ordinal: int = 0,
                actor: int = 0, payload: dict[str, object] | None = None) -> AcceptedCommand:
        return AcceptedCommand(tick, barrier, ordinal, actor, payload or {"kind": "wait"})

    def test_canonical_round_trip_preserves_complete_identity_and_order(self) -> None:
        replay = ReplayFile(self.header(), (self.command(), self.command(60, 1)))
        encoded = encode_replay(replay)
        decoded = decode_replay(encoded, expected_content_digest="a" * 64)
        self.assertEqual(decoded, replay)
        self.assertEqual(encode_replay(decoded), encoded)

    def test_exact_ruleset_and_full_content_digest_are_required(self) -> None:
        data = encode_replay(ReplayFile(self.header(), ()))
        with self.assertRaisesRegex(ReplayFileError, "ruleset mismatch"):
            decode_replay(data, expected_ruleset="m3-1")
        with self.assertRaisesRegex(ReplayFileError, "content digest mismatch"):
            decode_replay(data, expected_content_digest="b" * 64)

    def test_historical_ruleset_is_explicit_and_not_upgraded(self) -> None:
        replay = ReplayFile(self.header(ruleset_version="m3-1"), ())
        with self.assertRaisesRegex(ReplayFileError, "expected 'm7-1', actual 'm3-1'"):
            decode_replay(encode_replay(replay))
        self.assertEqual(decode_replay(encode_replay(replay), expected_ruleset="m3-1"), replay)

    def test_command_order_rejects_gaps_duplicates_and_decreasing_barriers(self) -> None:
        invalid = (
            (self.command(), self.command(0, 0, 2)),
            (self.command(), self.command(0, 0, 0)),
            (self.command(10, 2), self.command(11, 1)),
            (self.command(10, 2), self.command(11, 3, 1)),
        )
        for commands in invalid:
            with self.subTest(commands=commands), self.assertRaises(ReplayFileError):
                ReplayFile(self.header(), commands)

    def test_command_payload_and_rng_are_bounded(self) -> None:
        for args in (
            {"rng_state": (0, 0, 0, 0)},
            {"wait_ticks": 45},
            {"rng_version": "other"},
            {"initial_state": {"flag": True}},
        ):
            with self.subTest(args=args), self.assertRaises(ReplayFileError):
                self.header(**args)
        with self.assertRaises(ReplayFileError):
            self.command(payload={"kind": "wait", "bad": True})

    def test_decode_rejects_duplicate_keys_noncanonical_and_oversized_files(self) -> None:
        canonical = encode_replay(ReplayFile(self.header(), ()))
        with self.assertRaisesRegex(ReplayFileError, "duplicate JSON key"):
            decode_replay(b'{"a":1,"a":2}')
        with self.assertRaisesRegex(ReplayFileError, "not canonical"):
            decode_replay(b'{ "schemaVersion":1}')
        with self.assertRaisesRegex(ReplayFileError, "no larger"):
            decode_replay(b" " * (MAX_REPLAY_BYTES + 1))
        self.assertTrue(canonical.startswith(b'{"checkpoints":'))

    def test_decode_rejects_boolean_schema_version(self) -> None:
        value = json.loads(encode_replay(ReplayFile(self.header(), ())))
        value["schemaVersion"] = True
        encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
        with self.assertRaisesRegex(ReplayFileError, "unsupported replay JSON value: bool"):
            decode_replay(encoded)

    def test_checkpoint_is_checked_after_authoritative_submission(self) -> None:
        expected_state = "c" * 64
        replay = ReplayFile(self.header(), (self.command(),),
                            (ReplayCheckpoint(1, expected_state),), terminal=True)
        result = verify_replay(
            replay,
            expected_ruleset=RULESET_VERSION,
            expected_content_digest="a" * 64,
            initialize=lambda _header: "b" * 64,
            submit=lambda _command: ReplayRunStep(True, expected_state, terminal=True),
        )
        self.assertEqual(result.final_state_digest, expected_state)
        tampered = ReplayFile(self.header(), replay.commands,
                              (ReplayCheckpoint(1, "d" * 64),), terminal=True)
        with self.assertRaisesRegex(ReplayFileError, "checkpoint mismatch"):
            verify_replay(tampered, expected_ruleset=RULESET_VERSION,
                          expected_content_digest="a" * 64,
                          initialize=lambda _header: "b" * 64,
                          submit=lambda _command: ReplayRunStep(True, expected_state, True))

    def test_authoritative_runner_must_accept_every_command(self) -> None:
        replay = ReplayFile(self.header(), (self.command(),))
        with self.assertRaisesRegex(ReplayFileError, "rejected command 0"):
            verify_replay(replay, expected_ruleset=RULESET_VERSION,
                          expected_content_digest="a" * 64,
                          initialize=lambda _header: "b" * 64,
                          submit=lambda _command: ReplayRunStep(False, "c" * 64))

    def test_runner_rejects_terminal_or_identity_disagreement(self) -> None:
        replay = ReplayFile(self.header(), (self.command(),))
        runner = lambda _command: ReplayRunStep(True, "c" * 64, True)
        with self.assertRaisesRegex(ReplayFileError, "terminal result"):
            verify_replay(replay, expected_ruleset=RULESET_VERSION,
                          expected_content_digest="a" * 64,
                          initialize=lambda _header: "b" * 64, submit=runner)
        with self.assertRaisesRegex(ReplayFileError, "project content identity"):
            verify_replay(replay, expected_ruleset=RULESET_VERSION,
                          expected_content_digest="d" * 64,
                          initialize=lambda _header: "b" * 64, submit=runner)


if __name__ == "__main__":
    unittest.main()
