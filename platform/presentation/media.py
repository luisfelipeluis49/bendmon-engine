"""Decode already validated Content-0 media for presentation-only host use."""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
import struct
import zlib

from content.loader import ContentError, Diagnostic, _Root, _parse_png, _parse_ppm, _parse_wav
from content.models import Asset


@dataclass(frozen=True, slots=True)
class ImagePixels:
    width: int
    height: int
    rgba: bytes


@dataclass(frozen=True, slots=True)
class AudioSamples:
    channels: int
    sample_rate: int
    pcm_s16le: bytes


def _verified_bytes(project_root: Path, asset: Asset) -> bytes:
    root = _Root(project_root)
    try:
        raw = root.read(asset.path, asset.bytes)
    finally:
        root.close()
    if len(raw) != asset.bytes or hashlib.sha256(raw).hexdigest() != asset.sha256:
        raise ContentError([Diagnostic("asset-changed", asset.path, "", str(asset.id),
                                       "asset bytes changed since project validation")])
    return raw


def _ppm(raw: bytes) -> ImagePixels:
    match = re.fullmatch(rb"P6\n([1-9][0-9]{0,2}) ([1-9][0-9]{0,2})\n255\n([\s\S]*)", raw)
    assert match is not None
    width, height, rgb = int(match[1]), int(match[2]), match[3]
    rgba = bytearray(width * height * 4)
    for pixel in range(width * height):
        rgba[4 * pixel:4 * pixel + 4] = rgb[3 * pixel:3 * pixel + 3] + b"\xff"
    return ImagePixels(width, height, bytes(rgba))


def _png_chunks(raw: bytes) -> tuple[int, int, bytes]:
    position, compressed, width, height = 8, bytearray(), 0, 0
    while position < len(raw):
        size = int.from_bytes(raw[position:position + 4], "big")
        kind = raw[position + 4:position + 8]
        body = raw[position + 8:position + 8 + size]
        if kind == b"IHDR":
            width, height = struct.unpack_from(">II", body)
        elif kind == b"IDAT":
            compressed.extend(body)
        elif kind == b"IEND":
            break
        position += size + 12
    return width, height, zlib.decompress(bytes(compressed))


def _paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    distances = (abs(estimate - left), abs(estimate - above),
                 abs(estimate - upper_left))
    return (left, above, upper_left)[distances.index(min(distances))]


def _unfilter_row(filter_kind: int, encoded: bytes, previous: bytes) -> bytes:
    current = bytearray(len(encoded))
    for index, value in enumerate(encoded):
        left = current[index - 4] if index >= 4 else 0
        above = previous[index]
        upper_left = previous[index - 4] if index >= 4 else 0
        predictor = (0, left, above, (left + above) // 2,
                     _paeth(left, above, upper_left))[filter_kind]
        current[index] = (value + predictor) & 255
    return bytes(current)


def _png(raw: bytes) -> ImagePixels:
    width, height, filtered = _png_chunks(raw)
    stride = width * 4
    rows = bytearray(width * height * 4)
    previous = bytes(stride)
    for row in range(height):
        start = row * (stride + 1)
        decoded = _unfilter_row(filtered[start],
                                filtered[start + 1:start + 1 + stride], previous)
        rows[row * stride:(row + 1) * stride] = decoded
        previous = decoded
    return ImagePixels(width, height, bytes(rows))


def load_image(project_root: Path, asset: Asset) -> ImagePixels:
    """Return immutable RGBA8 pixels for a previously validated image asset."""
    raw = _verified_bytes(project_root, asset)
    if asset.media_type == "image/x-portable-pixmap":
        _parse_ppm(raw, asset.path)
        return _ppm(raw)
    if asset.media_type == "image/png":
        _parse_png(raw, asset.path)
        return _png(raw)
    raise ValueError(f"asset {asset.id} must be a validated image")


def load_audio(project_root: Path, asset: Asset) -> AudioSamples:
    """Return bounded signed PCM samples for a previously validated WAV asset."""
    if asset.media_type != "audio/wav":
        raise ValueError(f"asset {asset.id} must be a validated WAV")
    raw = _verified_bytes(project_root, asset)
    _parse_wav(raw, asset.path)
    position, channels, rate, pcm = 12, 0, 0, b""
    while position < len(raw):
        kind = raw[position:position + 4]
        size = int.from_bytes(raw[position + 4:position + 8], "little")
        body = raw[position + 8:position + 8 + size]
        if kind == b"fmt ":
            channels = int.from_bytes(body[2:4], "little")
            rate = int.from_bytes(body[4:8], "little")
        elif kind == b"data":
            pcm = body
        position += 8 + size + (size & 1)
    return AudioSamples(channels, rate, pcm)
