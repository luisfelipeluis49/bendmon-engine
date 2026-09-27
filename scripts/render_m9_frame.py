#!/usr/bin/env python3
"""Render a validated Bend M9 scene wire to RGBA8 for the SDL3 host."""
from __future__ import annotations

import argparse
from pathlib import Path
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "platform"))

from content.loader import load_project
from presentation.composer import render_frame
from presentation.wire import parse_cues, parse_scene


def _chunk(kind: bytes, body: bytes) -> bytes:
    return (struct.pack(">I", len(body)) + kind + body
            + struct.pack(">I", zlib.crc32(kind + body) & 0xffffffff))


def png_rgba(width: int, height: int, rgba: bytes) -> bytes:
    """Encode a QA capture without introducing a media library dependency."""
    stride = width * 4
    rows = b"".join(b"\x00" + rgba[y * stride:(y + 1) * stride]
                    for y in range(height))
    return (b"\x89PNG\r\n\x1a\n"
            + _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + _chunk(b"IDAT", zlib.compress(rows)) + _chunk(b"IEND", b""))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("scene_csv", type=Path)
    parser.add_argument("rgba_output", type=Path)
    parser.add_argument("--cues", type=Path)
    parser.add_argument("--png", type=Path)
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--raster-library", type=Path,
                        default=ROOT / "build/m9-raster.so")
    args = parser.parse_args()
    loaded = load_project(args.project)
    scene = parse_scene(args.scene_csv.read_text(encoding="ascii").strip())
    cues = parse_cues(args.cues.read_text(encoding="ascii").strip()) if args.cues else ()
    frame = render_frame(args.project, loaded, scene, cues,
                         args.raster_library, args.width, args.height)
    args.rgba_output.write_bytes(frame)
    if args.png:
        args.png.write_bytes(png_rgba(args.width, args.height, frame))
    print(f"M9 frame {args.width}x{args.height} identity={scene.content_identity} "
          f"map={scene.map_id} cues={len(cues)}")


if __name__ == "__main__":
    main()
