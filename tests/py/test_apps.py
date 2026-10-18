"""vitrum-apps: default applications (mimeapps.list) and XDG autostart."""
import importlib.machinery
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(env):
    old = {k: os.environ.get(k) for k in env}
    os.environ.update(env)
    try:
        loader = importlib.machinery.SourceFileLoader("vitrum_apps", str(ROOT / "tools" / "vitrum-apps"))
        spec = importlib.util.spec_from_loader("vitrum_apps", loader)
        mod = importlib.util.module_from_spec(spec)
        loader.exec_module(mod)
        return mod
    finally:
        for k, v in old.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


def desktop(path, **keys):
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = ["[Desktop Entry]", "Type=Application"] + ["%s=%s" % (k.replace("__", "-"), v) for k, v in keys.items()]
    path.write_text("\n".join(lines) + "\n[Desktop Action new]\nName=Not this\nExec=nope\n")


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.config, self.data, self.sysconf, self.sysdata = t / "config", t / "data", t / "etc/xdg", t / "usr/share"
        for d in (self.config, self.data, self.sysconf, self.sysdata):
            d.mkdir(parents=True)
        self.A = load({"XDG_CONFIG_HOME": str(self.config), "XDG_DATA_HOME": str(self.data),
                       "XDG_CONFIG_DIRS": str(self.sysconf), "XDG_DATA_DIRS": str(self.sysdata),
                       "XDG_CURRENT_DESKTOP": "niri", "LANG": "ru_RU.UTF-8"})

    def tearDown(self):
        self.tmp.cleanup()


class Exec(Base):
    def test_field_codes_and_quoting(self):
        A = self.A
        self.assertEqual(A.exec_argv("firefox %u"), ["firefox"])
        self.assertEqual(A.exec_argv('sh -c "echo \\"hi\\" 100%%" %F'), ["sh", "-c", 'echo "hi" 100%'])
        self.assertEqual(A.exec_argv('app %i --name %c', {"Icon": "x", "Name": "App"}), ["app", "--icon", "x", "--name", "App"])
        self.assertEqual(A.exec_argv('a ""'), ["a", ""])

    def test_localized_name_and_escapes(self):
        p = self.sysdata / "applications/t.desktop"
        desktop(p, Name="Text", **{"Name[ru]": "Текст"}, Comment="a\\sb")
        e = self.A.read_entry(p)
        self.assertEqual(self.A.localized(e, "Name"), "Текст")
        self.assertEqual(e["Comment"], "a b")
        self.assertNotIn("Not this", e.values())


class Defaults(Base):
    def setUp(self):
        super().setUp()
        apps = self.sysdata / "applications"
        desktop(apps / "firefox.desktop", Name="Firefox", Exec="firefox %u", MimeType="text/html;x-scheme-handler/https;x-scheme-handler/http;")
        desktop(apps / "org.kde.dolphin.desktop", Name="Dolphin", Exec="dolphin %u", MimeType="inode/directory;")
        desktop(apps / "viewer.desktop", Name="HTML viewer", Exec="v %f", MimeType="text/html;")
        desktop(apps / "kde4/old.desktop", Name="Old", Exec="o", MimeType="inode/directory;", NoDisplay="true")
        desktop(self.data / "applications/mine.desktop", Name="Mine", Exec="m", MimeType="inode/directory;")

    def test_offers_and_current(self):
        (self.sysconf / "mimeapps.list").write_text("[Default Applications]\ninode/directory=gone.desktop;org.kde.dolphin.desktop;\n")
        d = {x["kind"]: x for x in self.A.defaults(self.A.applications())}
        self.assertEqual([a["id"] for a in d["browser"]["apps"]], ["firefox.desktop"], "an HTML viewer is not a browser")
        self.assertEqual([a["name"] for a in d["files"]["apps"]], ["Dolphin", "Mine"], "hidden apps are not offered")
        self.assertEqual(d["files"]["current"], "org.kde.dolphin.desktop", "the first installed one in the list")
        self.assertEqual(d["browser"]["current"], "")

    def test_set_writes_every_type_and_keeps_the_rest(self):
        f = self.config / "mimeapps.list"
        f.write_text("[Added Associations]\ntext/plain=x.desktop;\n\n[Default Applications]\ntext/html=viewer.desktop;\nimage/png=y.desktop;\n\n[Removed Associations]\n")
        self.A.set_default("browser", "firefox.desktop", self.A.applications())
        text = f.read_text()
        self.assertIn("text/plain=x.desktop;", text)
        self.assertIn("image/png=y.desktop;", text)
        self.assertIn("text/html=firefox.desktop;", text)
        self.assertNotIn("viewer.desktop", text)
        group = self.A.read_group(f, "Default Applications")
        self.assertEqual(group["x-scheme-handler/https"], ["firefox.desktop"])
        self.assertIn("[Removed Associations]", text)
        self.assertEqual(self.A.read_group(f, "Removed Associations"), {})
        d = {x["kind"]: x for x in self.A.defaults(self.A.applications())}
        self.assertEqual(d["browser"]["current"], "firefox.desktop")

    def test_desktop_specific_file_follows(self):
        n = self.config / "niri-mimeapps.list"
        n.write_text("[Default Applications]\ninode/directory=mine.desktop;\n")
        self.A.set_default("files", "org.kde.dolphin.desktop", self.A.applications())
        self.assertEqual(self.A.read_group(n, "Default Applications")["inode/directory"], ["org.kde.dolphin.desktop"])
        self.assertEqual(self.A.default_for("inode/directory", self.A.applications()), "org.kde.dolphin.desktop")

    def test_new_file(self):
        self.A.set_default("files", "mine.desktop", self.A.applications())
        self.assertEqual((self.config / "mimeapps.list").read_text(), "[Default Applications]\ninode/directory=mine.desktop;\n")

    def test_unknown(self):
        with self.assertRaises(SystemExit):
            self.A.set_default("nope", "firefox.desktop", self.A.applications())
        with self.assertRaises(SystemExit):
            self.A.set_default("files", "nope.desktop", self.A.applications())


class Autostart(Base):
    def setUp(self):
        super().setUp()
        sysd, user = self.sysconf / "autostart", self.config / "autostart"
        desktop(sysd / "syncthing.desktop", Name="Syncthing", Exec="syncthing serve")
        desktop(sysd / "gnome-only.desktop", Name="G", Exec="g", OnlyShowIn="GNOME;")
        desktop(sysd / "not-niri.desktop", Name="N", Exec="n", NotShowIn="niri;")
        desktop(sysd / "lxpolkit.desktop", Name="LXPolkit", Exec="lxpolkit")
        desktop(sysd / "missing.desktop", Name="M", Exec="m", TryExec="/no/such/program")
        desktop(sysd / "off.desktop", Name="Off", Exec="off", X__GNOME__Autostart__enabled="false")
        desktop(sysd / "late.desktop", Name="Late", Exec="late %U", X__GNOME__Autostart__Delay="5")
        desktop(sysd / "hidden-by-user.desktop", Name="H", Exec="h")
        desktop(user / "hidden-by-user.desktop", Name="H", Exec="h", Hidden="true")
        desktop(user / "mine.desktop", Name="Mine", Exec="mine --tray")

    def test_list(self):
        rows = {r["id"]: r for r in self.A.autostart_list()}
        self.assertEqual(sorted(rows), ["hidden-by-user.desktop", "late.desktop", "lxpolkit.desktop", "mine.desktop", "off.desktop", "syncthing.desktop"])
        self.assertFalse(rows["hidden-by-user.desktop"]["enabled"])
        self.assertTrue(rows["hidden-by-user.desktop"]["user"] and rows["hidden-by-user.desktop"]["system"])
        self.assertFalse(rows["off.desktop"]["enabled"])
        self.assertEqual(rows["lxpolkit.desktop"]["managed"], "vitrum has its own password prompt")

    def test_run_starts_only_what_applies(self):
        started = {s["id"]: s["argv"] for s in self.A.autostart_run(dry=True)}
        self.assertEqual(sorted(started), ["late.desktop", "mine.desktop", "syncthing.desktop"])
        self.assertEqual(started["mine.desktop"], ["mine", "--tray"])
        self.assertEqual(started["late.desktop"], ["sh", "-c", 'sleep "$0"; exec "$@"', "5.0", "late"])

    def test_toggle_makes_a_user_copy(self):
        self.A.autostart_set("syncthing.desktop", False)
        self.assertTrue((self.config / "autostart/syncthing.desktop").exists())
        self.assertNotIn("syncthing.desktop", [s["id"] for s in self.A.autostart_run(dry=True)])
        self.A.autostart_set("syncthing.desktop", True)
        self.assertIn("syncthing.desktop", [s["id"] for s in self.A.autostart_run(dry=True)])
        self.A.autostart_set("off.desktop", True)
        self.assertIn("off.desktop", [s["id"] for s in self.A.autostart_run(dry=True)])
        # the system file is never touched
        self.assertNotIn("Hidden", (self.sysconf / "autostart/syncthing.desktop").read_text())

    def test_add_and_remove(self):
        desktop(self.sysdata / "applications/telegram.desktop", Name="Telegram", Exec="telegram -- %u")
        self.A.autostart_add("telegram.desktop", self.A.applications())
        self.assertIn("telegram.desktop", [s["id"] for s in self.A.autostart_run(dry=True)])
        self.A.autostart_remove("telegram.desktop")
        self.assertFalse((self.config / "autostart/telegram.desktop").exists())
        # a system entry can only be disabled
        self.A.autostart_remove("syncthing.desktop")
        rows = {r["id"]: r for r in self.A.autostart_list()}
        self.assertFalse(rows["syncthing.desktop"]["enabled"])

    def test_cli_list_is_json(self):
        import contextlib
        import io
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(self.A.main(["list"]), 0)
        d = json.loads(buf.getvalue())
        self.assertEqual(sorted(d), ["apps", "autostart", "defaults"])


if __name__ == "__main__":
    unittest.main()
