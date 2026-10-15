"""Focused tests for the M11 progression value codec."""

from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.m11_progression import (
    M11ProgressionError,
    decode_m11_progression,
    decode_m11_progression_tokens,
    encode_m11_progression,
    encode_m11_progression_tokens,
)
from persistence.canonical_json import canonical_json


def sample_value() -> dict[str, object]:
    cap = {"party": 6, "moves": 4, "storage": 1000, "stack": 999,
           "entries": 512, "currency": 9_999_999}
    stats = {"hp": 12, "attack": 5, "defense": 5, "special_attack": 5,
             "special_defense": 5, "speed": 5}
    individual = {"id": 41, "species": 8, "level": 3, "xp": 351,
                  "currentHp": 10, "maxHp": 12, "ivs": stats,
                  "moves": [3, 6], "moveHistory": [
                      {"kind": "learned", "move": 3},
                      {"kind": "replaced", "offered": 6, "removed": 2},
                      {"kind": "declined", "move": 7}],
                  "observations": [8, 9], "unlocks": [1], "harmony": [2, 3]}
    return {"economy": {"capacity": cap, "tier": 0, "party": 1, "storage": 0,
                        "equippedMoves": 2, "currency": 25,
                        "inventory": [{"item": 11, "quantity": 2}]},
            "roster": {"capacity": cap, "party": [41], "storage": []},
            "owned": [{"individual": individual, "base": stats, "ivs": stats,
                       "alive": 1, "previouslyActive": 1}],
            "ledger": {"completedEncounters": [501, 502]},
            "ruleset": 7, "contentIdentity": 1234}


def bend_encoder_fixture() -> dict[str, object]:
    cap = {"party": 6, "moves": 4, "storage": 1000, "stack": 999,
           "entries": 512, "currency": 9_999_999}
    ivs = {"hp": 0, "attack": 0, "defense": 0, "special_attack": 0,
           "special_defense": 0, "speed": 0}
    base = {"hp": 50, "attack": 100, "defense": 100, "special_attack": 100,
            "special_defense": 100, "speed": 100}
    individual = {"id": 77, "species": 4, "level": 2, "xp": 100,
        "currentHp": 9, "maxHp": 14, "ivs": ivs, "moves": [3, 4, 5, 6],
        "moveHistory": [{"kind": "learned", "move": 7},
            {"kind": "replaced", "offered": 8, "removed": 9},
            {"kind": "declined", "move": 10}], "observations": [11, 12],
        "unlocks": [13], "harmony": [1, 2]}
    return {"economy": {"capacity": cap, "tier": 0, "party": 1, "storage": 0,
        "equippedMoves": 4, "currency": 5, "inventory": [{"item": 9, "quantity": 2}]},
        "roster": {"capacity": cap, "party": [77], "storage": []},
        "owned": [{"individual": individual, "base": base, "ivs": ivs,
                   "alive": 1, "previouslyActive": 1}],
        "ledger": {"completedEncounters": [7, 8]}, "ruleset": 7, "contentIdentity": 123}


def bend_expected_tokens() -> tuple[int, ...]:
    return (1, 77, 6, 4, 1000, 999, 512, 9999999, 0, 1, 0, 4, 5,
        1, 9, 2, 6, 4, 1000, 999, 512, 9999999, 1, 77, 0,
        1, 47, 77, 4, 2, 100, 9, 14, 0, 0, 0, 0, 0, 0,
        4, 3, 4, 5, 6, 3, 0, 7, 1, 8, 9, 2, 10,
        2, 11, 12, 1, 13, 2, 1, 2, 50, 100, 100, 100, 100, 100,
        0, 0, 0, 0, 0, 0, 1, 1, 2, 7, 8, 7, 123)


class M11ProgressionCodecTests(unittest.TestCase):
    def test_full_payload_round_trip_preserves_all_durable_fields(self) -> None:
        value = sample_value()
        state = decode_m11_progression(value)
        self.assertEqual(encode_m11_progression(state), value)
        self.assertIs(state.owned[0].alive, True)
        self.assertIs(state.owned[0].previously_active, True)
        self.assertEqual([entry.kind for entry in state.owned[0].individual.move_history],
                         ["learned", "replaced", "declined"])
        self.assertEqual(state.owned[0].base.hp, 12)
        self.assertEqual(state.owned[0].ivs.speed, 5)
        self.assertEqual(state.ledger.completed_encounters, (501, 502))

    def test_canonical_json_compatibility_and_wire_boolean_tokens(self) -> None:
        state = decode_m11_progression(sample_value())
        encoded = encode_m11_progression(state)
        self.assertEqual(encoded["owned"][0]["alive"], 1)
        self.assertEqual(encoded["owned"][0]["previouslyActive"], 1)
        self.assertIsInstance(canonical_json(encoded), bytes)
        self.assertIsInstance(canonical_json({"progression": encoded}), bytes)
        malformed_flag = sample_value()
        malformed_flag["owned"][0]["alive"] = True  # type: ignore[index]
        with self.assertRaises(M11ProgressionError):
            decode_m11_progression(malformed_flag)

    def test_unknown_active_field_and_boolean_integer_are_rejected(self) -> None:
        active = sample_value()
        active["battleActive"] = False
        with self.assertRaises(M11ProgressionError):
            decode_m11_progression(active)
        malformed = sample_value()
        malformed["economy"]["currency"] = True  # type: ignore[index]
        with self.assertRaises(M11ProgressionError):
            decode_m11_progression(malformed)

    def test_roster_requires_unique_membership_matching_owned_records(self) -> None:
        value = sample_value()
        value["roster"]["storage"] = [41]  # type: ignore[index]
        with self.assertRaises(M11ProgressionError):
            decode_m11_progression(value)

    def test_history_variants_reject_extra_or_missing_fields(self) -> None:
        value = copy.deepcopy(sample_value())
        value["owned"][0]["individual"]["moveHistory"][1]["extra"] = 0  # type: ignore[index]
        with self.assertRaises(M11ProgressionError):
            decode_m11_progression(value)

    def test_wire_tokens_match_bend_encoder_fixture_and_round_trip(self) -> None:
        state = decode_m11_progression(bend_encoder_fixture())
        self.assertEqual(encode_m11_progression_tokens(state), bend_expected_tokens())
        self.assertEqual(decode_m11_progression_tokens(bend_expected_tokens()), state)

    def test_wire_rejects_wrong_version_count_truncation_trailing_and_bad_history_tag(self) -> None:
        tokens = bend_expected_tokens()
        invalid_rows = [
            ("nested token", (tokens[0], (tokens[1],)) + tokens[2:]),
            ("wrong version", (2,) + tokens[1:]),
            ("wrong count", (1, tokens[1] + 1) + tokens[2:]),
            ("truncated", tokens[:-1]),
            ("trailing", tokens + (0,)),
            ("boolean token", tuple(True if i == 2 else token
                                     for i, token in enumerate(tokens))),
            ("unknown history tag", tokens[:45] + (9,) + tokens[46:]),
            ("short owned record", tokens[:26] + (46,) + tokens[27:]),
            ("long owned record", tokens[:26] + (48,) + tokens[27:]),
        ]
        for label, invalid in invalid_rows:
            with self.subTest(case=label), self.assertRaises(M11ProgressionError):
                decode_m11_progression_tokens(invalid)

    def test_wire_payload_token_limit_excludes_two_header_tokens(self) -> None:
        at_limit = (1, 4096) + (0,) * 4096
        with self.assertRaisesRegex(M11ProgressionError, "trailing tokens"):
            decode_m11_progression_tokens(at_limit)
        over_limit = (1, 4097) + (0,) * 4097
        with self.assertRaisesRegex(M11ProgressionError, "exceeds 4096 tokens"):
            decode_m11_progression_tokens(over_limit)


if __name__ == "__main__":
    unittest.main()
