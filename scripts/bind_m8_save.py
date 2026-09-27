"""Bind a canonical M8 save to exact loaded content as closed Bend data."""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "platform"))

from content.loader import load_project
from content.m8_binding import bind_m8_content
from content.m8_bend_source import render_m8_catalog
from persistence.m8_world_bridge import decode_m8_world_save
from persistence.save_identity import SaveIdentity
from persistence.world_state import decode_world_state


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("save", type=Path)
    parser.add_argument("output", type=Path,
                        help="generated Bend module directly under build/")
    arguments = parser.parse_args()
    output = arguments.output.resolve()
    if output.parent != (ROOT / "build").resolve():
        parser.error("M8 save binding output must be directly under build/")
    loaded = load_project(arguments.project)
    encoded = arguments.save.read_bytes()
    expression = decode_m8_world_save(encoded, loaded)
    snapshot = decode_world_state(encoded, SaveIdentity(1, "m8-1",
                                                       loaded.content_hash))
    binding = bind_m8_content(loaded, expected_ruleset_version="m8-1",
                              expected_content_digest=loaded.content_hash)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        "import ../engine/world/save_boundary.bend as Save\n"
        "import ../engine/battle/rng.bend as Rng\n"
        + render_m8_catalog(binding, restore_map_id=snapshot.map_id)
        + "\n"
        "def snapshot() -> Save.Snapshot:\n"
        f"  {expression}\n"
    )


if __name__ == "__main__":
    main()
