from __future__ import annotations

import json
import random
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.battle_replay import RNG_VERSION, RULESET_VERSION  # noqa: E402
from persistence.m11_replay import (  # noqa: E402
    AcceptedCommand, ReplayFile, ReplayHeader, ReplayFileError,
    decode_replay, encode_replay,
)
from persistence.m11_save import (  # noqa: E402
    M11Save, M11SaveError, SaveExpectation, decode_m11_save, encode_m11_save,
)
from persistence.canonical_json import canonical_json, canonical_sha256  # noqa: E402
from persistence.world_state import WorldSnapshot  # noqa: E402


class CodecFuzzTests(unittest.TestCase):
    def test_seeded_save_and_replay_codec_round_trip_and_byte_fuzz(self) -> None:
        seed = 0x4D313243
        randomizer = random.Random(seed)
        expectation = SaveExpectation("m8-1", "a" * 64, "project.demo", "catalog.main")
        snapshot = WorldSnapshot(3, -12, 2, 99, 4, 180, 100_000, 15,
                                 (1, 2, 3, 4), ((2, 1), (9, 42)), (7, 12))
        save = M11Save("build-11", "project.demo", "catalog.main", "m8-1",
                       "a" * 64, 60, snapshot, (11, 12, 13, 14), ())
        replay = ReplayFile(
            ReplayHeader(RULESET_VERSION, "a" * 64, RNG_VERSION, (1, 2, 3, 4),
                         60, "build-11", {"world": {"map": 3}, "party": [4, 5]}),
            (AcceptedCommand(0, 0, 0, 0, {"kind": "wait"}),),
        )
        save_bytes = encode_m11_save(save)
        replay_bytes = encode_replay(replay)
        self.assertEqual(encode_m11_save(decode_m11_save(save_bytes, expectation)), save_bytes)
        self.assertEqual(encode_replay(decode_replay(
            replay_bytes, expected_content_digest="a" * 64)), replay_bytes)

        # Start with canonical envelopes, then make reproducible byte and
        # structured mutations. Every mutation must reject through its codec.
        save_semantic = []
        invalid_world_values = (
            ("mapId", 0), ("mapId", -1), ("position", "x", 524289),
            ("position", "y", -524289), ("rng", "state", [0, 0, 0, 0]),
            ("encounter", "threshold", 0), ("encounter", "safeDistance", 12289),
            ("persistentValues", [[2, 1, 3]]),
            ("acceptedCommands", [{"kind": "not-a-command"}]),
        )
        for index in range(64):
            value = json.loads(save_bytes)
            mutation = invalid_world_values[index % len(invalid_world_values)]
            payload = value["payload"]
            if mutation[0] == "position":
                delta = index % 100
                sign = 1 if mutation[2] > 0 else -1
                payload["world"]["position"][mutation[1]] = mutation[2] + sign * delta
            elif mutation[0] == "rng":
                payload["world"]["rng"][mutation[1]] = mutation[2]
            elif mutation[0] == "encounter":
                payload["world"]["encounter"][mutation[1]] = mutation[2] + index
            elif mutation[0] == "persistentValues":
                payload["world"][mutation[0]] = mutation[1]
            elif mutation[0] == "acceptedCommands":
                payload[mutation[0]] = mutation[1]
            else:
                payload["world"][mutation[0]] = mutation[1]
            value["payloadDigest"] = canonical_sha256(payload)
            save_semantic.append(canonical_json(value))

        replay_semantic = []
        for index in range(64):
            value = json.loads(replay_bytes)
            shape = index % 8
            if shape == 0: value["schemaVersion"] = 2
            elif shape == 1: value["terminal"] = 2
            elif shape == 2: value["header"]["waitTicks"] = 45
            elif shape == 3: value["header"]["engineBuild"] = ""
            elif shape == 4: value["header"]["rng"]["state"] = [0, 0, 0, 0]
            elif shape == 5: value["header"]["initialState"]["bad"] = True
            elif shape == 6: value["commands"][0]["actorId"] = -1
            else: value["commands"][0]["commandOrdinal"] = 1
            replay_semantic.append(json.dumps(value, sort_keys=True,
                                               separators=(",", ":")).encode())

        huge_integer = b'{"n":' + b"9" * 5000 + b"}"
        save_bytes_fuzz = [save_bytes + b" ", save_bytes.replace(b'"payload"', b'"z"'),
                           b'{"x":1,"x":2}', b"\xff", b"{}\n", huge_integer]
        replay_bytes_fuzz = [replay_bytes + b" ", replay_bytes.replace(b'"terminal":0', b'"terminal":2'),
                             b'{"x":1,"x":2}', b"\xff", b"{}\n", huge_integer]
        for _ in range(58):
            save_bytes_fuzz.append(bytes(randomizer.randrange(256) for _ in
                                         range(randomizer.randrange(0, 96))))
            replay_bytes_fuzz.append(bytes(randomizer.randrange(256) for _ in
                                           range(randomizer.randrange(0, 96))))
        self.assertEqual(len(save_semantic), 64)
        self.assertEqual(len(replay_semantic), 64)
        self.assertEqual(len(save_bytes_fuzz), 64)
        self.assertEqual(len(replay_bytes_fuzz), 64)
        for index, raw in enumerate(save_semantic):
            with self.subTest(seed=seed, codec="save", case=index):
                with self.assertRaises(M11SaveError):
                    decode_m11_save(raw, expectation)
        for index, raw in enumerate(replay_semantic):
            with self.subTest(seed=seed, codec="replay", case=index):
                with self.assertRaises(ReplayFileError):
                    decode_replay(raw)
        save_bytes_rejected = save_bytes_accepted = 0
        replay_bytes_rejected = replay_bytes_accepted = 0
        for index, raw in enumerate(save_bytes_fuzz):
            with self.subTest(seed=seed, codec="save-byte", case=index):
                try:
                    decoded = decode_m11_save(raw, expectation)
                except M11SaveError:
                    save_bytes_rejected += 1
                else:
                    self.assertEqual(encode_m11_save(decoded), raw)
                    save_bytes_accepted += 1
        for index, raw in enumerate(replay_bytes_fuzz):
            with self.subTest(seed=seed, codec="replay-byte", case=index):
                try:
                    decoded = decode_replay(raw)
                except ReplayFileError:
                    replay_bytes_rejected += 1
                else:
                    self.assertEqual(encode_replay(decoded), raw)
                    replay_bytes_accepted += 1
        self.assertEqual(save_bytes_rejected + save_bytes_accepted, 64)
        self.assertEqual(replay_bytes_rejected + replay_bytes_accepted, 64)
        self.assertEqual((save_bytes_rejected, save_bytes_accepted), (64, 0))
        self.assertEqual((replay_bytes_rejected, replay_bytes_accepted), (64, 0))


if __name__ == "__main__":
    unittest.main()
