"""Closed numeric M10 playtest boot envelope from an exact M8 binding.

The complete SHA-256 digest is compared by the trusted host before this
compact identity token crosses into Bend. The token alone is not a save ID.
"""
from __future__ import annotations

from dataclasses import dataclass

from .m8_binding import BoundPoint, M8ContentBinding, SignedCoord
from .world_limits import WORLD_COORD_LIMIT

MAGIC = 11
VERSION = 2
U32_MAX = 0xFFFFFFFF


class M10BootWireError(ValueError):
    """The creator's boot request violates the closed numeric contract."""


@dataclass(frozen=True, slots=True)
class M10BootWire:
    tokens: tuple[int, ...]
    text: str


def _word(value: object, name: str, ceiling: int = U32_MAX) -> int:
    if type(value) is not int or not 0 <= value <= ceiling:
        raise M10BootWireError(f"{name} must be an integer in 0..{ceiling}")
    return value


def _coordinate(value: SignedCoord, name: str) -> tuple[int, int]:
    if type(value) is not SignedCoord or type(value.negative) is not bool:
        raise M10BootWireError(f"{name} must be a signed Q10 coordinate")
    magnitude = _word(value.magnitude, name, WORLD_COORD_LIMIT)
    if value.negative and magnitude == 0:
        raise M10BootWireError(f"{name} cannot contain negative zero")
    return (1 if value.negative else 0, magnitude)


def encode_m10_boot(binding: M8ContentBinding, *, rng_state: tuple[int, int, int, int],
                    wait_ticks: int) -> M10BootWire:
    """Encode the authored entry point and explicit RNG/pacing for Bend boot."""
    if type(binding) is not M8ContentBinding or binding.ruleset_version != "m8-1":
        raise M10BootWireError("boot requires an exact M8ContentBinding")
    if type(binding.entry_point) is not BoundPoint:
        raise M10BootWireError("project requires an authored entryPoint")
    if type(rng_state) is not tuple or len(rng_state) != 4:
        raise M10BootWireError("RNG state must contain four U32 words")
    words = tuple(_word(value, f"RNG word {index}")
                  for index, value in enumerate(rng_state))
    if not any(words):
        raise M10BootWireError("RNG state cannot be all zero")
    if type(wait_ticks) is not int or wait_ticks not in (30, 60, 120):
        raise M10BootWireError("Wait pacing must be 30, 60, or 120 ticks")
    starter_id = 0 if binding.starter_species_id is None else _word(
        binding.starter_species_id, "starter species ID")
    starter_level = 0 if binding.starter_level is None else _word(
        binding.starter_level, "starter level", 100)
    if (starter_id == 0) != (starter_level == 0) or (starter_id and starter_level < 1):
        raise M10BootWireError("starter species and level must both be present or absent")
    point = binding.entry_point
    tokens = (MAGIC, VERSION, _word(binding.content_identity, "content identity"),
              _word(binding.entry_map_id, "entry map ID"),
              *_coordinate(point.x, "entryPoint.x"),
              *_coordinate(point.y, "entryPoint.y"),
              *_coordinate(point.z, "entryPoint.z"),
              *words, wait_ticks, starter_id, starter_level)
    if binding.entry_map_id == 0:
        raise M10BootWireError("entry map ID must be positive")
    return M10BootWire(tokens, " ".join(map(str, tokens)))
