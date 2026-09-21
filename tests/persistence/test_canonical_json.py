from __future__ import annotations

import hashlib
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.canonical_json import (  # noqa: E402
    CanonicalJSONError,
    canonical_json,
    canonical_json_sha256,
    canonical_sha256,
)


class CanonicalJSONTests(unittest.TestCase):
    def test_object_key_order_is_canonical_and_compact(self) -> None:
        first = {"z": 1, "a": {"y": 2, "x": 3}}
        second = {"a": {"x": 3, "y": 2}, "z": 1}
        self.assertEqual(canonical_json(first), b'{"a":{"x":3,"y":2},"z":1}')
        self.assertEqual(canonical_json(first), canonical_json(second))

    def test_unicode_is_encoded_as_utf8(self) -> None:
        encoded = canonical_json({"café": "雪"})
        self.assertEqual(encoded, '{"café":"雪"}'.encode("utf-8"))

    def test_arrays_preserve_semantic_order(self) -> None:
        self.assertEqual(canonical_json([3, {"b": 2, "a": 1}, 1]), b'[3,{"a":1,"b":2},1]')
        self.assertNotEqual(canonical_json([1, 2]), canonical_json([2, 1]))

    def test_integer_only_numeric_policy_rejects_float_and_bool(self) -> None:
        for value in (1.0, float("inf"), True, False, {"flag": True}, [1.5]):
            with self.subTest(value=value), self.assertRaises(CanonicalJSONError):
                canonical_json(value)

    def test_non_string_object_keys_are_rejected(self) -> None:
        with self.assertRaises(CanonicalJSONError):
            canonical_json({1: "would otherwise be coerced"})

    def test_null_and_negative_integers_are_supported(self) -> None:
        self.assertEqual(canonical_json({"n": None, "i": -12}), b'{"i":-12,"n":null}')

    def test_digest_is_deterministic_and_matches_sha256(self) -> None:
        value = {"items": [1, 2], "name": "save"}
        expected = hashlib.sha256(canonical_json(value)).hexdigest()
        self.assertEqual(canonical_sha256(value), expected)
        self.assertEqual(canonical_json_sha256(value), expected)

    def test_digest_changes_when_content_changes(self) -> None:
        self.assertNotEqual(canonical_sha256({"value": 1}), canonical_sha256({"value": 2}))
        self.assertNotEqual(canonical_sha256(["a", "b"]), canonical_sha256(["b", "a"]))

    def test_surrogates_and_recursive_containers_are_rejected(self) -> None:
        with self.assertRaises(CanonicalJSONError):
            canonical_json("\ud800")
        recursive: list[object] = []
        recursive.append(recursive)
        with self.assertRaises(CanonicalJSONError):
            canonical_json(recursive)


if __name__ == "__main__":
    unittest.main()
