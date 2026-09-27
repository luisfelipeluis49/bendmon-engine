"""Compile a strictly loaded M8 pack into numeric Bend constructor data."""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "platform"))

from content.loader import load_project
from content.m8_binding import bind_m8_content
from content.m8_bend_source import render_m8_catalog


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("output", type=Path,
                        help="generated Bend module under this repository's build/ directory")
    arguments = parser.parse_args()
    output = arguments.output.resolve()
    if output.parent != (ROOT / "build").resolve():
        parser.error("M8 Bend catalog output must be a file directly under build/")
    loaded = load_project(arguments.project)
    binding = bind_m8_content(loaded, expected_ruleset_version="m8-1",
                              expected_content_digest=loaded.content_hash)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render_m8_catalog(binding))


if __name__ == "__main__":
    main()
