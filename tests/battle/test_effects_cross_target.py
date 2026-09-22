"""Cross-target golden for the production M4 effect interpreter."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
BEND = ROOT / "scripts" / "bend"
ENTRY = ROOT / "tests" / "battle" / "effects_cross_target.bend"
EXPECTED = "1n"


class EffectCrossTargetTests(unittest.TestCase):
    def test_native_and_javascript_match_the_effect_order_golden(self) -> None:
        env = dict(os.environ, BEND_NO_TELEMETRY="1")
        with tempfile.TemporaryDirectory(prefix="m4-effects.") as temporary:
            native = Path(temporary) / "effects"
            javascript = Path(temporary) / "effects.js"
            subprocess.run([str(BEND), str(ENTRY), "-o", str(native)],
                           cwd=ROOT, env=env, check=True, capture_output=True, text=True)
            subprocess.run([str(BEND), str(ENTRY), "-o", str(javascript)],
                           cwd=ROOT, env=env, check=True, capture_output=True, text=True)
            native_output = subprocess.run([str(native)], cwd=ROOT, env=env,
                                           check=True, capture_output=True, text=True).stdout.strip()
            js_output = subprocess.run(["node", str(javascript)], cwd=ROOT, env=env,
                                       check=True, capture_output=True, text=True).stdout.strip()
        self.assertEqual(native_output, EXPECTED)
        self.assertEqual(js_output, EXPECTED)
        self.assertEqual(native_output, js_output)


if __name__ == "__main__":
    unittest.main()
