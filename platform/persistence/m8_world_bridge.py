"""Translate an exact-identity M8 world save into closed Bend data."""

from __future__ import annotations

from typing import Final

from content.m7_binding import M7BindingError
from content.m8_binding import M8BindingError, M8ContentBinding, bind_m8_content
from content.models import LoadedProject

from .save_identity import SaveIdentity, SaveIdentityError
from .world_state import WORLD_SAVE_SCHEMA_VERSION, WorldSnapshot, WorldStateError, decode_world_state

_RULESET: Final = "m8-1"


class M8WorldBridgeError(ValueError):
    """The save cannot be safely projected into the loaded M8 world."""


def _nat(value: int, field: str) -> str:
    if type(value) is not int or value < 0:
        raise M8WorldBridgeError(f"{field} must be a nonnegative integer")
    return f"{value}n"


def _uint(value: int, field: str) -> str:
    if type(value) is not int or not 0 <= value <= 0xFFFFFFFF:
        raise M8WorldBridgeError(f"{field} must be a U32")
    return str(value)


def _coord(value: int, field: str) -> str:
    if type(value) is not int or not -524_288 <= value <= 524_288:
        raise M8WorldBridgeError(f"{field} is outside the world coordinate range")
    sign = "True{}" if value < 0 else "False{}"
    return f"Geometry.Coord{{{sign}, {_uint(abs(value), field)}}}"


def _bound_map(binding: M8ContentBinding, map_id: int):
    for row in binding.maps:
        if row.id == map_id:
            return row
    raise M8WorldBridgeError(f"save map ID {map_id} is not bound in loaded content")


def render_world_snapshot(snapshot: WorldSnapshot, binding: M8ContentBinding) -> str:
    """Render a validated snapshot as one numeric ``Save.Snapshot`` expression."""
    if type(snapshot) is not WorldSnapshot:
        raise M8WorldBridgeError("world bridge requires a decoded WorldSnapshot")
    if type(binding) is not M8ContentBinding or binding.ruleset_version != _RULESET:
        raise M8WorldBridgeError("world bridge requires an exact M8 content binding")
    bound_map = _bound_map(binding, snapshot.map_id)
    if snapshot.region_id is not None and not any(
        region.id == snapshot.region_id for region in bound_map.regions
    ):
        raise M8WorldBridgeError(
            f"save region ID {snapshot.region_id} is not bound on map {snapshot.map_id}"
        )

    point = "Geometry.Point{" + ", ".join((
        _coord(snapshot.x, "position x"), _coord(snapshot.y, "position y"),
        _coord(snapshot.z, "position z"),
    )) + "}"
    region = "None{}" if snapshot.region_id is None else f"Some{{{_nat(snapshot.region_id, 'region ID')}}}"
    rng = "Rng.RngState{" + ", ".join(
        _uint(word, "RNG word") for word in snapshot.rng_state
    ) + "}"
    values = "[" + ", ".join(
        f"Events.Value{{{_nat(key, 'persistent value key')}, "
        f"{_nat(value, 'persistent value value')}}}"
        for key, value in snapshot.persistent_values
    ) + "]"
    entities = "[" + ", ".join(
        _nat(entity, "persistent entity") for entity in snapshot.persistent_entities
    ) + "]"
    fields = (
        _nat(binding.content_identity, "content identity"),
        _nat(snapshot.map_id, "map ID"), point, region,
        _nat(snapshot.weighted_distance, "weighted distance"),
        _nat(snapshot.encounter_threshold, "encounter threshold"),
        _nat(snapshot.safe_distance, "safe distance"), rng, values, entities,
    )
    return "Save.Snapshot{" + ", ".join(fields) + "}"


def decode_m8_world_save(encoded: bytes, loaded: LoadedProject) -> str:
    """Decode exact full-digest save bytes and return closed numeric Bend data.

    The authored project is validated and bound before any save IDs are
    projected. The returned expression contains no authored project strings.
    """
    try:
        if type(loaded) is not LoadedProject:
            raise M8WorldBridgeError("M8 save bridge requires a LoadedProject")
        identity = SaveIdentity(WORLD_SAVE_SCHEMA_VERSION, _RULESET, loaded.content_hash)
        snapshot = decode_world_state(encoded, identity)
        binding = bind_m8_content(
            loaded, expected_ruleset_version=_RULESET,
            expected_content_digest=loaded.content_hash,
        )
        return render_world_snapshot(snapshot, binding)
    except (SaveIdentityError, WorldStateError, M7BindingError, M8BindingError) as exc:
        raise M8WorldBridgeError(str(exc)) from exc


__all__ = ["M8WorldBridgeError", "decode_m8_world_save", "render_world_snapshot"]
