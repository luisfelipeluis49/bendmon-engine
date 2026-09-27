"""Presentation media uses the validated asset identity and decodes PNG rows."""
from __future__ import annotations

import hashlib
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import wave
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "platform"))
from content.loader import ContentError
from content.models import Asset, AssetId
from presentation.media import load_audio, load_image


def chunk(kind: bytes, body: bytes) -> bytes:
    return (struct.pack(">I", len(body)) + kind + body
            + struct.pack(">I", zlib.crc32(kind + body) & 0xffffffff))


def png_rows() -> bytes:
    first = bytes([10, 20, 30, 255, 40, 50, 60, 128])
    second = bytes([70, 80, 90, 255, 100, 110, 120, 64])
    # Sub then Up exercise nontrivial PNG reconstruction without external libs.
    sub = bytes((value - (first[i - 4] if i >= 4 else 0)) & 255
                for i, value in enumerate(first))
    up = bytes((value - first[i]) & 255 for i, value in enumerate(second))
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 2, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\x01" + sub + b"\x02" + up))
            + chunk(b"IEND", b""))


class MediaTest(unittest.TestCase):
    def test_png_rgba_and_verified_identity(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            raw = png_rows()
            (root / "sprite.png").write_bytes(raw)
            asset = Asset(AssetId("test:sprite"), "sprite.png", "image/png",
                          len(raw), hashlib.sha256(raw).hexdigest())
            image = load_image(root, asset)
            self.assertEqual((image.width, image.height), (2, 2))
            self.assertEqual(image.rgba, bytes([10, 20, 30, 255, 40, 50, 60, 128,
                                                70, 80, 90, 255, 100, 110, 120, 64]))
            (root / "sprite.png").write_bytes(raw[:-1] + b"x")
            with self.assertRaises(ContentError):
                load_image(root, asset)

    def test_pcm_audio_and_ppm(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            ppm = b"P6\n1 1\n255\n\x01\x02\x03"
            (root / "pixel.ppm").write_bytes(ppm)
            asset = Asset(AssetId("test:pixel"), "pixel.ppm",
                          "image/x-portable-pixmap", len(ppm), hashlib.sha256(ppm).hexdigest())
            self.assertEqual(load_image(root, asset).rgba, b"\x01\x02\x03\xff")
            with wave.open(str(root / "cue.wav"), "wb") as output:
                output.setnchannels(1)
                output.setsampwidth(2)
                output.setframerate(22050)
                output.writeframes(b"\x00\x00\x01\x00")
            wav = (root / "cue.wav").read_bytes()
            cue = Asset(AssetId("test:cue"), "cue.wav", "audio/wav",
                        len(wav), hashlib.sha256(wav).hexdigest())
            self.assertEqual(load_audio(root, cue).pcm_s16le, b"\x00\x00\x01\x00")


if __name__ == "__main__":
    unittest.main()
