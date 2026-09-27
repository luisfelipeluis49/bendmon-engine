"""Static browser export stays joined to validated M8 content and M9 wires."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "platform"))
sys.path.insert(0, str(ROOT / "scripts"))
from content.loader import load_project
from export_m9_browser import export
from presentation.wire import SceneWireError


class BrowserExportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.project = ROOT / "examples/m8-world"
        cls.loaded = load_project(cls.project)

    def scene(self, identity: int | None = None) -> str:
        identity = int(self.loaded.content_hash[:8], 16) if identity is None else identity
        # One player, one visible NPC, no event, and no battle.
        fields = ([1, identity, 1] + [0, 0] * 3 + [0] + [0, 0] * 3 +
                  [1, 1] + [0, 0, 0, 0, 0, 1024] + [0, 0, 0])
        return ",".join(map(str, fields))

    def test_exports_dto_media_and_exact_wires(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            scene, cues = root / "scene.csv", root / "cues.csv"
            output = root / "bundle"
            scene.write_text(self.scene(), encoding="ascii")
            cues.write_text("1,1,4,0,0,7,0\n", encoding="ascii")
            export(self.project, scene, cues, output)
            dto = json.loads((output / "content.json").read_text(encoding="utf-8"))
            self.assertEqual(dto["contentIdentity"], int(self.loaded.content_hash[:8], 16))
            self.assertEqual(dto["maps"][0]["runtimeId"], 1)
            self.assertEqual(dto["maps"][0]["npcs"][0]["runtimeId"], 1)
            self.assertEqual(dto["maps"][0]["npcs"][0]["spriteAssetId"], "sample:guide")
            self.assertIn("sample:grove-sky", dto["assets"])
            for record in dto["assets"].values():
                path = record.get("image", record.get("audio"))
                self.assertIsNotNone(path)
                self.assertTrue((output / path).is_file())
            self.assertEqual((output / "scene.csv").read_text().strip(), self.scene())
            self.assertTrue((output / "renderer.mjs").is_file())
            self.assertTrue((output / "index.html").is_file())
            script = ("import fs from 'node:fs'; import {pathToFileURL} from 'node:url'; "
                      "const root=process.argv[1]; const dto=JSON.parse(fs.readFileSync(root+'/content.json')); "
                      "const scene=fs.readFileSync(root+'/scene.csv','utf8').trim(); "
                      "const {renderScene}=await import(pathToFileURL(root+'/renderer.mjs')); "
                      "const ctx={canvas:{width:320,height:180},fillRect(){},beginPath(){},moveTo(){},lineTo(){},"
                      "closePath(){},fill(){},stroke(){},arc(){},drawImage(){},fillText(){}}; "
                      "renderScene(ctx,scene,dto,fs.readFileSync(root+'/cues.csv','utf8').trim());")
            subprocess.run(["node", "--input-type=module", "-e", script, str(output)],
                           check=True, capture_output=True, text=True)

    def test_rejects_wrong_content_identity_before_bundle_creation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            scene, cues, output = root / "scene.csv", root / "cues.csv", root / "bundle"
            scene.write_text(self.scene(1), encoding="ascii")
            cues.write_text("1,0", encoding="ascii")
            with self.assertRaisesRegex(ValueError, "identity"):
                export(self.project, scene, cues, output)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
