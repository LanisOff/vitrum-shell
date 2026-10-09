"""vitrum-portal: the screen-share portal backend's decisions (no D-Bus here)."""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import vitrum_portal as P  # noqa: E402


class CursorModes(unittest.TestCase):
    def test_portal_bits_to_mutter(self):
        # portal: 1 hidden, 2 embedded, 4 metadata — mutter: 0, 1, 2
        self.assertEqual(P.mutter_cursor(1), 0)
        self.assertEqual(P.mutter_cursor(2), 1)
        self.assertEqual(P.mutter_cursor(4), 2)

    def test_unknown_or_unset_means_embedded(self):
        # Discord does not ask; a visible pointer is what people expect.
        self.assertEqual(P.mutter_cursor(0), 1)
        self.assertEqual(P.mutter_cursor(None), 1)

    def test_the_picker_toggle_wins(self):
        self.assertEqual(P.mutter_cursor(4, show_cursor=False), 0)
        self.assertEqual(P.mutter_cursor(1, show_cursor=True), 1)


class Answers(unittest.TestCase):
    def test_monitor(self):
        a = P.parse_answer('{"ok": true, "cursor": true, "sources": [{"type": "monitor", "connector": "DP-2"}]}')
        self.assertTrue(a["ok"])
        self.assertEqual(a["sources"], [{"type": "monitor", "connector": "DP-2"}])
        self.assertTrue(a["cursor"])

    def test_window(self):
        a = P.parse_answer('{"ok": true, "sources": [{"type": "window", "id": 42}]}')
        self.assertEqual(a["sources"], [{"type": "window", "id": 42}])
        self.assertIsNone(a["cursor"])

    def test_cancel_and_garbage_are_cancel(self):
        self.assertFalse(P.parse_answer('{"ok": false}')["ok"])
        self.assertFalse(P.parse_answer("not json")["ok"])
        self.assertFalse(P.parse_answer('{"ok": true, "sources": []}')["ok"])
        self.assertFalse(P.parse_answer('{"ok": true, "sources": [{"type": "window"}]}')["ok"])

    def test_only_what_was_asked_for(self):
        a = P.parse_answer('{"ok": true, "sources": [{"type": "window", "id": 1}]}', types=P.MONITOR)
        self.assertFalse(a["ok"])
        a = P.parse_answer('{"ok": true, "sources": [{"type": "monitor", "connector": "A"}, {"type": "monitor", "connector": "B"}]}',
                           multiple=False)
        self.assertEqual(len(a["sources"]), 1)


class Streams(unittest.TestCase):
    def test_stream_entry(self):
        s = P.stream_entry(57, {"type": "monitor", "connector": "DP-2"}, {"position": (1920, 0), "size": (1920, 1080)})
        self.assertEqual(s, (57, {"source_type": 1, "position": (1920, 0), "size": (1920, 1080)}))

    def test_window_stream_without_parameters(self):
        s = P.stream_entry(9, {"type": "window", "id": 3}, {})
        self.assertEqual(s, (9, {"source_type": 2}))


class Active(unittest.TestCase):
    def test_write_active(self):
        import json
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "active.json"
            P.write_active(path, [{"session": "/s/1", "app": "vesktop"}])
            self.assertEqual(json.loads(path.read_text()), {"sessions": [{"session": "/s/1", "app": "vesktop"}]})
            P.write_active(path, [])
            self.assertEqual(json.loads(path.read_text()), {"sessions": []})


if __name__ == "__main__":
    unittest.main()
