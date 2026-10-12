#!/usr/bin/env python3
"""Build the pinned M10 runtime once for local maker development/package setup."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import tempfile

from setup_bun import main as setup_bun

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=ROOT / "build" / "m10_dynamic_runtime")
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    bun = setup_bun()
    with tempfile.TemporaryDirectory(prefix="m10-build-", dir=output.parent) as temp:
        stage = Path(temp)
        javascript = stage / "runtime.js"
        executable = stage / "runtime"
        subprocess.run([str(ROOT / "scripts" / "bend"),
                        str(ROOT / "platform" / "maker" / "dynamic_runtime.bend"),
                        "-o", str(javascript)], cwd=ROOT, check=True)
        subprocess.run([str(bun), "build", "--compile", str(javascript),
                        "--outfile", str(executable)], cwd=ROOT, check=True)
        if not executable.is_file() or not os.access(executable, os.X_OK):
            raise RuntimeError("Bun did not produce an executable M10 runtime")
        os.replace(executable, output)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
