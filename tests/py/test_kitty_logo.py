"""lib/kitty-logo.py: the fastfetch logo as kitty unicode placeholders.
fastfetch's own tmux wrapping left kitty's escape open and kitty hung; every
escape here must close, inside tmux's passthrough too."""
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# A real PNG over one 4096-byte piece of base64, so it goes in several.
PNG = b"\x89PNG\r\n\x1a\n" + bytes(range(256)) * 20


class KittyLogo(unittest.TestCase):
    def make(self, cols=30, rows=15):
        with tempfile.TemporaryDirectory() as t:
            t = Path(t)
            (t / "logo.png").write_bytes(PNG)
            r = subprocess.run([sys.executable, str(ROOT / "lib/kitty-logo.py"), str(t / "logo.png"), str(cols), str(rows),
                                str(t / "logo.kitty"), str(t / "logo.tmux")], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            return (t / "logo.kitty").read_text(encoding="utf-8"), (t / "logo.tmux").read_text(encoding="utf-8")

    def test_every_graphics_escape_is_closed(self):
        kitty, _ = self.make()
        apcs = re.findall(r"\x1b_G([^\x1b]*)\x1b\\", kitty)
        self.assertGreater(len(apcs), 1)
        self.assertEqual(kitty.count("\x1b_G"), len(apcs))
        self.assertIn("U=1", apcs[0])
        self.assertTrue(all("q=2" in a for a in apcs))
        self.assertTrue(apcs[-1].startswith("q=2,m=0;"))

    def test_tmux_passthrough_doubles_every_escape_inside(self):
        _, tmux = self.make()
        pieces = re.findall(r"\x1bPtmux;((?:\x1b\x1b|[^\x1b])*)\x1b\\", tmux)
        self.assertGreater(len(pieces), 1)
        for p in pieces:
            inner = p.replace("\x1b\x1b", "\x1b")
            self.assertTrue(inner.startswith("\x1b_G") and inner.endswith("\x1b\\"), repr(inner[-8:]))
        # Nothing but the passthroughs comes before the cells.
        self.assertTrue(re.sub(r"\x1bPtmux;(?:\x1b\x1b|[^\x1b])*\x1b\\", "", tmux).startswith("\x1b[38;5;"))

    def test_the_grid_is_cols_by_rows(self):
        kitty, _ = self.make(cols=12, rows=6)
        grid = kitty[kitty.index("\x1b[38;5;"):]
        rows = grid.split("\x1b[12D\x1bD")
        self.assertEqual(len(rows), 6)
        self.assertTrue(all(r.count("\U0010EEEE") == 12 for r in rows))
        # Row, column and the id's high byte: three diacritics a cell.
        cell = re.search("\U0010EEEE(.*?)(?=\U0010EEEE)", rows[1]).group(1)
        self.assertEqual(len(cell), 3)

    def test_a_box_too_big_is_refused(self):
        with tempfile.TemporaryDirectory() as t:
            (Path(t) / "logo.png").write_bytes(PNG)
            r = subprocess.run([sys.executable, str(ROOT / "lib/kitty-logo.py"), str(Path(t) / "logo.png"), "65", "15",
                                str(Path(t) / "a"), str(Path(t) / "b")], capture_output=True, text=True)
            self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
