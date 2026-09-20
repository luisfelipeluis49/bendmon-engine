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
    write_json(root / "manifest.json", {"schemaVersion": "content-0", "catalogs": ["data/catalog.json"], "maps": ["data/map.json"], "encounters": ["data/encounter.json"], "assets": [{"id": "demo:pixel", "path": "assets/pixel.ppm", "mediaType": "image/x-portable-pixmap", "bytes": len(ppm), "sha256": hashlib.sha256(ppm).hexdigest()}]})
    write_json(root / "data/catalog.json", {"schemaVersion": "content-0", "id": "demo:catalog", "species": [{"id": "demo:fox", "name": "Fox", "sprite": "demo:pixel"}]})
    write_json(root / "data/encounter.json", {"schemaVersion": "content-0", "id": "demo:field", "entries": [{"species": "demo:fox", "level": 1}]})
    write_json(root / "data/map.json", {"schemaVersion": "content-0", "id": "demo:start", "name": "Start", "width": 8, "height": 8, "encounters": ["demo:field"]})
    return root


def make_kernel(root: Path, output: str = "OK\n", status: int = 0) -> Path:
    kernel = root / "kernel"
    kernel.write_text("#!/usr/bin/env python3\nimport pathlib,sys\nassert sys.argv[1]=='--' and len(sys.argv)==3\np=pathlib.Path(sys.argv[2])\nassert p.is_absolute()\nassert p.read_text().split()[0]=='1'\nsys.stdout.write(" + repr(output) + ")\nsys.exit(" + str(status) + ")\n", encoding="utf-8")
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
        build = ROOT / "build"
        build.mkdir(exist_ok=True)
        installed = build / "content-kernel"
        previous = installed.read_bytes() if installed.exists() else None
        previous_mode = installed.stat().st_mode if installed.exists() else None
        try:
            installed.write_bytes(self.kernel.read_bytes()); installed.chmod(0o700)
            result = subprocess.run([sys.executable, ROOT / "scripts/validate_project.py", self.root], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(json.loads(result.stdout)["ok"])
            (self.root / "project.json").write_text("{}", encoding="utf-8")
            result = subprocess.run([sys.executable, ROOT / "scripts/validate_project.py", self.root], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertFalse(json.loads(result.stdout)["ok"])
        finally:
            if previous is None:
                installed.unlink(missing_ok=True)
            else:
                installed.write_bytes(previous); installed.chmod(previous_mode or 0o700)


if __name__ == "__main__":
    unittest.main()
