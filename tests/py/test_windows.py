"""Layer-shell windows and their visibility.

Quickshell deletes a layer-shell window when `visible` goes false and builds a
new one when it goes true; while building it emits width/height/screen changes
and then uses the window. A `visible` that reads geometry or an animated value
can flip back to false in that moment, the window is deleted under
Quickshell, and it segfaults (QQuickWindow::contentItem on null). So a
window's own `visible` is a plain state (or a MapGate's `mapped`), never
geometry, opacity or an animation's progress.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GEOMETRY = re.compile(r"\.(x|y|width|height|opacity)\b|\b(x|y|width|height|opacity)\s*[<>=]")


def window_visible_lines():
    for f in sorted((ROOT / "shell").rglob("*.qml")):
        text = f.read_text(encoding="utf-8")
        if not re.search(r"^PanelWindow\s*\{", text, re.M):
            continue
        for m in re.finditer(r"^    visible:\s*(.+)$", text, re.M):   # the window's own, at root indent
            yield f.relative_to(ROOT), m.group(1)


class WindowVisibility(unittest.TestCase):
    def test_no_window_visibility_from_geometry_or_animation(self):
        bad = [f"{f}: visible: {expr}" for f, expr in window_visible_lines() if GEOMETRY.search(expr)]
        self.assertEqual(bad, [])

    def test_every_blurred_window_resends_its_region(self):
        # Without BlurKick a rebuilt window can lose its blur region, and niri
        # then blurs the whole surface (see shell/components/BlurKick.qml).
        missing = []
        for f in sorted((ROOT / "shell").rglob("*.qml")):
            text = f.read_text(encoding="utf-8")
            if "BackgroundEffect.blurRegion:" in text and "BlurKick {" not in text:
                missing.append(str(f.relative_to(ROOT)))
        self.assertEqual(missing, [])

    def test_no_window_follows_the_focused_screen(self):
        # A window whose screen changes is rebuilt by Quickshell; on NVIDIA the
        # rebuilt dock came up blurred whole. Windows stay on their screen (one
        # per screen, in Variants) and show or hide instead.
        bad = []
        for f in sorted((ROOT / "shell").rglob("*.qml")):
            text = f.read_text(encoding="utf-8")
            for m in re.finditer(r"\b(?:screen|targetScreen)\s*:\s*(\{.*?\n\s*\}|[^\n]*)", text, re.S):
                if "focusedOutput" in m.group(1):
                    bad.append(f"{f.relative_to(ROOT)}: {m.group(0)[:80]}")
        self.assertEqual(bad, [])

    def test_the_check_sees_the_windows(self):
        self.assertGreater(len(list(window_visible_lines())), 10)


if __name__ == "__main__":
    unittest.main()
