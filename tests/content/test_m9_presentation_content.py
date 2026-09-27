from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct
import sys
import zlib
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))
from content.loader import ContentError, load_project
from tests.content.test_loader import make_kernel, make_project, write_json
import tempfile


def png_chunk(kind: bytes, body: bytes) -> bytes:
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xffffffff)


def rgba_png() -> bytes:
    header = struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", header)
            + png_chunk(b"IDAT", zlib.compress(b"\0\x11\x22\x33\xff"))
            + png_chunk(b"IEND", b""))


def pcm_wav() -> bytes:
    samples = b"\0\0" * 220
    fmt = struct.pack("<HHIIHH", 1, 1, 22050, 44100, 2, 16)
    body = b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(samples)) + samples
    return b"RIFF" + struct.pack("<I", len(body) + 4) + b"WAVE" + body


class M9PresentationContentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.root = make_project(root / "project")
        self.kernel = make_kernel(root)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def add_asset(self, aid: str, name: str, media: str, body: bytes) -> None:
        path = self.root / "assets" / name
        path.write_bytes(body)
        manifest_path = self.root / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["assets"].append({"id": aid, "path": f"assets/{name}",
                                   "mediaType": media, "bytes": len(body),
                                   "sha256": hashlib.sha256(body).hexdigest()})
        write_json(manifest_path, manifest)

    def test_png_wav_and_camera_profile_are_validated_and_hashed(self) -> None:
        self.add_asset("demo:transparent", "sprite.png", "image/png", rgba_png())
        self.add_asset("demo:cue", "cue.wav", "audio/wav", pcm_wav())
        manifest_path = self.root / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["cameraProfiles"] = [{"id": "demo:perspective", "fovDegrees": 60,
                                       "nearQ10": 10, "farQ10": 512000}]
        manifest["audioBindings"] = [{"signalKind": 4, "asset": "demo:cue"}]
        write_json(manifest_path, manifest)
        map_path = self.root / "data/map.json"
        map_doc = json.loads(map_path.read_text())
        map_doc["presentation"] = {"cameraProfile": "demo:perspective",
                                    "background": "demo:transparent"}
        write_json(map_path, map_doc)
        loaded = load_project(self.root, self.kernel)
        self.assertEqual(loaded.camera_profiles[0].fov_degrees, 60)
        self.assertEqual(loaded.audio_bindings[0].signal_kind, 4)
        self.assertEqual(loaded.maps[0].presentation.background, "demo:transparent")
        canonical = json.loads(loaded.canonical_json)
        self.assertEqual(canonical["cameraProfiles"][0]["farQ10"], 512000)
        self.assertEqual(canonical["audioBindings"][0]["asset"], "demo:cue")
        self.assertEqual(canonical["maps"][0]["presentation"]["cameraProfile"], "demo:perspective")
        self.assertEqual(hashlib.sha256(loaded.canonical_json).hexdigest(), loaded.content_hash)

    def test_png_crc_rejects_hostile_media(self) -> None:
        broken = bytearray(rgba_png())
        broken[-5] ^= 1
        self.add_asset("demo:broken", "bad.png", "image/png", bytes(broken))
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "png")

    def test_wav_duration_limit_rejects_hostile_media(self) -> None:
        samples = b"\0\0" * 220501
        fmt = struct.pack("<HHIIHH", 1, 1, 22050, 44100, 2, 16)
        body = b"fmt " + struct.pack("<I", 16) + fmt + b"data" + struct.pack("<I", len(samples)) + samples
        too_long = b"RIFF" + struct.pack("<I", len(body) + 4) + b"WAVE" + body
        self.add_asset("demo:long", "long.wav", "audio/wav", too_long)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "wav")

    def test_camera_reference_and_bounds_reject(self) -> None:
        manifest_path = self.root / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["cameraProfiles"] = [{"id": "demo:cam", "fovDegrees": 91,
                                       "nearQ10": 1, "farQ10": 10}]
        write_json(manifest_path, manifest)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/cameraProfiles/0/fovDegrees")

    def test_audio_binding_requires_wav_asset_and_unique_signal(self) -> None:
        manifest_path = self.root / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["audioBindings"] = [{"signalKind": 1, "asset": "demo:pixel"}]
        write_json(manifest_path, manifest)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/audioBindings/0/asset")


if __name__ == "__main__":
    unittest.main()
