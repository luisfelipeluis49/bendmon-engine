#!/usr/bin/env python3
"""Generate the canonical cumulative XP thresholds for levels 1 through 200."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

LEVEL_MIN = 1
LEVEL_MAX = 200
U32_MAX = 2**32 - 1
OUTPUT = Path(__file__).resolve().parent.parent / "rules" / "generated" / "xp_thresholds.json"


def xp_for_level(level: int) -> int:
    """Return the cumulative XP threshold for one legal level."""
    if isinstance(level, bool) or not isinstance(level, int):
        raise TypeError("level must be an integer")
    if not LEVEL_MIN <= level <= LEVEL_MAX:
        raise ValueError(f"level must be in {LEVEL_MIN}..{LEVEL_MAX}")
    n = level - 1
    return 25 * n**3 + 75 * n


def table_document() -> dict[str, object]:
    thresholds = [xp_for_level(level) for level in range(LEVEL_MIN, LEVEL_MAX + 1)]
    if thresholds[-1] > U32_MAX:
        raise ArithmeticError("level-200 threshold does not fit in U32")
    return {
        "schema": "xp-thresholds-1",
        "levelMin": LEVEL_MIN,
        "levelMax": LEVEL_MAX,
        "formula": "25 * (level - 1)^3 + 75 * (level - 1)",
        "thresholds": thresholds,
        "level200Cap": thresholds[-1],
    }


def render(document: dict[str, object]) -> str:
    return json.dumps(document, indent=2, ensure_ascii=True) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true", help="fail if output is not canonical")
    args = parser.parse_args()

    rendered = render(table_document())
    if args.check:
        try:
            current = args.output.read_text(encoding="utf-8")
        except FileNotFoundError:
            return 1
        return int(current != rendered)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
