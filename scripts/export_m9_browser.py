"""Export a validated Content-0 project and exact M9 wires as a static preview."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "platform"))
from content.loader import load_project  # noqa: E402
from presentation.media import _verified_bytes, load_audio, load_image  # noqa: E402
from presentation.wire import parse_cues, parse_scene  # noqa: E402


def _png(pixels) -> bytes:
    def chunk(kind: bytes, body: bytes) -> bytes:
        payload = kind + body
        return struct.pack(">I", len(body)) + payload + struct.pack(">I", zlib.crc32(payload) & 0xffffffff)
    rows = b"".join(b"\0" + pixels.rgba[y * pixels.width * 4:(y + 1) * pixels.width * 4]
                    for y in range(pixels.height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", pixels.width,
            pixels.height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def export(project: Path, scene_path: Path, cues_path: Path, output: Path) -> None:
    loaded = load_project(project)
    scene_wire = scene_path.read_text(encoding="ascii").strip()
    cues_wire = cues_path.read_text(encoding="ascii").strip()
    scene, cues = parse_scene(scene_wire), parse_cues(cues_wire)
    if scene.content_identity != int(loaded.content_hash[:8], 16):
        raise ValueError("scene content identity differs from validated Content-0 project")
    maps = sorted(loaded.maps, key=lambda row: str(row.id))
    if not 1 <= scene.map_id <= len(maps):
        raise ValueError(f"scene map ID {scene.map_id} is absent from validated project")
    row = maps[scene.map_id - 1]
    npcs = sorted(row.npcs, key=lambda npc: str(npc.id))
    if (row.navigation is None or len(row.navigation.vertices) > 256 or
            len(row.navigation.faces) > 256 or len(npcs) > 256):
        raise ValueError("active map exceeds browser renderer geometry or NPC limits")
    if any(not 1 <= npc.id <= len(npcs) for npc in scene.npcs):
        raise ValueError("scene references an NPC absent from the active Content-0 map")
    profiles = {profile.id: profile for profile in loaded.camera_profiles}
    profile = profiles.get(row.presentation.camera_profile)
    asset_by_id = {str(asset.id): asset for asset in loaded.assets}
    required_ids = ({str(row.presentation.background)} if row.presentation.background else set())
    required_ids.update(str(npc.sprite) for npc in npcs if npc.sprite)
    required_ids.update(str(binding.asset) for binding in loaded.audio_bindings)
    missing = sorted(required_ids - asset_by_id.keys())
    if missing:
        raise ValueError(f"presentation reference {missing[0]} is not a validated asset")
    if len(required_ids) > 256:
        raise ValueError("presentation asset count exceeds browser renderer limit 256")
    for asset_id in required_ids:
        asset = asset_by_id[asset_id]
        if asset_id in {str(row.presentation.background), *(str(npc.sprite) for npc in npcs if npc.sprite)} and asset.media_type not in {"image/png", "image/x-portable-pixmap"}:
            raise ValueError(f"map presentation reference {asset_id} is not a validated image")
        if any(str(binding.asset) == asset_id for binding in loaded.audio_bindings) and asset.media_type != "audio/wav":
            raise ValueError(f"audio reference {asset_id} is not a validated WAV")
    output.mkdir(parents=True, exist_ok=True)
    media = output / "media"
    media.mkdir(exist_ok=True)
    assets: dict[str, dict[str, str]] = {}
    for index, asset in enumerate(sorted((asset_by_id[key] for key in required_ids), key=lambda item: str(item.id))):
        name = f"asset-{index:04d}"
        if asset.media_type in {"image/png", "image/x-portable-pixmap"}:
            target = name + ".png"
            (media / target).write_bytes(_png(load_image(project, asset)))
            assets[str(asset.id)] = {"image": f"media/{target}"}
        elif asset.media_type == "audio/wav":
            # load_audio rechecks digest and the bounded WAV contract before copy.
            load_audio(project, asset)
            target = name + ".wav"
            (media / target).write_bytes(_verified_bytes(project, asset))
            assets[str(asset.id)] = {"audio": f"media/{target}"}
    audio_rows = []
    for binding in loaded.audio_bindings:
        asset_id = str(binding.asset)
        if asset_id not in assets or "audio" not in assets[asset_id]:
            raise ValueError(f"audio binding {binding.signal_kind} does not resolve to validated WAV")
        audio_rows.append({"signalKind": binding.signal_kind, "assetId": asset_id})
    authored = [{"runtimeId": index + 1,
                 **({"spriteAssetId": str(npc.sprite)} if npc.sprite else {})}
                for index, npc in enumerate(npcs)]
    content = {"contentIdentity": scene.content_identity, "assets": assets,
               "audioBindings": audio_rows,
               "maps": [{"runtimeId": scene.map_id,
                         "vertices": ([{"x": v.x, "y": v.y, "z": v.z}
                                      for v in row.navigation.vertices] if row.navigation else []),
                         "faces": ([[f.a, f.b, f.c] for f in row.navigation.faces]
                                   if row.navigation else []),
                         "npcs": authored,
                         "cameraProfile": ({"fovDegrees": profile.fov_degrees,
                                            "nearQ10": profile.near_q10,
                                            "farQ10": profile.far_q10} if profile else
                                           {"fovDegrees": 60, "nearQ10": 16, "farQ10": 524288}),
                         **({"backgroundAssetId": str(row.presentation.background)}
                            if row.presentation.background else {})}]}
    (output / "content.json").write_text(json.dumps(content, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    (output / "scene.csv").write_text(scene_wire + "\n", encoding="ascii")
    (output / "cues.csv").write_text(cues_wire + "\n", encoding="ascii")
    shutil.copyfile(ROOT / "platform/presentation/browser/renderer.mjs", output / "renderer.mjs")
    shutil.copyfile(ROOT / "platform/presentation/browser/index.html", output / "index.html")
    shutil.copyfile(ROOT / "platform/presentation/browser/main.mjs", output / "main.mjs")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path, help="validated Content-0 project directory")
    parser.add_argument("scene_csv", type=Path, help="exact Bend M9 scene wire file")
    parser.add_argument("cues_csv", type=Path, help="exact Bend M9 cue wire file")
    parser.add_argument("output", type=Path, help="static preview bundle directory")
    args = parser.parse_args()
    try:
        export(args.project, args.scene_csv, args.cues_csv, args.output)
    except (ValueError, OSError) as exc:
        parser.error(str(exc))
    print(f"M9 browser preview exported to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
