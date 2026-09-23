from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.learning_state import (  # noqa: E402
    IndividualLearning,
    LearningStateCodecError,
    RecipeHarmony,
    decode_learning_state,
    encode_learning_state,
)
from persistence.save_identity import SaveIdentity  # noqa: E402


class LearningStateCodecTests(unittest.TestCase):
    def setUp(self) -> None:
        self.identity = SaveIdentity(1, "m6-1", "a" * 64)
        self.roster = (12, 3, 90)
        self.known = (2, 4, 7, 9)
        self.records = (
            IndividualLearning(12, (4, 7), (RecipeHarmony(4, 40),)),
            IndividualLearning(3, (), ()),
            IndividualLearning(90, (2, 9), (RecipeHarmony(2, 6), RecipeHarmony(9, 0))),
        )

    def test_round_trip_preserves_every_roster_member_and_progress(self) -> None:
        encoded = encode_learning_state(self.identity, self.roster, self.records,
                                        known_recipe_ids=self.known)
        decoded = decode_learning_state(encoded, self.identity, self.roster,
                                        known_recipe_ids=self.known)
        self.assertEqual(decoded, self.records)
        self.assertIn(b'"individualId":3', encoded)
        self.assertIn(b'"progress":40', encoded)

    def test_exact_ruleset_content_and_schema_identity_are_required(self) -> None:
        encoded = encode_learning_state(self.identity, self.roster, self.records,
                                        known_recipe_ids=self.known)
        with self.assertRaisesRegex(LearningStateCodecError, "content identity mismatch"):
            decode_learning_state(encoded, SaveIdentity(1, "m6-1", "b" * 64),
                                  self.roster, known_recipe_ids=self.known)
        with self.assertRaisesRegex(LearningStateCodecError, "requires ruleset 'm6-1'"):
            decode_learning_state(encoded, SaveIdentity(1, "m3-1", "a" * 64),
                                  self.roster, known_recipe_ids=self.known)
        with self.assertRaisesRegex(LearningStateCodecError, "requires ruleset 'm6-1'"):
            encode_learning_state(SaveIdentity(1, "m3-1", "a" * 64),
                                  self.roster, self.records,
                                  known_recipe_ids=self.known)
        with self.assertRaisesRegex(LearningStateCodecError, "schema version mismatch"):
            decode_learning_state(encoded, SaveIdentity(2, "m6-1", "a" * 64),
                                  self.roster, known_recipe_ids=self.known)

    def test_missing_duplicate_and_unknown_participants_reject(self) -> None:
        with self.assertRaisesRegex(LearningStateCodecError, "missing roster"):
            encode_learning_state(self.identity, self.roster, self.records[:-1],
                                  known_recipe_ids=self.known)
        with self.assertRaisesRegex(LearningStateCodecError, "duplicate learning record"):
            encode_learning_state(self.identity, self.roster,
                                  self.records + (self.records[0],),
                                  known_recipe_ids=self.known)
        with self.assertRaisesRegex(LearningStateCodecError, "non-roster"):
            encode_learning_state(
                self.identity,
                self.roster,
                self.records[:-1] + (IndividualLearning(91, (), ()),),
                known_recipe_ids=self.known,
            )
        with self.assertRaisesRegex(LearningStateCodecError, "duplicate roster"):
            encode_learning_state(self.identity, (12, 12), (self.records[0],),
                                  known_recipe_ids=self.known)

    def test_duplicate_or_malformed_recipe_data_rejects(self) -> None:
        malformed = (
            IndividualLearning(12, (4, 4), ()),
            IndividualLearning(12, (7, 4), ()),
            IndividualLearning(12, (), (RecipeHarmony(2, 1), RecipeHarmony(2, 2))),
            IndividualLearning(12, (), (RecipeHarmony(2, 41),)),
            IndividualLearning(12, (), (RecipeHarmony(2, True),)),
            IndividualLearning(12, (), (RecipeHarmony(2, 1),)),
        )
        for record in malformed:
            records = (record,) + self.records[1:]
            with self.subTest(record=record), self.assertRaises(LearningStateCodecError):
                encode_learning_state(self.identity, self.roster, records,
                                      known_recipe_ids=self.known)

    def test_decoder_rejects_noncanonical_and_duplicate_json(self) -> None:
        duplicate_key = b'{"identity":{},"identity":{},"participants":[]}'
        with self.assertRaisesRegex(LearningStateCodecError, "duplicate JSON"):
            decode_learning_state(duplicate_key, self.identity, (),
                                  known_recipe_ids=self.known)
        encoded = encode_learning_state(self.identity, self.roster, self.records,
                                        known_recipe_ids=self.known)
        with self.assertRaisesRegex(LearningStateCodecError, "not canonical"):
            decode_learning_state(encoded + b" ", self.identity, self.roster,
                                  known_recipe_ids=self.known)
        with self.assertRaisesRegex(LearningStateCodecError, "valid UTF-8 JSON"):
            decode_learning_state(b"\xff", self.identity, self.roster,
                                  known_recipe_ids=self.known)

    def test_unknown_catalog_recipe_rejects_before_save_install(self) -> None:
        with self.assertRaisesRegex(LearningStateCodecError, "unknown observed recipe"):
            encode_learning_state(self.identity, self.roster, self.records,
                                  known_recipe_ids=(2, 4, 9))
        encoded = encode_learning_state(self.identity, self.roster, self.records,
                                        known_recipe_ids=self.known)
        with self.assertRaisesRegex(LearningStateCodecError, "unknown observed recipe"):
            decode_learning_state(encoded, self.identity, self.roster,
                                  known_recipe_ids=(2, 4, 9))


if __name__ == "__main__":
    unittest.main()
