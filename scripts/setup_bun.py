#!/usr/bin/env python3
"""Install the checksum-pinned Bun packager for the M10 Bend JS runtime."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent
LOCK = json.loads((ROOT / "toolchain.bun.lock.json").read_text())


def digest(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def checked_path(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if not path.is_relative_to(ROOT) or not relative.startswith(".toolchain/"):
        raise ValueError(f"Bun lock path escapes .toolchain: {relative!r}")
    return path


def main() -> Path:
    archive = checked_path(LOCK["archive"])
    binary = checked_path(LOCK["binary"])
    binary.parent.mkdir(parents=True, exist_ok=True)
    if binary.is_file() and digest(binary.read_bytes()) == LOCK["binarySha256"]:
        binary.chmod(0o755)
        return binary
    if not archive.is_file():
        request = urllib.request.Request(LOCK["url"],
                                         headers={"User-Agent": "bend-m10-build"})
        with urllib.request.urlopen(request, timeout=120) as response:
            content = response.read(40 * 1024 * 1024 + 1)
        if len(content) > 40 * 1024 * 1024:
            raise ValueError("Bun archive exceeds 40 MiB")
        if digest(content) != LOCK["archiveSha256"]:
            raise ValueError("Bun archive checksum mismatch")
        archive.write_bytes(content)
    content = archive.read_bytes()
    if digest(content) != LOCK["archiveSha256"]:
        raise ValueError("cached Bun archive checksum mismatch")
    with zipfile.ZipFile(archive) as bundle:
        if bundle.namelist() != ["bun-linux-x64/", "bun-linux-x64/bun"]:
            raise ValueError("Bun archive has unexpected entries")
        executable = bundle.read("bun-linux-x64/bun")
    if digest(executable) != LOCK["binarySha256"]:
        raise ValueError("Bun executable checksum mismatch")
    with tempfile.NamedTemporaryFile(dir=binary.parent, delete=False) as temporary:
        temporary.write(executable)
        temporary_path = Path(temporary.name)
    try:
        temporary_path.chmod(0o755)
        os.replace(temporary_path, binary)
    finally:
        temporary_path.unlink(missing_ok=True)
    return binary


if __name__ == "__main__":
    print(main())
