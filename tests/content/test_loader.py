from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))
from content.loader import ContentError, InfrastructureError, load_project


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")


def make_project(root: Path) -> Path:
    ppm = b"P6\n1 1\n255\n\x10\x20\x30"
    (root / "assets").mkdir(parents=True)
    (root / "assets/pixel.ppm").write_bytes(ppm)
    write_json(root / "project.json", {"schemaVersion": "content-0", "id": "demo:project", "name": "Demo", "ruleset": "unassigned", "entryMap": "demo:start"})
    write_json(root / "manifest.json", {"schemaVersion": "content-0", "catalogs": ["data/catalog.json"], "maps": ["data/map.json"], "encounters": ["data/encounter.json"], "moves": [], "assets": [{"id": "demo:pixel", "path": "assets/pixel.ppm", "mediaType": "image/x-portable-pixmap", "bytes": len(ppm), "sha256": hashlib.sha256(ppm).hexdigest()}]})
    write_json(root / "data/catalog.json", {"schemaVersion": "content-0", "id": "demo:catalog", "species": [{"id": "demo:fox", "name": "Fox", "sprite": "demo:pixel"}]})
    write_json(root / "data/encounter.json", {"schemaVersion": "content-0", "id": "demo:field", "entries": [{"species": "demo:fox", "level": 1}]})
    write_json(root / "data/map.json", {"schemaVersion": "content-0", "id": "demo:start", "name": "Start", "width": 8, "height": 8, "encounters": ["demo:field"]})
    return root


def make_kernel(root: Path, output: str = "OK\n", status: int = 0) -> Path:
    kernel = root / "kernel"
    stream = "sys.stdout" if status == 0 else "sys.stderr"
    kernel.write_text("#!/usr/bin/env python3\nimport pathlib,sys\nassert sys.argv[1]=='--' and len(sys.argv)==3\np=pathlib.Path(sys.argv[2])\nassert p.is_absolute()\nassert p.read_text().split()[0]=='1'\n" + stream + ".write(" + repr(output) + ")\nsys.exit(" + str(status) + ")\n", encoding="utf-8")
    kernel.chmod(kernel.stat().st_mode | stat.S_IXUSR)
    return kernel


class LoaderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = make_project(Path(self.temp.name) / "project")
        self.kernel = make_kernel(Path(self.temp.name))

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_valid_load_is_immutable_and_calls_kernel(self) -> None:
        loaded = load_project(self.root, self.kernel)
        self.assertEqual(str(loaded.project.id), "demo:project")
        self.assertEqual(hashlib.sha256(loaded.canonical_json).hexdigest(), loaded.content_hash)
        with self.assertRaisesRegex(Exception, "cannot assign"):
            loaded.project.name = "changed"  # type: ignore[misc]

    def test_authored_move_timing_accuracy_and_animation_reference(self) -> None:
        move = {"schemaVersion": "content-0", "id": "demo:quick", "name": "Quick",
                "accuracy": 500, "windup": 0, "recovery": 30, "cooldown": 60,
                "animation": "demo:pixel"}
        write_json(self.root / "data/move.json", move)
        manifest = json.loads((self.root / "manifest.json").read_text())
        manifest["moves"] = ["data/move.json"]
        write_json(self.root / "manifest.json", manifest)
        loaded = load_project(self.root, self.kernel)
        self.assertEqual(loaded.moves[0].accuracy, 500)
        self.assertEqual((loaded.moves[0].windup, loaded.moves[0].recovery,
                          loaded.moves[0].cooldown), (0, 30, 60))

    def test_move_ranges_always_hit_and_animation_reference_are_checked(self) -> None:
        move = {"schemaVersion": "content-0", "id": "demo:quick", "name": "Quick",
                "alwaysHit": True, "windup": 601, "recovery": 30, "cooldown": 60,
                "animation": "demo:missing"}
        write_json(self.root / "data/move.json", move)
        manifest = json.loads((self.root / "manifest.json").read_text())
        manifest["moves"] = ["data/move.json"]
        write_json(self.root / "manifest.json", manifest)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/windup")
        move["windup"] = 0
        write_json(self.root / "data/move.json", move)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/animation")

    def test_move_shape_and_accuracy_mode_reject_as_content_errors(self) -> None:
        manifest = json.loads((self.root / "manifest.json").read_text())
        manifest["moves"] = ["data/move.json"]
        write_json(self.root / "manifest.json", manifest)
        write_json(self.root / "data/move.json", 7)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "shape")
        write_json(self.root / "data/move.json", {
            "schemaVersion": "content-0", "id": "demo:quick", "name": "Quick",
            "windup": 0, "recovery": 30, "cooldown": 60,
            "animation": "demo:pixel",
        })
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "accuracy-mode")

    def test_canonical_identity_ignores_json_keys_and_manifest_order(self) -> None:
        first = load_project(self.root, self.kernel).content_hash
        manifest = json.loads((self.root / "manifest.json").read_text())
        write_json(self.root / "manifest.json", dict(reversed(list(manifest.items()))))
        catalog = json.loads((self.root / "data/catalog.json").read_text())
        write_json(self.root / "data/catalog.json", dict(reversed(list(catalog.items()))))
        self.assertEqual(first, load_project(self.root, self.kernel).content_hash)

    def test_duplicate_key_rejected(self) -> None:
        (self.root / "project.json").write_text('{"schemaVersion":"content-0","schemaVersion":"content-0"}', encoding="utf-8")
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "json")

    def test_deep_json_and_escaped_surrogate_rejected_as_content(self) -> None:
        (self.root / "project.json").write_text("[" * 1100 + "]" * 1100, encoding="utf-8")
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "json")
        (self.root / "project.json").write_bytes(b'{"schemaVersion":"content-0","id":"demo:project","name":"\\ud800","ruleset":"unassigned","entryMap":"demo:start"}')
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "json")

    def test_bool_is_not_an_integer(self) -> None:
        doc = json.loads((self.root / "data/map.json").read_text())
        doc["width"] = True
        write_json(self.root / "data/map.json", doc)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/width")

    def test_unknown_key_uses_a_valid_json_pointer(self) -> None:
        doc = json.loads((self.root / "project.json").read_text())
        doc["a/b~c"] = 1
        write_json(self.root / "project.json", doc)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/a~1b~0c")

    def test_symlink_and_hardlink_rejected(self) -> None:
        source = self.root / "data/map.json"
        target = self.root / "data/real.json"
        source.rename(target)
        source.symlink_to("real.json")
        with self.assertRaises(ContentError):
            load_project(self.root, self.kernel)
        source.unlink(); os.link(target, source)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "file-type")

    def test_symlink_in_project_root_ancestry_is_rejected(self) -> None:
        alias = Path(self.temp.name) / "alias"
        alias.symlink_to(self.root.parent, target_is_directory=True)
        with self.assertRaises(ContentError) as caught:
            load_project(alias / self.root.name, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "root")

    @unittest.skipUnless(hasattr(os, "mkfifo"), "FIFO unsupported")
    def test_fifo_is_rejected_without_blocking(self) -> None:
        (self.root / "data/map.json").unlink()
        os.mkfifo(self.root / "data/map.json")
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, self.kernel)
        self.assertEqual(caught.exception.diagnostics[0].code, "file-type")

    def test_kernel_semantic_error_maps_to_source(self) -> None:
        bad = make_kernel(Path(self.temp.name), "ERR 3 0 0\n", 2)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, bad)
        diagnostic = caught.exception.diagnostics[0]
        self.assertEqual((diagnostic.file, diagnostic.pointer, diagnostic.entity_id), ("data/encounter.json", "/entries/0/level", "demo:field"))

    def test_kernel_dimension_error_points_to_height_when_width_is_valid(self) -> None:
        doc = json.loads((self.root / "data/map.json").read_text())
        doc["height"] = 0
        write_json(self.root / "data/map.json", doc)
        bad = make_kernel(Path(self.temp.name), "ERR 4 0 0\n", 2)
        with self.assertRaises(ContentError) as caught:
            load_project(self.root, bad)
        self.assertEqual(caught.exception.diagnostics[0].pointer, "/height")

    def test_kernel_wire_failure_is_infrastructure(self) -> None:
        bad = make_kernel(Path(self.temp.name), "WIRE bad-token\n", 2)
        with self.assertRaises(InfrastructureError):
            load_project(self.root, bad)

    def test_cli_exit_codes_and_json(self) -> None:
        installed = ROOT / "build/content-kernel"
        self.assertTrue(installed.is_file(), "build the native content kernel first")
        result = subprocess.run([sys.executable, ROOT / "scripts/validate_project.py", self.root], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["ok"])
        (self.root / "project.json").write_text("{}", encoding="utf-8")
        result = subprocess.run([sys.executable, ROOT / "scripts/validate_project.py", self.root], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse(json.loads(result.stdout)["ok"])


if __name__ == "__main__":
    unittest.main()
