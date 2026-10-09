"""vitrum-steam: the installed Steam games, for the launcher's Games tab."""
import importlib.machinery
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
loader = importlib.machinery.SourceFileLoader("vitrum_steam", str(ROOT / "tools" / "vitrum-steam"))
spec = importlib.util.spec_from_loader("vitrum_steam", loader)
S = importlib.util.module_from_spec(spec)
loader.exec_module(S)


def acf(appid, name, last="0", flags="4"):
    return ('"AppState"\n{\n\t"appid"\t\t"%s"\n\t"name"\t\t"%s"\n\t"StateFlags"\t\t"%s"\n\t"LastPlayed"\t\t"%s"\n}\n'
            % (appid, name, flags, last))


class Library(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.steam = Path(self.tmp.name) / "Steam"
        apps = self.steam / "steamapps"
        apps.mkdir(parents=True)
        other = Path(self.tmp.name) / "games"
        (other / "steamapps").mkdir(parents=True)
        (apps / "libraryfolders.vdf").write_text(
            '"libraryfolders"\n{\n\t"0"\n\t{\n\t\t"path"\t\t"%s"\n\t}\n\t"1"\n\t{\n\t\t"path"\t\t"%s"\n\t}\n'
            '\t"2"\n\t{\n\t\t"path"\t\t"/not/mounted"\n\t}\n}\n' % (self.steam, other))
        (apps / "appmanifest_2379780.acf").write_text(acf("2379780", "Balatro", "1791040419"))
        (apps / "appmanifest_1493710.acf").write_text(acf("1493710", "Proton Experimental"))
        (apps / "appmanifest_228980.acf").write_text(acf("228980", "Steamworks Common Redistributables"))
        (other / "steamapps" / "appmanifest_730.acf").write_text(acf("730", "Counter-Strike 2", "0", "1026"))
        cache = self.steam / "appcache" / "librarycache"
        (cache / "730").mkdir(parents=True)
        (cache / "730" / "library_600x900.jpg").write_bytes(b"x")
        (cache / "2379780" / "abc").mkdir(parents=True)
        (cache / "2379780" / "abc" / "library_600x900.jpg").write_bytes(b"x")
        conf = self.steam / "userdata" / "1" / "config"
        conf.mkdir(parents=True)
        (conf / "localconfig.vdf").write_text('"UserLocalConfigStore"\n{\n\t"Software"\n\t{\n\t\t"Valve"\n\t\t{\n\t\t\t"Steam"\n\t\t\t{\n'
                                              '\t\t\t\t"apps"\n\t\t\t\t{\n\t\t\t\t\t"730"\n\t\t\t\t\t{\n'
                                              '\t\t\t\t\t\t"LastPlayed"\t\t"1791038562"\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n}\n')

    def tearDown(self):
        self.tmp.cleanup()

    def test_games_only_newest_first(self):
        games = S.games(self.steam)
        self.assertEqual([g["name"] for g in games], ["Balatro", "Counter-Strike 2"])

    def test_last_played_from_the_user_config(self):
        cs = [g for g in S.games(self.steam) if g["appid"] == 730][0]
        self.assertEqual(cs["lastPlayed"], 1791038562)

    def test_covers(self):
        g = {x["appid"]: x for x in S.games(self.steam)}
        self.assertTrue(g[730]["cover"].endswith("730/library_600x900.jpg"))
        self.assertTrue(g[2379780]["cover"].endswith("abc/library_600x900.jpg"))

    def test_no_steam_no_games(self):
        self.assertEqual(S.games(Path(self.tmp.name) / "nothing"), [])

    def test_vdf_parser(self):
        d = S.parse_vdf('"a"\n{\n\t"b"\t\t"1"\n\t"c"\n\t{\n\t\t"d"\t"x \\" y"\n\t}\n}\n')
        self.assertEqual(d, {"a": {"b": "1", "c": {"d": 'x " y'}}})


if __name__ == "__main__":
    unittest.main()
