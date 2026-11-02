"""fcitx5's side of the input_method component (tools/vitrum_theme/fcitx.py).

Everything runs in a temp HOME; fcitx5, gdbus and niri are stubbed.
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from vitrum_theme import fcitx, niri_input  # noqa: E402

ROLES = {"bg": "#101114", "surface": "#16181c", "surfaceHigh": "#20232a", "text": "#e6e6ea", "textDim": "#a0a0a8",
         "accent": "#7aa2f7", "accent2": "#f7a27a"}
PALETTE = {"dark": ROLES, "light": dict(ROLES, surface="#f4f4f6", text="#16181c", textDim="#50505a")}


def no_fcitx(*a, **k):
    return subprocess.CompletedProcess(a[0], 1)


class Home(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.cfg, self.data = root / "config", root / "share"
        self.state = self.data / "vitrum"
        self.state.mkdir(parents=True)
        env = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.cfg), "XDG_DATA_HOME": str(self.data)})
        env.start()
        self.addCleanup(env.stop)

    def on(self, value=True):
        (self.state / "components.json").write_text(json.dumps({"version": 2, "input_method": value}))

    def sync(self, layouts, run=no_fcitx, **k):
        return fcitx.sync({"keyboard": {"layouts": layouts}}, PALETTE, "dark", self.state, run=run, **k)


class Names(unittest.TestCase):
    def test_the_engines_and_the_keymaps(self):
        self.assertEqual(fcitx.im_name("us"), "keyboard-us")
        self.assertEqual(fcitx.im_name("de", "nodeadkeys"), "keyboard-de-nodeadkeys")
        self.assertEqual(fcitx.im_name("jp"), "mozc")
        self.assertEqual(fcitx.im_name("kr"), "hangul")
        self.assertEqual(fcitx.im_name("cn"), "pinyin")

    def test_a_variant_stays_a_keymap(self):
        self.assertEqual(fcitx.im_name("jp", "kana"), "keyboard-jp-kana")

    def test_the_javascript_twin_agrees(self):
        src = (ROOT / "shell/lib/keyboard.js").read_text(encoding="utf-8")
        for layout, engine in fcitx.ENGINES.items():
            self.assertIn(f'{layout}: "{engine}"', src)

    def test_the_base_is_the_first_keymap(self):
        self.assertEqual(fcitx.base_layout([("jp", ""), ("ru", ""), ("us", "")]), ("ru", ""))
        self.assertEqual(fcitx.base_layout([("jp", ""), ("kr", "")]), ("us", ""))

    def test_the_list_starts_with_the_base(self):
        self.assertEqual(fcitx.input_methods([("us", ""), ("ru", ""), ("jp", "")]), ["keyboard-us", "keyboard-ru", "mozc"])
        self.assertEqual(fcitx.input_methods([("jp", ""), ("ru", "")]), ["keyboard-ru", "mozc"])
        self.assertEqual(fcitx.input_methods([("jp", "")]), ["keyboard-us", "mozc"])

    def test_all_five_fit(self):
        s = {"keyboard": {"layouts": ["us", "ru", "jp", "kr", "cn"]}}
        self.assertEqual(fcitx.input_methods(fcitx.entries(s)),
                         ["keyboard-us", "keyboard-ru", "mozc", "hangul", "pinyin"])

    def test_config_kdl_until_settings_changes_them(self):
        pairs = fcitx.entries({}, {"layout": "us,ru,jp", "variant": ",phonetic,"})
        self.assertEqual(pairs, [("us", ""), ("ru", "phonetic"), ("jp", "")])

    def test_junk_is_dropped(self):
        self.assertEqual(fcitx.entries({"keyboard": {"layouts": ["us", 'x"; spawn', 3, "us"]}}), [("us", "")])


class Profile(unittest.TestCase):
    def test_the_format_fcitx5_reads(self):
        t = fcitx.profile_text(["keyboard-us", "mozc"], "us")
        self.assertIn("[Groups/0]\nName=Default\nDefault Layout=us\nDefaultIM=keyboard-us\n", t)
        self.assertIn("[Groups/0/Items/1]\nName=mozc\nLayout=\n", t)
        self.assertIn("[GroupOrder]\n0=Default\n", t)

    def test_round_trip(self):
        self.assertEqual(fcitx.parse_profile(fcitx.profile_text(["keyboard-ru", "pinyin"], "ru")),
                         (["keyboard-ru", "pinyin"], "ru"))

    def test_as_fcitx5_saves_it(self):
        saved = ("[Groups/0]\n# Group Name\nName=Default\n# Layout\nDefault Layout=us\n# Default Input Method\n"
                 "DefaultIM=mozc\n\n[Groups/0/Items/0]\n# Name\nName=keyboard-us\n# Layout\nLayout=\n\n"
                 "[Groups/0/Items/1]\n# Name\nName=mozc\n# Layout\nLayout=\n\n[GroupOrder]\n0=Default\n")
        self.assertEqual(fcitx.parse_profile(saved), (["keyboard-us", "mozc"], "us"))


class Ini(unittest.TestCase):
    def test_other_keys_stay(self):
        out = fcitx.merge_ini("[Behavior]\nActiveByDefault=True\nOther=1\n\n[Mine]\na=b\n", {"Behavior": {"ActiveByDefault": "False"}})
        self.assertIn("ActiveByDefault=False\nOther=1\n", out)
        self.assertIn("[Mine]\na=b\n", out)

    def test_a_list_is_replaced_whole(self):
        out = fcitx.merge_ini("[Hotkey/TriggerKeys]\n0=Control+space\n1=A\n2=B\n", {"Hotkey/TriggerKeys": {"0": "Hangul"}})
        self.assertEqual(out, "[Hotkey/TriggerKeys]\n0=Hangul\n")

    def test_a_list_is_emptied(self):
        out = fcitx.merge_ini("[Hotkey/AltTriggerKeys]\n0=Shift_L\n", {"Hotkey/AltTriggerKeys": {}})
        self.assertEqual(out, "[Hotkey/AltTriggerKeys]\n")

    def test_top_level_keys(self):
        out = fcitx.merge_ini("Theme=default\nFont=x\n[Sub]\nk=v\n", {"": {"Theme": "vitrum", "New": "1"}})
        self.assertEqual(out, "Theme=vitrum\nFont=x\nNew=1\n[Sub]\nk=v\n")

    def test_it_settles(self):
        for ours in (fcitx.config_sections(True), fcitx.config_sections(False), fcitx.classicui_sections({})):
            once = fcitx.merge_ini("", ours)
            self.assertEqual(fcitx.merge_ini(once, ours), once)

    def test_alt_shift_is_niris_or_fcitx5s_never_both(self):
        self.assertEqual(fcitx.config_sections(True)["Hotkey/EnumerateForwardKeys"], {})
        self.assertEqual(fcitx.config_sections(False)["Hotkey/EnumerateForwardKeys"],
                         {"0": "Alt+Shift_L", "1": "Shift+Alt_L"})

    def test_one_state_and_no_popup_of_its_own(self):
        b = fcitx.config_sections(True)["Behavior"]
        self.assertEqual(b["ShareInputState"], "All")
        self.assertEqual(b["ShowInputMethodInformation"], "False")
        self.assertEqual(b["AllowInputMethodForPassword"], "False")


class Niri(unittest.TestCase):
    S = {"keyboard": {"layouts": ["us", "ru", "jp"]}}
    X = {"options": "grp:alt_shift_toggle,compose:ralt"}

    def test_without_the_component_nothing_changes(self):
        k = niri_input.input_kdl(self.S, self.X)
        self.assertIn('layout "us,ru,jp"', k)
        self.assertIn('options "grp:alt_shift_toggle,compose:ralt"', k)
        self.assertNotIn("environment", k)
        self.assertNotIn("binds", k)

    def test_one_base_layout_and_no_group_switch(self):
        k = niri_input.input_kdl(self.S, self.X, True)
        self.assertIn('layout "us"\n', k)
        self.assertIn('options "compose:ralt"', k)

    def test_nothing_left_in_the_options(self):
        k = niri_input.input_kdl(self.S, {"options": "grp:alt_shift_toggle"}, True)
        self.assertNotIn("options", k)

    def test_config_kdls_layouts_too(self):
        k = niri_input.input_kdl({}, {"layout": "us,ru,jp", "options": "grp:alt_shift_toggle"}, True)
        self.assertIn('layout "us"\n', k)

    def test_the_environment(self):
        k = niri_input.input_kdl(self.S, self.X, True)
        self.assertIn('XMODIFIERS "@im=fcitx"', k)
        self.assertIn('QT_IM_MODULES "wayland;fcitx;ibus"', k)
        self.assertIn('SDL_IM_MODULE "fcitx"', k)
        self.assertNotIn("GTK_IM_MODULE", k)

    def test_the_hotkey_only_where_niri_takes_it(self):
        self.assertNotIn("binds", niri_input.input_kdl(self.S, self.X, True, False))
        k = niri_input.input_kdl(self.S, self.X, True, True)
        self.assertIn('Alt+Shift allow-when-locked=true', k)
        self.assertIn('release { spawn "vitrum-im" "next"; }', k)

    def test_the_probe(self):
        ran = []
        def run(cmd, **k):
            ran.append(Path(cmd[3]).read_text())
            return subprocess.CompletedProcess(cmd, 0)
        self.assertTrue(fcitx.niri_takes_hotkey("/x/niri", run))
        self.assertIn("Alt+Shift", ran[0])
        self.assertFalse(fcitx.niri_takes_hotkey("/x/niri", lambda *a, **k: subprocess.CompletedProcess(a[0], 1)))
        def gone(*a, **k):
            raise OSError
        self.assertFalse(fcitx.niri_takes_hotkey("/x/niri", gone))


class Theme(unittest.TestCase):
    def test_lit_glass_not_a_solid_accent(self):
        svg = fcitx.highlight_svg(ROLES, True, 9)
        self.assertIn('rx="9"', svg)
        self.assertIn('fill="#ffffff"', svg)
        self.assertIn('stop-color="#7aa2f7"', svg)
        self.assertNotIn(f'fill="{ROLES["accent"]}"', svg)

    def test_text_on_tint_stays_text(self):
        conf = fcitx.theme_conf(ROLES, 12, 9)
        self.assertIn("HighlightCandidateColor=#e6e6eaff", conf)
        self.assertIn("NormalColor=#e6e6eaff", conf)

    def test_the_corners_survive_scaling(self):
        conf = fcitx.theme_conf(ROLES, 12, 9)
        self.assertIn("[InputPanel/Background/Margin]\nLeft=16\n", conf)
        self.assertIn("[InputPanel/Highlight/Margin]\nLeft=12\n", conf)

    def test_density_scales_the_radius(self):
        files = fcitx.theme_files(ROLES, True, {"density": "comfortable"})
        self.assertIn('rx="14"', files["panel.svg"])   # 12 × 1.2
        self.assertIn('rx="11"', files["highlight.svg"])

    def test_light_and_dark_differ(self):
        self.assertNotEqual(fcitx.panel_svg(PALETTE["dark"], True, 12), fcitx.panel_svg(PALETTE["light"], False, 12))


class Flags(unittest.TestCase):
    def test_text_input_v3(self):
        block = fcitx.flags_block()
        self.assertIn("--enable-wayland-ime\n", block)
        self.assertIn("--wayland-text-input-version=3\n", block)

    def test_yours_stay(self):
        t = fcitx.with_flags("--ozone-platform=wayland\n")
        self.assertTrue(t.startswith("--ozone-platform=wayland\n# >>> vitrum"))
        self.assertEqual(fcitx.with_flags(t), t)
        self.assertEqual(fcitx.with_flags(t, False), "--ozone-platform=wayland\n")

    def test_only_for_apps_that_are_there(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d)
            fcitx.sync_flags(home, lambda c: c == "vesktop")
            self.assertEqual(sorted(p.name for p in home.iterdir()), ["electron-flags.conf", "vesktop-flags.conf"])
            self.assertEqual(fcitx.sync_flags(home, lambda c: c == "vesktop"), [])
            fcitx.sync_flags(home, on=False)
            self.assertEqual(list(home.iterdir()), [])


class Sync(Home):
    def test_nothing_without_the_component(self):
        self.assertEqual(self.sync(["us", "jp"]), [])
        self.on(False)
        self.assertEqual(self.sync(["us", "jp"]), [])
        self.assertFalse((self.cfg / "fcitx5").exists())

    def test_the_files(self):
        self.on()
        self.sync(["us", "ru", "jp"], niri_hotkey=True)
        home = self.cfg / "fcitx5"
        self.assertEqual(fcitx.parse_profile((home / "profile").read_text()), (["keyboard-us", "keyboard-ru", "mozc"], "us"))
        self.assertIn("ShareInputState=All", (home / "config").read_text())
        self.assertIn("Theme=vitrum", (home / "conf/classicui.conf").read_text())
        themes = self.data / "fcitx5/themes/vitrum"
        self.assertEqual(sorted(p.name for p in themes.iterdir()), ["highlight.svg", "panel.svg", "theme.conf"])
        self.assertTrue((self.state / "fcitx-managed").exists())
        self.assertIn("Hidden=true", (self.cfg / "autostart/org.fcitx.Fcitx5.desktop").read_text())

    def test_a_second_run_writes_nothing(self):
        self.on()
        self.sync(["us", "jp"])
        self.assertEqual(self.sync(["us", "jp"]), [])

    def test_fcitx5s_own_rewrite_is_left_alone(self):
        self.on()
        self.sync(["us", "jp"])
        profile = self.cfg / "fcitx5/profile"
        saved = profile.read_text().replace("DefaultIM=keyboard-us", "DefaultIM=mozc").replace("Name=Default", "# Group Name\nName=Default")
        profile.write_text(saved)
        self.assertEqual(self.sync(["us", "jp"]), [])
        self.assertEqual(profile.read_text(), saved)

    def test_a_changed_list_is_rewritten_and_sent_to_the_daemon(self):
        self.on()
        self.sync(["us", "jp"])
        calls = []
        def run(cmd, **k):
            calls.append(cmd)
            return subprocess.CompletedProcess(cmd, 0)
        self.sync(["us", "ru", "jp"], run=run)
        group = [c for c in calls if "org.fcitx.Fcitx.Controller1.SetInputMethodGroupInfo" in c]
        self.assertEqual(len(group), 1)
        self.assertEqual(group[0][-3:], ["Default", "us", "[('keyboard-us', ''), ('keyboard-ru', ''), ('mozc', '')]"])

    def test_a_new_colour_reloads_the_theme_only(self):
        self.on()
        self.sync(["us", "jp"])
        calls = []
        def run(cmd, **k):
            calls.append(cmd)
            return subprocess.CompletedProcess(cmd, 0)
        fcitx.sync({"keyboard": {"layouts": ["us", "jp"]}}, {"dark": dict(ROLES, accent="#ff0000")}, "dark", self.state, run=run)
        names = [c[-2:] for c in calls if c[0] == "gdbus"]
        self.assertEqual(names, [["org.fcitx.Fcitx.Controller1.ReloadAddonConfig", "classicui"]])

    def test_a_users_file_is_kept_once(self):
        self.on()
        home = self.cfg / "fcitx5"
        home.mkdir(parents=True)
        (home / "profile").write_text("[Groups/0]\nName=Mine\n")
        (home / "config").write_text("[Behavior]\nOwn=1\n")
        self.sync(["us", "jp"])
        self.assertEqual((home / "profile.pre-vitrum").read_text(), "[Groups/0]\nName=Mine\n")
        self.assertEqual((home / "config.pre-vitrum").read_text(), "[Behavior]\nOwn=1\n")
        self.assertIn("Own=1", (home / "config").read_text())
        self.sync(["us", "ru", "jp"])
        self.assertEqual((home / "profile.pre-vitrum").read_text(), "[Groups/0]\nName=Mine\n")

    def test_no_layouts_writes_nothing(self):
        self.on()
        self.assertEqual(self.sync([]), [])


class Applies(Home):
    def kdl(self, text="input { }\n"):
        path = Path(self.tmp.name) / "input.kdl"
        path.write_text(text)
        return path

    def test_off_is_off(self):
        self.assertFalse(fcitx.applies(self.state, self.kdl(), True, {}))

    def test_before_the_compositor_starts(self):
        self.on()
        self.assertTrue(fcitx.applies(self.state, self.kdl(), env={}))

    def test_a_session_that_has_it(self):
        self.on()
        self.assertTrue(fcitx.applies(self.state, self.kdl(), env={"NIRI_SOCKET": "s", "XMODIFIERS": "@im=fcitx"}))

    def test_a_running_session_without_it_keeps_its_layouts(self):
        self.on()
        self.assertFalse(fcitx.applies(self.state, self.kdl(), env={"NIRI_SOCKET": "s"}))

    def test_the_installer_may_all_the_same(self):
        self.on()
        self.assertTrue(fcitx.applies(self.state, self.kdl(), True, {"NIRI_SOCKET": "s"}))

    def test_and_later_renders_do_not_undo_it(self):
        self.on()
        self.assertTrue(fcitx.applies(self.state, self.kdl('environment {\n    XMODIFIERS "@im=fcitx"\n}\n'), env={"NIRI_SOCKET": "s"}))


class Cli(Home):
    def run_cli(self):
        root = Path(self.tmp.name)
        (root / "settings.json").write_text(json.dumps({"palette": {"source": "preset"}, "keyboard": {"layouts": ["us", "ru", "jp"]}}))
        args = [sys.executable, str(ROOT / "tools/vitrum-theme"), "--settings", str(root / "settings.json"),
                "--out-palette", str(self.state / "palette.json"), "--niri-dir", str(root / "gen"), "--no-color-scheme",
                "--templates", str(root / "none")]
        env = dict(os.environ, PATH="/usr/bin:/bin")
        env.pop("NIRI_SOCKET", None)
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def test_off_is_the_plain_path(self):
        r = self.run_cli()
        self.assertEqual(r.returncode, 0, r.stderr)
        k = (Path(self.tmp.name) / "gen/input.kdl").read_text()
        self.assertIn('layout "us,ru,jp"', k)
        self.assertNotIn("environment", k)
        self.assertFalse((self.cfg / "fcitx5").exists())

    def test_on_moves_the_layouts_to_fcitx5(self):
        self.on()
        r = self.run_cli()
        self.assertEqual(r.returncode, 0, r.stderr)
        k = (Path(self.tmp.name) / "gen/input.kdl").read_text()
        self.assertIn('layout "us"\n', k)
        self.assertIn("XMODIFIERS", k)
        self.assertEqual(fcitx.parse_profile((self.cfg / "fcitx5/profile").read_text())[0],
                         ["keyboard-us", "keyboard-ru", "mozc"])


if __name__ == "__main__":
    unittest.main()
