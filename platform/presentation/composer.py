"""Trusted host composition from a Bend projection and validated content."""
from __future__ import annotations

import ctypes as C
from pathlib import Path

from content.models import LoadedProject, MapRecord
from presentation.media import ImagePixels, load_image
from presentation.wire import CueView, SceneView


class Vec3(C.Structure):
    _fields_ = [("x", C.c_float), ("y", C.c_float), ("z", C.c_float)]


class Terrain(C.Structure):
    _fields_ = [("a", Vec3), ("b", Vec3), ("c", Vec3), ("rgba", C.c_uint32)]


class Image(C.Structure):
    _fields_ = [("rgba", C.POINTER(C.c_uint8)), ("width", C.c_uint),
                ("height", C.c_uint), ("pitch", C.c_uint)]


class Billboard(C.Structure):
    _fields_ = [("foot", Vec3), ("width", C.c_float), ("height", C.c_float),
                ("image", C.POINTER(Image)), ("tint", C.c_uint32)]


class Pulse(C.Structure):
    _fields_ = [("center", Vec3), ("radius", C.c_float), ("rgba", C.c_uint32)]


class Camera(C.Structure):
    _fields_ = [("position", Vec3), ("target", Vec3),
                ("vertical_fov_degrees", C.c_float), ("near_plane", C.c_float),
                ("far_plane", C.c_float)]


class Scene(C.Structure):
    _fields_ = [("camera", Camera), ("background", C.c_uint32),
                ("terrain", C.POINTER(Terrain)), ("terrain_count", C.c_size_t),
                ("billboards", C.POINTER(Billboard)), ("billboard_count", C.c_size_t),
                ("pulses", C.POINTER(Pulse)), ("pulse_count", C.c_size_t),
                ("background_image", C.POINTER(Image))]


class Canvas(C.Structure):
    _fields_ = [("rgba", C.POINTER(C.c_uint32)), ("depth", C.POINTER(C.c_float)),
                ("width", C.c_uint), ("height", C.c_uint), ("pitch", C.c_uint)]


def rgba(red: int, green: int, blue: int, alpha: int = 255) -> int:
    return red | green << 8 | blue << 16 | alpha << 24


def point(x: int, y: int, z: int) -> Vec3:
    return Vec3(x / 1024, y / 1024, z / 1024)


def _image(pixels: ImagePixels, buffers: list[object]) -> Image:
    buffer = C.create_string_buffer(pixels.rgba)
    buffers.append(buffer)
    return Image(C.cast(buffer, C.POINTER(C.c_uint8)), pixels.width,
                 pixels.height, pixels.width * 4)


def _map(loaded: LoadedProject, map_id: int) -> MapRecord:
    ordered = sorted(loaded.maps, key=lambda row: str(row.id))
    if map_id < 1 or map_id > len(ordered):
        raise ValueError(f"scene map ID {map_id} has no validated map")
    return ordered[map_id - 1]


def _camera(row: MapRecord, view: SceneView, loaded: LoadedProject) -> Camera:
    profiles = {profile.id: profile for profile in loaded.camera_profiles}
    profile = profiles.get(row.presentation.camera_profile)
    fov = profile.fov_degrees if profile else 60
    near = profile.near_q10 / 1024 if profile else 0.1
    far = profile.far_q10 / 1024 if profile else 100
    directions = ((0, 1), (1, 0), (0, -1), (-1, 0))
    dx, dz = directions[view.facing]
    anchor = view.camera_anchor or (view.x, view.y, view.z)
    avatar = point(*anchor)
    position = Vec3(avatar.x - dx * 5, avatar.y + 4,
                    avatar.z - dz * 5)
    target = Vec3(avatar.x + dx, avatar.y + 1,
                  avatar.z + dz)
    return Camera(position, target, fov, near, far)


def _terrain(row: MapRecord) -> list[Terrain]:
    nav = row.navigation
    if nav is None or not 1 <= len(nav.faces) <= 256:
        raise ValueError(f"map {row.id} requires 1..256 baked navigation faces")
    vertices = [point(vertex.x, vertex.y, vertex.z) for vertex in nav.vertices]
    return [Terrain(vertices[face.a], vertices[face.b], vertices[face.c],
                    rgba(72, 119, 82) if index % 2 else rgba(89, 136, 96))
            for index, face in enumerate(nav.faces)]


def _battle_overlay(raw: bytes, width: int, height: int,
                    view: SceneView) -> bytes:
    if view.battle is None:
        return raw
    frame = bytearray(raw)
    for index, actor in enumerate(view.battle.actors[:12]):
        left, top = 12, 12 + index * 10
        length = min(80, max(1, actor.hp * 80 // 200))
        color = (238, 94, 82, 255) if actor.side else (95, 174, 255, 255)
        for y in range(top, min(top + 5, height)):
            for x in range(left, min(left + length, width)):
                frame[(y * width + x) * 4:(y * width + x) * 4 + 4] = bytes(color)
    return bytes(frame)


def render_frame(project_root: Path, loaded: LoadedProject, view: SceneView,
                 cues: tuple[CueView, ...], library: Path,
                 width: int = 1280, height: int = 720) -> bytes:
    """Render one observational frame; all game state remains Bend-owned."""
    if view.content_identity != int(loaded.content_hash[:8], 16):
        raise ValueError("scene content identity differs from validated project")
    if not (1 <= width <= 1920 and 1 <= height <= 1080):
        raise ValueError(f"frame size {width}x{height} exceeds renderer bounds")
    row = _map(loaded, view.map_id)
    assets = {str(asset.id): asset for asset in loaded.assets}
    buffers: list[object] = []
    images: list[Image] = []

    def asset_image(asset_id: object | None) -> C.POINTER(Image):
        if asset_id is None:
            return C.POINTER(Image)()
        asset = assets.get(str(asset_id))
        if asset is None:
            raise ValueError(f"presentation asset {asset_id} is not validated")
        images.append(_image(load_image(project_root, asset), buffers))
        return C.pointer(images[-1])

    terrain = _terrain(row)
    billboards = [Billboard(point(view.x, view.y, view.z), 0.8, 1.5,
                            C.POINTER(Image)(), rgba(80, 170, 255))]
    authored_npcs = sorted(row.npcs, key=lambda npc: str(npc.id))
    for npc in view.npcs:
        if not 1 <= npc.id <= len(authored_npcs):
            raise ValueError(f"NPC {npc.id} has no validated map binding")
        source = authored_npcs[npc.id - 1]
        billboards.append(Billboard(point(npc.x, npc.y, npc.z), 1.1, 1.7,
                                    asset_image(source.sprite),
                                    rgba(255, 255, 255)))
    if view.battle:
        for index, actor in enumerate(view.battle.actors):
            x = view.x + (index % 8 - 4) * 1500
            z = view.z + (3 if actor.side else 0) * 1024
            tint = rgba(240, 75, 75) if actor.side else rgba(70, 140, 255)
            billboards.append(Billboard(point(x, view.y, z), 0.8, 1.5,
                                        C.POINTER(Image)(), tint))
    if len(billboards) > 64:
        raise ValueError("scene has more than 64 billboards")
    pulses = [Pulse(point(view.x, view.y + 1024, view.z), 1.1,
                    rgba(255, 220, 70, 180)) for cue in cues if cue.kind == 0]
    if len(pulses) > 64:
        raise ValueError("scene has more than 64 VFX pulses")
    background = asset_image(row.presentation.background)
    terrain_array = (Terrain * len(terrain))(*terrain)
    billboard_array = (Billboard * len(billboards))(*billboards)
    pulse_array = (Pulse * len(pulses))(*pulses)
    scene = Scene(_camera(row, view, loaded), rgba(16, 25, 40),
                  terrain_array, len(terrain), billboard_array,
                  len(billboards), pulse_array, len(pulses), background)
    frame = (C.c_uint32 * (width * height))()
    depth = (C.c_float * (width * height))()
    canvas = Canvas(frame, depth, width, height, width * 4)
    renderer = C.CDLL(str(library))
    renderer.m9_render_scene.argtypes = [C.POINTER(Scene), C.POINTER(Canvas)]
    renderer.m9_render_scene.restype = C.c_int
    if renderer.m9_render_scene(C.byref(scene), C.byref(canvas)) != 1:
        raise RuntimeError("M9 native raster rejected a validated scene")
    return _battle_overlay(C.string_at(frame, width * height * 4),
                           width, height, view)
