#!/usr/bin/env python3
"""Assemble a verified, offline Linux x86-64 M11 maker package."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import shutil
import stat
import tempfile
import sys

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = "m11-package-1"
sys.dont_write_bytecode = True


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _safe_relative(path: str) -> bool:
    parsed = PurePosixPath(path)
    return (path == parsed.as_posix() and not parsed.is_absolute()
            and bool(parsed.parts) and all(part not in {"", ".", ".."} for part in parsed.parts))


def _sources() -> list[tuple[str, Path]]:
    selected: list[tuple[str, Path]] = []
    for prefix in ("platform/content", "platform/maker", "platform/persistence",
                   "platform/presentation"):
        for source in sorted((ROOT / prefix).rglob("*")):
            if source.is_symlink():
                raise ValueError(f"package source may not be a symlink: {source.relative_to(ROOT)}")
            if source.is_file() and (source.suffix == ".py" or
                                     (prefix == "platform/maker" and
                                      source.parent.name == "browser" and
                                      source.suffix in {".html", ".mjs", ".css"}) or
                                     (prefix == "platform/presentation" and
                                      source.parent.name == "browser" and
                                      source.suffix in {".html", ".mjs", ".css"})):
                selected.append((source.relative_to(ROOT).as_posix(), source))
    selected.extend((path, ROOT / path) for path in (
        "scripts/run_m10_maker.py", "scripts/verify_m11_package.py",
        "build/content-kernel",
        "build/m10_dynamic_runtime"))
    for source in sorted((ROOT / "examples/m10-starter").rglob("*")):
        if source.is_symlink():
            raise ValueError(f"starter content may not contain symlinks: {source.relative_to(ROOT)}")
        if source.is_file():
            selected.append((source.relative_to(ROOT).as_posix(), source))
    if len({name for name, _ in selected}) != len(selected):
        raise ValueError("package source paths are duplicated")
    for name, source in selected:
        if not _safe_relative(name) or not source.is_file() or source.is_symlink():
            raise ValueError(f"required package input is missing or unsafe: {name}")
    for executable in (ROOT / "build/content-kernel", ROOT / "build/m10_dynamic_runtime"):
        if not os.access(executable, os.X_OK):
            raise ValueError(f"required package input is not executable: {executable.relative_to(ROOT)}")
    return selected


def package(output: Path) -> Path:
    if platform.system() != "Linux" or platform.machine() not in {"x86_64", "amd64"}:
        raise RuntimeError("M11 package target is Linux x86-64")
    sources = _sources()
    output = output.expanduser().absolute()
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".m11-package-", dir=output.parent))
    try:
        for relative, source in sources:
            destination = stage / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            destination.chmod(stat.S_IMODE(source.stat().st_mode) & 0o755)
        # Validate the copied starter with the exact package kernel before emitting it.
        sys.path.insert(0, str(stage / "platform"))
        from content.loader import load_project
        loaded = load_project(stage / "examples/m10-starter",
                              kernel_path=stage / "build/content-kernel")
        launcher = """#!/bin/sh
set -eu
export PYTHONDONTWRITEBYTECODE=1
package_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python3 "$package_dir/scripts/verify_m11_package.py" --package "$package_dir"
data_root=${XDG_DATA_HOME:-${HOME:?HOME is required}/.local/share}
exec python3 "$package_dir/scripts/run_m10_maker.py" \\
  --root "$data_root/bend-maker/projects" \\
  --runtime "$package_dir/build/m10_dynamic_runtime" \\
  --template "$package_dir/examples/m10-starter" "$@"
"""
        (stage / "start-maker").write_text(launcher, encoding="utf-8")
        (stage / "start-maker").chmod(0o755)
        entries = []
        for relative, _ in sources:
            path = stage / relative
            entries.append({"path": relative, "size": path.stat().st_size,
                            "sha256": _sha256(path),
                            "mode": stat.S_IMODE(path.stat().st_mode)})
        launcher_path = stage / "start-maker"
        entries.append({"path": "start-maker", "size": launcher_path.stat().st_size,
                        "sha256": _sha256(launcher_path),
                        "mode": stat.S_IMODE(launcher_path.stat().st_mode)})
        metadata = {"schema": SCHEMA, "target": "linux-x86_64",
                    "pythonMinVersion": "3.12",
                    "contentHash": loaded.content_hash, "files": entries}
        (stage / "package.json").write_text(
            json.dumps(metadata, sort_keys=True, separators=(",", ":")) + "\n",
            encoding="utf-8")
        os.replace(stage, output)
    except Exception:
        shutil.rmtree(stage, ignore_errors=True)
        raise
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/m11-package")
    args = parser.parse_args()
    print(package(args.output))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
