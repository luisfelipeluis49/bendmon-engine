from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))

from persistence.m11_save import M11Save, SaveExpectation, encode_m11_save
from persistence.save_slots import (
    AUTOSAVE_SLOT, MANUAL_SLOTS, SLOT_NAMES, SaveSlotError, SaveSlotStore,
)
from persistence.world_state import WorldSnapshot


class MemorySaveIO:
    """Named in-memory filesystem with one-shot operation interruption."""

    def __init__(self) -> None:
        self.files: dict[str, bytes] = {}
        self.calls: dict[str, int] = {}
        self.fail_at: tuple[str, int] | None = None

    def _step(self, name: str) -> None:
        count = self.calls.get(name, 0) + 1
        self.calls[name] = count
        if self.fail_at == (name, count):
            self.fail_at = None
            raise OSError(f"injected {name} interruption #{count}")

    def exists(self, path: Path) -> bool:
        return str(path) in self.files

    def read(self, path: Path) -> bytes:
        self._step("read")
        return self.files[str(path)]

    def remove(self, path: Path) -> None:
        self._step("remove")
        self.files.pop(str(path), None)

    def write(self, path: Path, data: bytes) -> None:
        self._step("write")
        self.files[str(path)] = data

    def fsync_file(self, path: Path) -> None:
        self._step("fsync_file")

    def replace(self, source: Path, target: Path) -> None:
        self._step("replace")
        self.files[str(target)] = self.files.pop(str(source))

    def fsync_directory(self, path: Path) -> None:
        self._step("fsync_directory")


class SaveSlotTests(unittest.TestCase):
    def setUp(self) -> None:
        self.io = MemorySaveIO()
        self.store = SaveSlotStore(Path("/saves"), self.io)
        self.expected = SaveExpectation("m8-1", "a" * 64, "game", "main")

    def save(self, x: int) -> M11Save:
        return M11Save("build", "game", "main", "m8-1", "a" * 64, 60,
                       WorldSnapshot(1, x, 0, 0, None, 0, 0, 0,
                                     (1, 2, 3, 4), (), ()))

    def test_policy_has_ten_manual_slots_and_one_rotating_autosave(self) -> None:
        self.assertEqual(len(MANUAL_SLOTS), 10)
        self.assertEqual(len(SLOT_NAMES), 11)
        self.assertEqual(SLOT_NAMES[-1], AUTOSAVE_SLOT)
        for slot in SLOT_NAMES:
            self.store.save(slot, self.save(1))
            self.assertEqual(self.store.load(slot, self.expected)[0], self.save(1))
        with self.assertRaisesRegex(SaveSlotError, "unknown save slot"):
            self.store.save("../escape", self.save(2))

    def test_rotation_keeps_verified_previous_copy_and_corrupt_primary_recovers(self) -> None:
        self.store.save("manual-01", self.save(10))
        self.store.save("manual-01", self.save(20))
        primary = self.store._path("manual-01")
        self.io.files[str(primary)] = b"corrupt primary"
        loaded, recovered = self.store.load("manual-01", self.expected)
        self.assertEqual(loaded, self.save(10))
        self.assertTrue(recovered)

    def test_replacing_slot_after_content_edit_establishes_new_identity_recovery(self) -> None:
        self.store.save("manual-01", self.save(10))
        self.store.save("manual-01", self.save(20))
        newer = M11Save("build", "game", "main", "m8-1", "b" * 64, 60,
                        self.save(30).snapshot)
        self.store.save("manual-01", newer)
        primary = self.store._path("manual-01")
        self.io.files[str(primary)] = b"corrupt"
        restored, recovered = self.store.load("manual-01", SaveExpectation(
            "m8-1", "b" * 64, "game", "main"))
        self.assertEqual(restored, newer)
        self.assertTrue(recovered)

    def test_invalid_primary_and_recovery_never_install(self) -> None:
        primary = self.store._path("autosave")
        recovery = self.store._recovery("autosave")
        self.io.files[str(primary)] = b"corrupt"
        self.io.files[str(recovery)] = b"also corrupt"
        with self.assertRaisesRegex(SaveSlotError, "no valid save copy"):
            self.store.load("autosave", self.expected)

    def test_deep_or_huge_integer_primary_uses_verified_recovery(self) -> None:
        self.store.save("manual-01", self.save(10))
        self.store.save("manual-01", self.save(20))
        primary = self.store._path("manual-01")
        for corrupt in (b"[" * 1200 + b"]" * 1200,
                        b"{" + b'"value":' + b"9" * 5000 + b"}"):
            with self.subTest(corrupt=corrupt[:12]):
                self.io.files[str(primary)] = corrupt
                loaded, recovered = self.store.load("manual-01", self.expected)
                self.assertTrue(recovered)
                self.assertEqual(loaded, self.save(10))

    def test_interruption_at_each_write_boundary_leaves_a_loadable_copy(self) -> None:
        operations = (("remove", 2), ("write", 2), ("fsync_file", 2),
                      ("replace", 2), ("fsync_directory", 2))
        for operation, count in operations:
            with self.subTest(operation=operation):
                io = MemorySaveIO()
                store = SaveSlotStore(Path("/saves"), io)
                store.save("manual-02", self.save(10))
                io.calls.clear()
                io.fail_at = (operation, count)
                with self.assertRaises(OSError):
                    store.save("manual-02", self.save(20))
                loaded, _ = store.load("manual-02", self.expected)
                self.assertIn(loaded, (self.save(10), self.save(20)))
                self.assertTrue(io.exists(store._path("manual-02"))
                                or io.exists(store._recovery("manual-02")))

    def test_migration_readback_failure_keeps_legacy_primary(self) -> None:
        # Migration staging does a readback before the original moves to recovery.
        io = MemorySaveIO()
        store = SaveSlotStore(Path("/saves"), io)
        from persistence.save_identity import SaveIdentity
        from persistence.world_state import encode_world_state
        legacy = encode_world_state(SaveIdentity(1, "m8-1", "a" * 64), self.save(8).snapshot)
        path = store._path("manual-03")
        io.files[str(path)] = legacy
        io.fail_at = ("read", 2)
        with self.assertRaises(OSError):
            store.migrate_slot("manual-03", self.expected, engine_build="build", wait_ticks=60)
        self.assertEqual(io.files[str(path)], legacy)
        self.assertFalse(io.exists(store._recovery("manual-03")))

    def test_successful_migration_retains_legacy_recovery(self) -> None:
        from persistence.save_identity import SaveIdentity
        from persistence.world_state import encode_world_state
        legacy = encode_world_state(SaveIdentity(1, "m8-1", "a" * 64), self.save(8).snapshot)
        path = self.store._path("manual-04")
        self.io.files[str(path)] = legacy
        migrated = self.store.migrate_slot("manual-04", self.expected,
                                           engine_build="build", wait_ticks=60)
        self.assertEqual(migrated.snapshot.x, 8)
        self.assertEqual(self.io.files[str(self.store._recovery("manual-04"))], legacy)
        self.assertEqual(self.store.load("manual-04", self.expected)[0], migrated)
        self.io.files[str(path)] = b"corrupt v2 primary"
        with self.assertRaisesRegex(SaveSlotError, "no valid save copy"):
            self.store.load("manual-04", self.expected)
        recovered, used_recovery = self.store.load(
            "manual-04", self.expected, migrate_legacy_recovery=True,
            engine_build="build", wait_ticks=60,
        )
        self.assertEqual(recovered, migrated)
        self.assertTrue(used_recovery)


if __name__ == "__main__":
    unittest.main()
