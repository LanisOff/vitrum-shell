"""vitrum-calendar: khal's JSON read for the shell; configs written only when ours."""
import importlib.machinery
import importlib.util
import os
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(home):
    os.environ["XDG_DATA_HOME"] = str(home / "share")
    os.environ["XDG_CONFIG_HOME"] = str(home / "config")
    loader = importlib.machinery.SourceFileLoader("vitrum_calendar", str(ROOT / "tools" / "vitrum-calendar"))
    spec = importlib.util.spec_from_loader("vitrum_calendar", loader)
    m = importlib.util.module_from_spec(spec)
    loader.exec_module(m)
    return m


class Calendar(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.C = load(self.home)

    def tearDown(self):
        self.tmp.cleanup()

    def test_normalize_khal_json(self):
        rows = ('[{"uid": "a1", "title": "Dentist", "start-long": "2026-10-04 14:00", "end-long": "2026-10-04 15:00",'
                ' "all-day": "False", "calendar": "local", "location": ""}]\n'
                '[{"uid": "b2", "title": "Trip", "start-long": "2026-10-05", "end-long": "2026-10-07",'
                ' "all-day": "True", "calendar": "work", "location": "Riga"}]\n')
        ev = self.C.normalize(rows)
        self.assertEqual([e["title"] for e in ev], ["Dentist", "Trip"])
        self.assertFalse(ev[0]["allDay"])
        self.assertTrue(ev[1]["allDay"])
        self.assertEqual(ev[1]["location"], "Riga")

    def test_an_event_over_several_days_is_listed_once_per_start(self):
        row = '[{"uid": "b2", "title": "Trip", "start-long": "2026-10-05", "end-long": "2026-10-07", "all-day": "True"}]\n'
        self.assertEqual(len(self.C.normalize(row * 3)), 1)

    def test_garbage_lines_are_skipped(self):
        self.assertEqual(self.C.normalize("warning: something\n\n[not json\n"), [])

    def test_khal_config_written_once_and_kept_when_yours(self):
        self.C.ensure()
        conf = self.home / "config" / "khal" / "config"
        self.assertTrue(conf.read_text().startswith(self.C.MARK))
        self.assertIn("type = discover", conf.read_text())
        conf.write_text("[calendars]\n# mine\n")
        self.C.ensure()
        self.assertEqual(conf.read_text(), "[calendars]\n# mine\n")

    def test_caldav_config_reads_the_password_from_a_file(self):
        text = self.C.vdirsyncer_caldav("https://dav.example/", "me")
        self.assertIn('password.fetch = ["command", "cat"', text)
        self.assertNotIn("secret", text)

    def test_config_values_are_escaped(self):
        text = self.C.vdirsyncer_caldav('https://x/"evil', 'me"\nurl = "y')
        self.assertIn('url = "https://x/\\"evil"', text)
        self.assertEqual(text.count("\nurl ="), 1, "no second key smuggled in")

    def test_delete_matches_the_whole_uid(self):
        self.C.ensure()
        a = self.C.LOCAL / "a.ics"; a.write_text("BEGIN:VEVENT\nUID:abc\nEND:VEVENT\n")
        b = self.C.LOCAL / "b.ics"; b.write_text("BEGIN:VEVENT\nUID:abcdef\nEND:VEVENT\n")
        self.assertEqual(self.C.find_ics("abcdef"), b)
        self.assertEqual(self.C.find_ics("abc"), a)
        self.assertIsNone(self.C.find_ics(""), "an empty uid matches nothing")
        self.assertIsNone(self.C.find_ics("ab"), "a prefix matches nothing")

    def test_not_connected_without_a_config(self):
        self.assertFalse(self.C.connected())


if __name__ == "__main__":
    unittest.main()
