"""Durable fixed-policy save slots with a verified recovery copy."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Protocol

from .m11_save import (
    M11Save, M11SaveError, SaveExpectation, decode_m11_save, encode_m11_save,
    migrate_m8_v1_to_v2,
)

MANUAL_SLOT_COUNT = 10
AUTOSAVE_SLOT = "autosave"
MANUAL_SLOTS = tuple(f"manual-{number:02d}" for number in range(1, MANUAL_SLOT_COUNT + 1))
SLOT_NAMES = (*MANUAL_SLOTS, AUTOSAVE_SLOT)


class SaveSlotError(OSError):
    """A slot operation failed without discarding the prior valid copy."""


class SaveIO(Protocol):
    """Named host operations allow deterministic interruption testing."""

    def exists(self, path: Path) -> bool: ...
    def read(self, path: Path) -> bytes: ...
    def remove(self, path: Path) -> None: ...
    def write(self, path: Path, data: bytes) -> None: ...
    def fsync_file(self, path: Path) -> None: ...
    def replace(self, source: Path, target: Path) -> None: ...
    def fsync_directory(self, path: Path) -> None: ...


class LocalSaveIO:
    """Filesystem adapter using same-directory replacement and durability syncs."""

    def exists(self, path: Path) -> bool:
        return path.exists()

    def read(self, path: Path) -> bytes:
        return path.read_bytes()

    def remove(self, path: Path) -> None:
        try:
            path.unlink()
        except FileNotFoundError:
            pass

    def write(self, path: Path, data: bytes) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("wb") as stream:
            stream.write(data)
            stream.flush()

    def fsync_file(self, path: Path) -> None:
        descriptor = os.open(path, os.O_RDONLY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)

    def replace(self, source: Path, target: Path) -> None:
        os.replace(source, target)

    def fsync_directory(self, path: Path) -> None:
        descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)


class SaveSlotStore:
    """Manage ten manual slots, a rotating autosave and one recovery per slot."""

    def __init__(self, root: Path, io: SaveIO | None = None) -> None:
        self.root = Path(root)
        self.io: SaveIO = io or LocalSaveIO()

    def _path(self, slot: str) -> Path:
        if type(slot) is not str or slot not in SLOT_NAMES:
            raise SaveSlotError(f"unknown save slot: {slot!r}")
        return self.root / f"{slot}.json"

    def _recovery(self, slot: str) -> Path:
        return self.root / f"{slot}.recovery.json"

    def _atomic(self, target: Path, data: bytes) -> None:
        temporary = target.with_name(f".{target.name}.pending")
        try:
            self.io.remove(temporary)
            self.io.write(temporary, data)
            self.io.fsync_file(temporary)
            if self.io.read(temporary) != data:
                raise SaveSlotError(f"staged save readback differs for {target.name}")
            self.io.replace(temporary, target)
            self.io.fsync_directory(target.parent)
        except Exception:
            # A failed replacement leaves the target intact; a failed directory
            # sync may have installed it, so the verified recovery remains vital.
            raise
        finally:
            self.io.remove(temporary)

    def save(self, slot: str, save: M11Save) -> None:
        """Persist a verified envelope while retaining the prior valid bytes."""
        target = self._path(slot)
        recovery = self._recovery(slot)
        encoded = encode_m11_save(save)
        target_valid = False
        if self.io.exists(target):
            previous = self.io.read(target)
            try:
                decode_m11_save(previous, SaveExpectation(
                    save.ruleset_version, save.content_digest,
                    save.project_id, save.catalog_id,
                ))
                target_valid = True
            except M11SaveError:
                target_valid = False
        if target_valid:
            self._atomic(recovery, previous)
        else:
            # Replacing a slot after an intentional project edit must not be
            # blocked by copies tied to the older content digest. Establish a
            # same-identity recovery before installing the new primary.
            self._atomic(recovery, encoded)
        self._atomic(target, encoded)

    @staticmethod
    def _is_m8_v1(encoded: bytes) -> bool:
        try:
            value = json.loads(encoded.decode("utf-8"))
            identity = value.get("identity") if type(value) is dict else None
            return (type(identity) is dict
                    and type(identity.get("saveSchemaVersion")) is int
                    and identity["saveSchemaVersion"] == 1
                    and identity.get("rulesetVersion") == "m8-1")
        except (UnicodeDecodeError, json.JSONDecodeError):
            return False

    def load(
        self, slot: str, expected: SaveExpectation, *,
        migrate_legacy_recovery: bool = False, engine_build: str | None = None,
        wait_ticks: int | None = None,
    ) -> tuple[M11Save, bool]:
        """Load a verified save, optionally migrating an M8-v1 recovery copy.

        Legacy recovery migration is explicit because schema 1 does not carry
        the M11 build or Wait metadata needed to construct its v2 envelope.
        """
        if type(migrate_legacy_recovery) is not bool:
            raise SaveSlotError("migrate_legacy_recovery must be a boolean")
        if migrate_legacy_recovery and (engine_build is None or wait_ticks is None):
            raise SaveSlotError("legacy recovery migration requires engine_build and wait_ticks")
        target = self._path(slot)
        recovery = self._recovery(slot)
        failures: list[str] = []
        for path, recovered in ((target, False), (recovery, True)):
            if not self.io.exists(path):
                continue
            try:
                encoded = self.io.read(path)
                try:
                    return decode_m11_save(encoded, expected), recovered
                except M11SaveError:
                    if recovered and migrate_legacy_recovery and self._is_m8_v1(encoded):
                        migrated = migrate_m8_v1_to_v2(
                            encoded, expected, engine_build=engine_build,
                            wait_ticks=wait_ticks,
                        )
                        return migrated, True
                    raise
            except (M11SaveError, OSError) as exc:
                failures.append(f"{path.name}: {exc}")
        if not failures:
            raise SaveSlotError(f"save slot {slot!r} does not exist")
        raise SaveSlotError("no valid save copy; " + "; ".join(failures))

    def migrate_slot(
        self, slot: str, expected: SaveExpectation, *, engine_build: str,
        wait_ticks: int,
    ) -> M11Save:
        """Migrate legacy v1, verify v2 readback, then install with v1 recovery."""
        target = self._path(slot)
        if not self.io.exists(target):
            raise SaveSlotError(f"save slot {slot!r} does not exist")
        original = self.io.read(target)
        migrated = migrate_m8_v1_to_v2(
            original, expected, engine_build=engine_build, wait_ticks=wait_ticks,
        )
        encoded = encode_m11_save(migrated)
        # Stage and validate before moving either the original or the target.
        temporary = target.with_name(f".{target.name}.pending")
        self.io.remove(temporary)
        try:
            self.io.write(temporary, encoded)
            self.io.fsync_file(temporary)
            verified = decode_m11_save(self.io.read(temporary), expected)
            self._atomic(self._recovery(slot), original)
            self.io.replace(temporary, target)
            self.io.fsync_directory(target.parent)
            return verified
        finally:
            self.io.remove(temporary)


__all__ = ["AUTOSAVE_SLOT", "MANUAL_SLOT_COUNT", "MANUAL_SLOTS", "SLOT_NAMES",
           "LocalSaveIO", "SaveIO", "SaveSlotError", "SaveSlotStore"]
