#!/usr/bin/env python3
"""Install the pinned Bend release inside this workspace."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import tarfile
import tempfile
import urllib.request


ROOT = Path(__file__).resolve().parent.parent
LOCK_PATH = ROOT / "toolchain.lock.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def workspace_path(value: str) -> Path:
    path = (ROOT / value).resolve()
    try:
        path.relative_to(ROOT)
    except ValueError as error:
        raise SystemExit(f"locked path escapes workspace: {value}") from error
    return path


def fetch(url: str, destination: Path, expected: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        dir=destination.parent, prefix=destination.name + ".", delete=False
    ) as temporary:
        temporary_path = Path(temporary.name)
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "bend-m0-bootstrap"})
        with urllib.request.urlopen(request) as response, temporary_path.open("wb") as out:
            shutil.copyfileobj(response, out)
        actual = sha256(temporary_path)
        if actual != expected:
            raise SystemExit(
                f"download checksum mismatch: expected {expected}, got {actual}"
            )
        os.replace(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def validate_members(archive: tarfile.TarFile) -> None:
    for member in archive.getmembers():
        name = PurePosixPath(member.name)
        if name.is_absolute() or ".." in name.parts:
            raise SystemExit(f"unsafe path in toolchain archive: {member.name}")
        if not name.parts or name.parts[0] != "bend":
            raise SystemExit(f"unexpected archive root: {member.name}")
        if not (member.isdir() or member.isfile()):
            raise SystemExit(f"unsafe entry type in toolchain archive: {member.name}")


def main() -> None:
    lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    release = lock["release"]
    archive_path = workspace_path(release["archive"])
    binary_path = workspace_path(release["binary"])
    archive_hash = release["sha256"]
    binary_hash = release["binarySha256"]
    version = release["version"]
    platform = release["platform"]
    url = (
        "https://github.com/bendlang/bend/releases/download/"
        f"v{version}/bend-{version}-{platform}.tar.gz"
    )

    if archive_path.exists() and sha256(archive_path) != archive_hash:
        raise SystemExit(f"cached archive checksum mismatch: {archive_path}")
    if not archive_path.exists():
        print(f"downloading {url}")
        fetch(url, archive_path, archive_hash)

    if binary_path.is_file() and os.access(binary_path, os.X_OK):
        if sha256(binary_path) == binary_hash:
            print(f"Bend {version} already installed at {binary_path}")
            return

    release_root = binary_path.parent.parent.parent
    release_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="bend-extract.", dir=release_root) as temp:
        temp_path = Path(temp)
        with tarfile.open(archive_path, mode="r:gz") as archive:
            validate_members(archive)
            archive.extractall(temp_path, filter="data")
        extracted = temp_path / "bend"
        extracted_binary = extracted / "bin" / "bend"
        if not extracted_binary.is_file() or sha256(extracted_binary) != binary_hash:
            raise SystemExit("extracted Bend executable does not match the lock")
        destination = release_root / "bend"
        if destination.exists():
            shutil.rmtree(destination)
        os.replace(extracted, destination)

    print(f"installed Bend {version} at {binary_path}")


if __name__ == "__main__":
    main()
