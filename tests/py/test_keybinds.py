"""KEYBINDS.md → binds.kdl: no key bound twice (niri rejects the whole config)."""
import re
import subprocess
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class Keybinds(unittest.TestCase):
    def test_no_duplicate_keys(self):
        with tempfile.TemporaryDirectory() as tmp:
            kdl, js = Path(tmp) / "b.kdl", Path(tmp) / "b.json"
            r = subprocess.run([sys.executable, str(ROOT / "lib" / "keybinds.py"), str(ROOT / "KEYBINDS.md"), str(kdl), str(js)],
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            keys = [m.group(1).lower() for m in re.finditer(r"^\s{4}([A-Za-z0-9_+]+)\s", kdl.read_text(), re.M)]
            dupes = [k for k, n in Counter(keys).items() if n > 1]
            self.assertEqual(dupes, [])

    def test_mod_slash_opens_the_keybind_sheet(self):
        # KEYBINDS.md promises it; the shell's sheet reads binds.json.
        with tempfile.TemporaryDirectory() as tmp:
            kdl = Path(tmp) / "b.kdl"
            subprocess.run([sys.executable, str(ROOT / "lib" / "keybinds.py"), str(ROOT / "KEYBINDS.md"), str(kdl),
                            str(Path(tmp) / "b.json")], check=True, capture_output=True)
            line = next((l for l in kdl.read_text().splitlines() if l.strip().startswith("Mod+Slash ")), "")
            self.assertIn('"keybinds" "toggle"', line)

    def test_every_row_resolves(self):
        with tempfile.TemporaryDirectory() as tmp:
            r = subprocess.run([sys.executable, str(ROOT / "lib" / "keybinds.py"), str(ROOT / "KEYBINDS.md"),
                                str(Path(tmp) / "b.kdl"), str(Path(tmp) / "b.json")], capture_output=True, text=True)
            self.assertNotIn("had no known action", r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
