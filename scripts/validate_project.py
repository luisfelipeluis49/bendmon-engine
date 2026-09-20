#!/usr/bin/env python3
"""Validate a Content-0 project and print one JSON result."""
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
PLATFORM = ROOT / "platform"
if str(PLATFORM) not in sys.path:
    sys.path.insert(0, str(PLATFORM))

from content.loader import ContentError, InfrastructureError, load_project


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(json.dumps({"ok": False, "error": "usage: validate_project.py PROJECT_DIR"}, separators=(",", ":")))
        return 1
    try:
        loaded = load_project(argv[1])
    except ContentError as exc:
        print(json.dumps({"ok": False, "diagnostics": [d.as_dict() for d in exc.diagnostics]}, ensure_ascii=False, separators=(",", ":")))
        return 2
    except (InfrastructureError, OSError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False, separators=(",", ":")))
        return 1
    print(json.dumps({"ok": True, "projectId": str(loaded.project.id), "contentHash": loaded.content_hash,
                      "counts": {"assets": len(loaded.assets), "species": len(loaded.species),
                                 "encounters": len(loaded.encounters), "maps": len(loaded.maps)}}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
