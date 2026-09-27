#!/usr/bin/env python3
"""Run the loaded Bend journey twice and export its observed presentation evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "platform"))
sys.path.insert(0, str(ROOT / "scripts"))

from content.loader import load_project  # noqa: E402
from presentation.composer import render_frame  # noqa: E402
from presentation.media import load_audio  # noqa: E402
from presentation.wire import parse_cues, parse_scene  # noqa: E402
from export_m9_browser import export  # noqa: E402
from render_m9_frame import png_rgba  # noqa: E402


def _fixture_output(command: list[str]) -> list[str]:
    result = subprocess.run(command, cwd=ROOT, check=True, capture_output=True,
                            text=True, timeout=60)
    rows = json.loads(result.stdout.strip())
    if not isinstance(rows, str):
        raise ValueError(f"Bend journey returned non-string output: {command[0]}")
    lines = rows.splitlines()
    if len(lines) != 7:
        raise ValueError(f"Bend journey returned {len(lines)} lines; expected 7")
    return lines


def _scene_output(command: list[str]) -> str:
    result = subprocess.run(command, cwd=ROOT, check=True, capture_output=True,
                            text=True, timeout=60)
    scene = json.loads(result.stdout.strip())
    if not isinstance(scene, str) or scene == "FAIL":
        raise ValueError(f"Bend movement scene failed: {command[0]}")
    return scene


def _signature(line: str) -> tuple[str, str, str, str, str, str, str]:
    parts = line.split("|")
    if len(parts) != 9 or parts[0] != "OK" or parts[1] != "0":
        raise ValueError(f"loaded journey did not return a committed battle: {line[:80]}")
    if (not parts[5].startswith("entities=") or
            not parts[6].startswith("battle=") or
            not parts[7].startswith("events=") or
            not parts[8].startswith("captures=")):
        raise ValueError("loaded journey lacks a projected battle scene")
    return (parts[2], parts[3], parts[4], parts[5][9:], parts[6][7:],
            parts[7][7:], parts[8][9:])


def run(project: Path, output: Path, native: Path, javascript: Path,
        native_move: Path, javascript_move: Path,
        raster_library: Path) -> dict[str, object]:
    """Compare exact Bend target output and materialize frames from its DTOs."""
    native_lines = _fixture_output([str(native), "--threads", "1", "--gpu", "off"])
    javascript_lines = _fixture_output(["node", str(javascript)])
    if native_lines != javascript_lines:
        raise ValueError("loaded journey differs between native and JavaScript Bend targets")
    (initial_wire, observed_wire, first_cues, second_cues, headless,
     observed, ok) = native_lines
    if initial_wire != observed_wire or headless != observed or ok != "True":
        raise ValueError("headless and presentation-observed logical journeys diverged")
    event_and_move = _scene_output([str(native_move), "--threads", "1",
                                    "--gpu", "off"])
    if event_and_move != _scene_output(["node", str(javascript_move)]):
        raise ValueError("loaded event and movement scenes differ across Bend targets")
    phases = event_and_move.split(";")
    if len(phases) != 2:
        raise ValueError("loaded event/move fixture must emit two scene wires")
    event_wire, move_wire = phases
    (final_wire, meter_rng, world_values, world_entities, battle_wire,
     battle_events, capture_events) = _signature(headless)
    loaded = load_project(project)
    scenes = {name: parse_scene(wire) for name, wire in
              (("initial", initial_wire), ("battle", battle_wire), ("returned", final_wire))}
    event_scene = parse_scene(event_wire)
    if scenes["initial"].battle is not None or scenes["battle"].battle is None or scenes["returned"].battle is not None:
        raise ValueError("loaded journey is missing world/battle/return scene phases")
    if any(scene.content_identity != int(loaded.content_hash[:8], 16)
           for scene in scenes.values()):
        raise ValueError("loaded scene identity differs from validated project")
    # Event output 42 changes persistent state but not the scene projection's
    # visible world position; its second frame carries the emitted cue.
    sequence_wires = [initial_wire, event_wire, move_wire, battle_wire,
                      final_wire]
    sequence = tuple(parse_scene(wire) for wire in sequence_wires)
    if (event_scene.battle is not None or
            (event_scene.x, event_scene.y, event_scene.z) !=
            (scenes["initial"].x, scenes["initial"].y, scenes["initial"].z) or
            sequence[2].battle is not None or sequence[2].x == sequence[0].x
            or sequence[3].battle is None or sequence[4].battle is not None
            or any(scene.content_identity != scenes["initial"].content_identity
                   for scene in sequence)):
        raise ValueError("loaded scenes do not show movement, battle and world return")
    cues = parse_cues(first_cues) + parse_cues(second_cues)
    if not any(cue.kind == 0 and cue.payload == 7 for cue in cues):
        raise ValueError("loaded event did not emit the expected signal cue 7")
    output.mkdir(parents=True, exist_ok=True)
    wires = output / "wires"
    wires.mkdir(exist_ok=True)
    (wires / "initial.csv").write_text(initial_wire + "\n", encoding="ascii")
    (wires / "event.csv").write_text(event_wire + "\n", encoding="ascii")
    (wires / "battle.csv").write_text(battle_wire + "\n", encoding="ascii")
    (wires / "returned.csv").write_text(final_wire + "\n", encoding="ascii")
    (wires / "moved.csv").write_text(move_wire + "\n", encoding="ascii")
    for name, wire in (("activation", first_cues), ("signal", second_cues)):
        (wires / f"{name}-cues.csv").write_text(wire + "\n", encoding="ascii")
    (wires / "no-cues.csv").write_text("1,0\n", encoding="ascii")
    frames: dict[str, str] = {}
    for name, scene in scenes.items():
        rgba = render_frame(project, loaded, scene, (),
                            raster_library, 320, 180)
        rgba_path = output / f"{name}.rgba"
        rgba_path.write_bytes(rgba)
        (output / f"{name}.png").write_bytes(png_rgba(320, 180, rgba))
        frames[name] = hashlib.sha256(rgba).hexdigest()
    event_rgba = render_frame(project, loaded, event_scene, tuple(cues),
                              raster_library, 320, 180)
    (output / "event.rgba").write_bytes(event_rgba)
    (output / "event.png").write_bytes(png_rgba(320, 180, event_rgba))
    frames["event"] = hashlib.sha256(event_rgba).hexdigest()
    for index, scene in enumerate(sequence):
        active_cues = cues if index == 1 else ()
        rgba = render_frame(project, loaded, scene, tuple(active_cues),
                            raster_library, 320, 180)
        stem = f"sequence-{index:02d}"
        (output / f"{stem}.rgba").write_bytes(rgba)
        (output / f"{stem}.png").write_bytes(png_rgba(320, 180, rgba))
        frames[stem] = hashlib.sha256(rgba).hexdigest()
    # The event projection retains the same visible point but carries cue 42.
    export(project, wires / "event.csv", wires / "signal-cues.csv",
           output / "browser")
    export(project, wires / "battle.csv", wires / "no-cues.csv",
           output / "browser-battle")
    binding = next((row for row in loaded.audio_bindings
                    if any(cue.kind == 0 and cue.payload == row.signal_kind
                           for cue in cues)), None)
    if binding is None:
        raise ValueError("loaded signal has no validated audio binding")
    asset = next((asset for asset in loaded.assets if asset.id == binding.asset), None)
    if asset is None:
        raise ValueError(f"audio binding {binding.signal_kind} has no validated asset")
    audio = load_audio(project, asset)
    (output / "cue.pcm").write_bytes(audio.pcm_s16le)
    report: dict[str, object] = {
        "contentHash": loaded.content_hash,
        "fixtures": ["tests/m9/loaded_parity_test.bend",
                     "tests/m9/loaded_move_scene_test.bend"],
        "nativeJavascriptExact": True,
        "headlessObservedExact": True,
        "finalSignatureSha256": hashlib.sha256(headless.encode("ascii")).hexdigest(),
        "finalMeterRng": meter_rng,
        "finalWorldValues": world_values,
        "finalWorldEntities": world_entities,
        "battleReturnEvents": battle_events,
        "battleReturnCaptures": capture_events,
        "cueOccurrences": [{"ordinal": cue.ordinal, "index": cue.index,
                            "kind": cue.kind, "payload": cue.payload}
                           for cue in cues],
        "frameSha256": frames,
        "sceneSequenceFrames": len(sequence),
        "cueFrameIndex": 1,
        "sceneSequenceBattleFrames": [index for index, scene in enumerate(sequence)
                                      if scene.battle is not None],
        "audio": {"channels": audio.channels, "sampleRate": audio.sample_rate,
                  "pcmBytes": len(audio.pcm_s16le),
                  "pcmSha256": hashlib.sha256(audio.pcm_s16le).hexdigest()},
    }
    (output / "parity.json").write_text(json.dumps(report, indent=2) + "\n",
                                        encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT / "examples/m8-world")
    parser.add_argument("--output", type=Path, default=ROOT / "build/evidence/m9-journey")
    parser.add_argument("--native", type=Path, default=ROOT / "build/m9_loaded_parity_test")
    parser.add_argument("--javascript", type=Path, default=ROOT / "build/m9_loaded_parity_test.js")
    parser.add_argument("--native-move", type=Path,
                        default=ROOT / "build/m9_loaded_move_scene_test")
    parser.add_argument("--javascript-move", type=Path,
                        default=ROOT / "build/m9_loaded_move_scene_test.js")
    parser.add_argument("--raster-library", type=Path,
                        default=ROOT / "build/m9-raster.so")
    args = parser.parse_args()
    report = run(args.project, args.output, args.native, args.javascript,
                 args.native_move, args.javascript_move,
                 args.raster_library)
    print("M9 loaded journey parity and presentation evidence: "
          f"{report['finalSignatureSha256']}")


if __name__ == "__main__":
    main()
