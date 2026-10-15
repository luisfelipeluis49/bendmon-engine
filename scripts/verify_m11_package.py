#!/usr/bin/env python3
"""Verify every M11 package byte and its bundled Content-0 project."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import stat
import sys

SCHEMA = "m11-package-1"
sys.dont_write_bytecode = True
MAX_MANIFEST_BYTES = 1024 * 1024
MAX_PACKAGE_FILES = 2048
MAX_PACKAGE_BYTES = 256 * 1024 * 1024


def _pairs(items: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in items:
        if key in result:
            raise ValueError(f"duplicate package manifest key: {key}")
        result[key] = value
    return result


def _digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            sha.update(block)
    return sha.hexdigest()


def verify(package: Path) -> dict[str, object]:
    package = package.expanduser().absolute()
    if package.is_symlink() or not package.is_dir():
        raise ValueError("package root must be a real directory")
    manifest_path = package / "package.json"
    raw = manifest_path.read_bytes()
    if len(raw) > MAX_MANIFEST_BYTES:
        raise ValueError("package manifest exceeds 1 MiB")
    metadata = json.loads(raw.decode("utf-8", "strict"), object_pairs_hook=_pairs)
    if (not isinstance(metadata, dict) or set(metadata) != {
            "schema", "target", "pythonMinVersion", "contentHash", "files"}
            or metadata["schema"] != SCHEMA or metadata["target"] != "linux-x86_64"
            or metadata["pythonMinVersion"] != "3.12"):
        raise ValueError("package manifest has an unsupported schema or target")
    if sys.version_info < (3, 12):
        raise ValueError("M11 package requires Python 3.12 or newer")
    if platform.system() != "Linux" or platform.machine() not in {"x86_64", "amd64"}:
        raise ValueError("package target is Linux x86-64")
    rows = metadata["files"]
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_PACKAGE_FILES:
        raise ValueError("package file manifest count is outside 1..2048")
    expected: dict[str, dict[str, object]] = {}
    total = 0
    for row in rows:
        if not isinstance(row, dict) or set(row) != {"path", "size", "sha256", "mode"}:
            raise ValueError("package file entry has an invalid shape")
        relative, size, digest, mode = row["path"], row["size"], row["sha256"], row["mode"]
        if (not isinstance(relative, str) or relative != PurePosixPath(relative).as_posix()
                or PurePosixPath(relative).is_absolute()
                or any(part in {"", ".", ".."} for part in PurePosixPath(relative).parts)
                or relative in expected or relative == "package.json"):
            raise ValueError("package manifest contains a duplicate or unsafe path")
        if (type(size) is not int or not 0 <= size <= MAX_PACKAGE_BYTES
                or not isinstance(digest, str) or len(digest) != 64
                or any(char not in "0123456789abcdef" for char in digest)
                or type(mode) is not int or mode not in {0o644, 0o755}):
            raise ValueError(f"package file metadata is invalid: {relative}")
        total += size
        expected[relative] = row
    if total > MAX_PACKAGE_BYTES:
        raise ValueError("package exceeds 256 MiB")
    actual: set[str] = set()
    for path in package.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"package contains a symbolic link: {path.relative_to(package)}")
        if path.is_file() and path != manifest_path:
            actual.add(path.relative_to(package).as_posix())
    if actual != set(expected):
        missing, extra = sorted(set(expected) - actual), sorted(actual - set(expected))
        raise ValueError(f"package file set differs (missing={missing[:1]}, extra={extra[:1]})")
    for relative, row in expected.items():
        path = package / relative
        if not path.is_file() or path.stat().st_size != row["size"]:
            raise ValueError(f"package size mismatch: {relative}")
        if stat.S_IMODE(path.stat().st_mode) != row["mode"] or _digest(path) != row["sha256"]:
            raise ValueError(f"package digest or mode mismatch: {relative}")
    required = {"build/content-kernel", "build/m10_dynamic_runtime",
                "scripts/run_m10_maker.py", "platform/content/loader.py",
                "platform/maker/service.py", "examples/m10-starter/project.json",
                "examples/m10-starter/manifest.json", "start-maker"}
    if not required.issubset(expected):
        raise ValueError("package is missing required launcher, runtime, host, or starter files")
    for relative in ("build/content-kernel", "build/m10_dynamic_runtime", "start-maker"):
        path = package / relative
        if not os.access(path, os.X_OK):
            raise ValueError(f"package executable bit is missing: {relative}")
    sys.path.insert(0, str(package / "platform"))
    from content.loader import load_project
    loaded = load_project(package / "examples/m10-starter",
                          kernel_path=package / "build/content-kernel")
    if loaded.content_hash != metadata["contentHash"]:
        raise ValueError("starter content digest differs from package metadata")
    return {"ok": True, "files": len(expected), "bytes": total,
            "contentHash": loaded.content_hash, "target": metadata["target"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = verify(args.package)
    except (OSError, ValueError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"M11 package verification failed: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
