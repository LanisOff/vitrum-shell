"""The vitrum theme for Steam (tools/vitrum_theme/steam.py, tools/vitrum-steam-theme).

Everything runs against a temp HOME with a fake Steam and Millennium layout:
~/.steam/steam with steamui bundles and ubuntu12_32/64, a fake
/usr/lib/millennium (VITRUM_MILLENNIUM_LIB), and Millennium's config in
~/.config/millennium. No real Steam, package manager or network is touched.
"""
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import vitrum_theme as vt  # noqa: E402
from vitrum_theme import steam  # noqa: E402

THEME_SRC = ROOT / "assets" / "steam" / "vitrum"
ORIGINAL_STEAM_PID = steam.steam_pid      # Base patches the attribute; this is the real one
HELPER = ROOT / "tools" / "vitrum-steam-theme"

# A webpack bundle like Steam's: CSS-module objects mapping readable keys to hashes.
BUNDLE = (
    'var a={1:function(e){e.exports={OuterFrame:"_3abcdeFrame",ContentFrame:"_1contentXYZ",TopBar:"_2topbarQQ",'
    'TitleBar:"_9titlebarZ",Library:"_4libraryAA",BrowserWrapper:"_5browserBB",URLBar:"_6urlbarCC",'
    'URLBarText:"_7urltextDD",WindowControls:"_8windowEE"}},'
    '2:function(e){e.exports={GameListEntryContainer:"_1gleContainer",Container:"_2gleCont",Selected:"_3gleSel",'
    'HoverOverlay:"_4gleHover",GameListEntryName:"_5gleName",Running:"_6gleRun",Updating:"_7gleUpd",'
    'Uninstalled:"_8gleUn"}},'
    '3:function(e){e.exports={Toggle:"_1tog",ToggleRail:"_2rail",ToggleSwitch:"_3knob",On:"_4on",Disabled:"_5dis"}},'
    '4:function(e){e.exports={Toggle:"_6tog",ToggleRail:"_7rail",ToggleSwitch:"_8knob",On:"_9on",Off:"_0off"}},'
    '5:function(e){e.exports={narrowWidth:"500px","ItemFocusAnim-grey":"_1grey",PagedSettingsDialog_PageListItem:"_1pli",'
    'Active:"_2act",PageListItem_Icon:"_3icon"}}};'
)


def make_home(tmp):
    home = Path(tmp) / "home"
    steam_root = home / ".local" / "share" / "Steam"
    (steam_root / "steamui").mkdir(parents=True)
    (steam_root / "ubuntu12_32").mkdir()
    (steam_root / "ubuntu12_64").mkdir()
    (steam_root / "steamui" / "sp.js").write_text(BUNDLE)
    (home / ".steam").mkdir()
    (home / ".steam" / "steam").symlink_to(steam_root)
    lib = Path(tmp) / "usr-lib-millennium"
    env = {"HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"), "XDG_DATA_HOME": str(home / ".local/share"),
           "XDG_CACHE_HOME": str(home / ".cache"), "VITRUM_MILLENNIUM_LIB": str(lib),
           "VITRUM_STEAM_THEME_SRC": str(THEME_SRC)}
    return home, steam_root, lib, env


def fake_libs(lib):
    lib.mkdir(parents=True, exist_ok=True)
    for f in steam.LIB_FILES:
        (lib / f).write_bytes(b"\x7fELF")


def palette(accent="#f2b3e7"):
    return vt.with_accent2({
        "dark": {"bg": "#100c12", "surface": "#1c171e", "surfaceHigh": "#2a2330", "surfaceHighest": "#332b38",
                 "outline": "#4a404e", "text": "#ede0ea", "textDim": "#cfc2cc", "accent": accent,
                 "onAccent": "#3a0d36", "danger": "#ffb4ab", "warning": "#fdd663", "success": "#81c995"},
        "light": {"bg": "#fff7f9", "surface": "#fff7f9", "surfaceHigh": "#f3e5ef", "surfaceHighest": "#ede0ea",
                  "outline": "#cfc2cc", "text": "#211a20", "textDim": "#4e444c", "accent": "#7f4878",
                  "onAccent": "#ffffff", "danger": "#ba1a1a", "warning": "#9a5b00", "success": "#1e7a43"},
    }, {})


def settings(**theme):
    s, _ = vt.load_settings(Path("/nonexistent/settings.json"))
    s["steam"]["theme"].update(theme)
    return s


def no_steam(*a, **k):
    return subprocess.CompletedProcess(a[0] if a else [], 1, "", "")


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home, self.steam_root, self.lib, env = make_home(self.tmp.name)
        self.env = env
        p = mock.patch.dict(os.environ, env)
        p.start()
        self.addCleanup(p.stop)
        q = mock.patch.object(steam, "steam_pid", lambda run=None: None)
        q.start()
        self.addCleanup(q.stop)

    def tearDown(self):
        self.tmp.cleanup()

    def config(self):
        return json.loads(steam.config_file().read_text())


class Defaults(unittest.TestCase):
    def test_the_two_keys(self):
        d = json.loads((ROOT / "shell/data/settings.defaults.json").read_text())
        self.assertEqual(d["steam"]["theme"], {"enabled": True, "sync": True})

    def test_skin_json_is_millennium_format(self):
        skin = json.loads((THEME_SRC / "skin.json").read_text())
        self.assertEqual(skin["name"], "vitrum")
        self.assertIn("version", skin)
        self.assertFalse(skin["UseDefaultPatches"])
        for patch in skin["Patches"]:
            self.assertIn("MatchRegexString", patch)
            for f in patch["TargetCss"] + [patch.get("TargetJs", "live.js")]:
                self.assertTrue((THEME_SRC / f).is_file(), f)
            self.assertEqual(patch["TargetCss"][0], "colors.css")   # the variables come first

    def test_big_picture_is_left_alone(self):
        import re
        rx = json.loads((THEME_SRC / "skin.json").read_text())["Patches"][0]["MatchRegexString"]
        self.assertTrue(re.match(rx, "Steam"))
        self.assertTrue(re.match(rx, "Steam Settings"))
        self.assertFalse(re.match(rx, "Steam Big Picture Mode"))
        self.assertFalse(re.match(rx, "QuickAccess_uid0"))

    def test_no_capsules_no_bounce_no_m3_fill(self):
        for name in ("base.css", "steam.vcss", "friends.css"):
            text = (THEME_SRC / name).read_text()
            self.assertNotRegex(text, r"border-radius:\s*(9999|999|50%|1337)", name)
            self.assertNotIn("cubic-bezier(.34", text)          # overshoot
            self.assertNotIn("onAccent", text)
            self.assertNotRegex(text, r"color:\s*var\(--vt-bg\)", name)   # dark text on the tint

    def test_shipped_colors_define_every_variable(self):
        text = (THEME_SRC / "colors.css").read_text()
        for v in ("bg", "surface", "surface-high", "surface-highest", "text", "text-dim", "accent", "accent2",
                  "danger", "radius-tile", "radius-button", "radius-panel"):
            self.assertIn(f"--vt-{v}:", text)

    def test_shipped_colors_are_what_apply_writes_for_the_default(self):
        pal = json.loads((ROOT / "shell/data/palettes.json").read_text())["graphite"]
        want = steam.colors_css(steam.dark_roles(vt.with_accent2(pal, {})), "preset graphite (shipped default)")
        self.assertEqual((THEME_SRC / "colors.css").read_text(), want)

    def test_no_wallpaper_and_no_see_through_window(self):
        import re
        for name in ("colors.css", "base.css", "steam.vcss", "friends.css", "live.js"):
            text = (THEME_SRC / name).read_text()
            for gone in ("--vt-wall", "--vt-glass-opacity", "wall.jpg", "url("):
                self.assertNotIn(gone, text, f"{name}: {gone}")
            self.assertNotIn("backdrop-filter: blur", text, name)
        # The window's base layer is the palette's bg, solid.
        base = (THEME_SRC / "base.css").read_text()
        window = re.search(r"--vt-window:([^;]+);", base).group(1)
        self.assertTrue(window.strip().endswith("var(--vt-bg)"), window)
        self.assertIn("background: var(--vt-window) !important;", base)

    def test_lit_glass_for_on(self):
        base = (THEME_SRC / "base.css").read_text()
        vcss = (THEME_SRC / "steam.vcss").read_text()
        self.assertIn("--vt-lit: linear-gradient(180deg, rgba(255, 255, 255, .20)", base)    # frosted white
        rim = base.split("--vt-rim-lit:")[1].split(";")[0]
        self.assertIn("inset 0 0 0 1px rgba(255, 255, 255", rim)                              # the rim
        self.assertIn("inset 0 1px 0 rgba(255, 255, 255", rim)                                # the top light
        self.assertIn("rgba(var(--vt-glow-rgb)", rim)                                         # the accent glow
        self.assertIn("background: rgba(var(--vt-glow-rgb), .32) !important;", vcss)        # a switch that is on
        self.assertRegex(vcss, r"/Active\} @\{PagedSettingsDialog_PageListItem/PageListItem_Icon\} \{\s*color: var\(--vt-accent\)")

    def test_every_variable_used_is_defined(self):
        import re
        defined = set(re.findall(r"(--vt-[\w-]+)\s*:", (THEME_SRC / "colors.css").read_text()
                                 + (THEME_SRC / "base.css").read_text()))
        for name in ("base.css", "steam.vcss", "friends.css"):
            used = set(re.findall(r"var\((--vt-[\w-]+)", (THEME_SRC / name).read_text()))
            self.assertEqual(used - defined, set(), name)


class Motion(unittest.TestCase):
    """The theme's animations: damped, 150–400 ms, one-shot, all switched off
    by reduced motion, and every one of them defined."""

    FILES = ("base.css", "steam.vcss", "friends.css")

    def text(self, name):
        import re
        return re.sub(r"/\*.*?\*/", "", (THEME_SRC / name).read_text(), flags=re.S)

    def test_one_easing_and_no_overshoot(self):
        import re
        base = self.text("base.css")
        self.assertIn("--vt-ease: cubic-bezier(.2, .8, .2, 1);", base)
        for name in self.FILES:
            text = self.text(name)
            curves = re.findall(r"cubic-bezier\([^)]*\)", text)
            self.assertEqual(set(curves) - {"cubic-bezier(.2, .8, .2, 1)"}, set(), name)
            for word in ("infinite", "alternate", "ease-in-out", "OutBack", "bounce", "steps("):
                self.assertNotIn(word, text, f"{name}: {word}")

    def test_animations_go_through_the_reduced_motion_switch(self):
        import re
        for name in self.FILES:
            for value in re.findall(r"(?<![\w-])animation:\s*([^;]+);", self.text(name)):
                self.assertRegex(value.strip(), r"^(var\(--vt-a-[\w-]+\)|none)$", f"{name}: {value}")

    def test_reduced_motion_switches_every_animation_off(self):
        import re
        base = self.text("base.css")
        named = set(re.findall(r"(--vt-a-[\w-]+):", base.split("@media (prefers-reduced-motion")[0]))
        self.assertGreaterEqual(named, {"--vt-a-rise", "--vt-a-pop", "--vt-a-fade", "--vt-a-menu", "--vt-a-sweep"})
        reduced = base.split("@media (prefers-reduced-motion: reduce)")[1]
        for var in named:
            self.assertRegex(reduced, re.escape(var) + r":\s*none;", var)
        for var in ("--vt-dur-fast", "--vt-dur", "--vt-dur-slow"):
            self.assertRegex(reduced, re.escape(var) + r":\s*0ms;", var)

    def test_every_keyframe_used_is_defined_and_short(self):
        import re
        base = self.text("base.css")
        defined = set(re.findall(r"@keyframes ([\w-]+)", base))
        durations = dict(re.findall(r"--(vt-dur[\w-]*):\s*(\d+)ms;", base.split("@media (prefers-reduced-motion")[0]))
        for var, value in re.findall(r"(--vt-a-[\w-]+):\s*([^;]+);", base.split("@media (prefers-reduced-motion")[0]):
            name = value.split()[0]
            self.assertIn(name, defined, var)
            ms = re.search(r"var\(--(vt-dur[\w-]*)\)|(\d+)ms", value)
            ms = int(durations[ms.group(1)]) if ms.group(1) else int(ms.group(2))
            self.assertTrue(150 <= ms <= 400, f"{var}: {ms} ms")
        for name, value in durations.items():
            self.assertTrue(150 <= int(value) <= 400, f"{name}: {value} ms")

    def test_lit_glass_lights_up_once(self):
        vcss = self.text("steam.vcss")
        base = self.text("base.css")
        self.assertIn("--vt-sweep: linear-gradient(105deg", base)
        # The sweep needs its position free of !important to animate.
        self.assertNotRegex(base + vcss, r"background-position:[^;]*!important")
        self.assertNotRegex(base + vcss, r"background:\s*var\(--vt-sweep\)")
        # Lit glass that carries the sweep starts it.
        for block in (base + vcss).split("\n}"):
            if "background-image: var(--vt-sweep)" in block:
                self.assertIn("animation: var(--vt-a-sweep", block)

    def test_tiles_lift_without_tilt(self):
        vcss = self.text("steam.vcss")
        self.assertIn("transform: translateY(-2px) !important;", vcss)
        self.assertIn("box-shadow: var(--vt-shadow-lift) !important;", vcss)
        self.assertIn("perspective: none !important;", vcss)

    def test_menus_scale_from_098(self):
        base = self.text("base.css")
        self.assertRegex(base, r"@keyframes vt-menu \{\s*from \{ opacity: 0; transform: scale\(\.98\); \}")


class NavTabs(unittest.TestCase):
    """Store / Library / Community / the profile: one plate shape for all of
    them (Steam pads the first and last unevenly and tops the text), so the
    lit plate sits straight."""

    def block(self):
        vcss = (THEME_SRC / "steam.vcss").read_text()
        start = vcss.index("@{SuperNavMenu/SuperNavMenu},\n@{SuperNavMenu/SuperNavMenu}:first-child,\n"
                           "@{SuperNavMenu/SuperNavMenu}:last-child {")
        return vcss, vcss[start:vcss.index("\n}", start)]

    def test_every_tab_is_the_same_centred_plate(self):
        _, block = self.block()
        for decl in ("display: flex !important;", "align-items: center !important;", "height: 28px !important;",
                     "padding: 0 12px !important;", "border-radius: var(--vt-radius-button) !important;"):
            self.assertIn(decl, block)

    def test_the_selection_cross_fades(self):
        vcss, block = self.block()
        self.assertIn("transition: background-color 280ms var(--vt-ease), box-shadow 280ms var(--vt-ease)", block)
        # Same number of shadows in every state, so the rim interpolates.
        rest = block.split("box-shadow:")[1].split("!important")[0]
        sel = vcss.split("@{SuperNavMenu/SuperNavMenu}@{SuperNavMenu/Selected} {")[1].split("\n}")[0]
        lit = sel.split("box-shadow:")[1].split("!important")[0]
        count = lambda s: s.count("rgba(")
        self.assertEqual(count(rest), count(lit))
        self.assertIn("animation: var(--vt-a-sweep-one);", sel)


class Colours(unittest.TestCase):
    def test_colors_css(self):
        css = steam.colors_css(steam.dark_roles(palette()))
        self.assertIn("--vt-accent: #f2b3e7;", css)
        self.assertIn("--vt-accent-rgb: 242, 179, 231;", css)
        self.assertIn("--vt-bg: #100c12;", css)
        self.assertIn("--vt-surface-highest: #332b38;", css)
        self.assertIn("--vt-radius-tile: 12px;", css)
        self.assertIn("--vt-radius-button: 9px;", css)
        self.assertIn("--vt-radius-panel: 20px;", css)
        self.assertNotIn("opacity", css)
        self.assertNotIn("wall", css)

    def test_old_kept_colours_without_surface_highest(self):
        roles = {k: v for k, v in steam.dark_roles(palette()).items() if k != "surfaceHighest"}
        self.assertIn("--vt-surface-highest: #2a2330;", steam.colors_css(roles))

    def test_always_the_dark_scheme(self):
        roles = steam.dark_roles(palette())
        self.assertEqual(roles["text"], "#ede0ea")
        self.assertTrue(roles["accent2"].startswith("#"))

    def test_accent2_from_vitrum_maths(self):
        p = palette()
        self.assertEqual(steam.dark_roles(p)["accent2"], vt.accent2("#f2b3e7", -100, True))
        old = {"dark": {k: v for k, v in p["dark"].items() if k != "accent2"}}
        self.assertEqual(steam.dark_roles(old)["accent2"], vt.accent2("#f2b3e7", -100, True))

    def test_glow_is_kept_from_going_pastel(self):
        import colorsys
        css = steam.colors_css(steam.dark_roles(palette("#f8e8f6")))
        rgb = [int(x) / 255 for x in css.split("--vt-glow-rgb: ")[1].split(";")[0].split(",")]
        self.assertLessEqual(colorsys.rgb_to_hls(*rgb)[1], 0.665)



class Classes(unittest.TestCase):
    def test_parse_maps(self):
        maps = steam.parse_class_maps(BUNDLE)
        self.assertIn({"Toggle": "_1tog", "ToggleRail": "_2rail", "ToggleSwitch": "_3knob", "On": "_4on",
                       "Disabled": "_5dis"}, maps)
        quoted = [m for m in maps if "ItemFocusAnim-grey" in m][0]
        self.assertEqual(quoted["PagedSettingsDialog_PageListItem"], "_1pli")

    def test_render(self):
        maps = steam.parse_class_maps(BUNDLE)
        missing = set()
        css = steam.render_vcss(
            "/* c { } */\n@{GameListEntryContainer/Selected}@{GameListEntryContainer/Container}:hover,\n"
            "@{Nope/Gone} a { color: red; background: blue }\n"
            "@{Nope/Gone} { color: green; }\n"
            "@{ToggleRail/Toggle}@{ToggleRail/On} @{ToggleRail/ToggleRail}::before { display: none }\n"
            "@media (prefers-reduced-motion: reduce) { @{OuterFrame/TopBar} { transition: none } }\n",
            maps, missing)
        self.assertIn("._3gleSel._2gleCont:hover {", css)
        self.assertNotIn("Nope", css)
        self.assertNotIn("green", css)                       # a rule left with no selector is gone
        self.assertIn("color: red;", css)
        self.assertIn(":is(._1tog,._6tog):is(._4on,._9on) :is(._2rail,._7rail)::before", css)
        self.assertIn("@media (prefers-reduced-motion: reduce) {\n._2topbarQQ {", css)
        self.assertEqual(missing, {"@{Nope/Gone}"})

    def test_class_names_are_valid_identifiers(self):
        self.assertEqual(steam._ident("3abc"), "\\33 abc")
        self.assertEqual(steam._ident("_3abc"), "_3abc")
        self.assertEqual(steam._ident("-9x"), "\\-9x")

    def test_the_shipped_template_renders_against_the_fake(self):
        css = steam.render_vcss((THEME_SRC / "steam.vcss").read_text(), steam.parse_class_maps(BUNDLE))
        self.assertIn("._3gleSel._2gleCont", css)
        self.assertNotIn("@{", css)
        self.assertNotIn("\x00", css)

    def test_cache(self):
        with tempfile.TemporaryDirectory() as tmp:
            ui = Path(tmp) / "steamui"
            ui.mkdir()
            (ui / "sp.js").write_text(BUNDLE)
            first = steam.class_maps(ui, Path(tmp) / "cache")
            self.assertTrue((Path(tmp) / "cache" / "steam-classes.json").is_file())
            with mock.patch.object(steam, "parse_class_maps", side_effect=AssertionError("parsed again")):
                self.assertEqual(steam.class_maps(ui, Path(tmp) / "cache"), first)
            self.assertEqual(steam.class_maps(Path(tmp) / "none", Path(tmp) / "cache"), [])


class RecordComponent(Base):
    """An install from Settings marks the part, so vitrum-theme's sync follows."""

    def test_marks_the_part_in_the_installers_file(self):
        f = steam.data_home() / "vitrum" / "components.json"
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(json.dumps({"version": 2, "games": True, "steam_theme": False}))
        steam.record_component(True)
        self.assertEqual(json.loads(f.read_text()), {"version": 2, "games": True, "steam_theme": True})

    def test_never_makes_the_file(self):
        f = steam.data_home() / "vitrum" / "components.json"
        if f.exists():
            f.unlink()
        steam.record_component(True)
        self.assertFalse(f.exists())


class Config(Base):
    def test_enable_keeps_millennium_keys(self):
        steam.config_file().parent.mkdir(parents=True)
        steam.config_file().write_text(json.dumps({"general": {"injectCSS": True},
                                                   "themes": {"activeTheme": "default", "allowedStyles": True}}))
        self.assertTrue(steam.set_active(True))
        c = self.config()
        self.assertEqual(c["themes"], {"activeTheme": "vitrum", "allowedStyles": True})
        self.assertEqual(c["general"], {"injectCSS": True})
        self.assertFalse(steam.set_active(True))       # nothing to change

    def test_disable_goes_back_to_steam_only_from_vitrum(self):
        steam.config_file().parent.mkdir(parents=True)
        steam.config_file().write_text(json.dumps({"themes": {"activeTheme": "vitrum"}}))
        steam.set_active(False)
        self.assertEqual(self.config()["themes"]["activeTheme"], "default")
        steam.config_file().write_text(json.dumps({"themes": {"activeTheme": "Fluenty"}}))
        steam.set_active(False)
        self.assertEqual(self.config()["themes"]["activeTheme"], "Fluenty")

    def test_no_config_yet(self):
        steam.set_active(True)
        self.assertEqual(self.config(), {"themes": {"activeTheme": "vitrum"}})

    def test_broken_config_is_not_touched(self):
        steam.config_file().parent.mkdir(parents=True)
        steam.config_file().write_text("{nope")
        with self.assertRaises(steam.SteamThemeError):
            steam.set_active(True)
        self.assertEqual(steam.config_file().read_text(), "{nope")


class Apply(Base):
    def install(self):
        return steam.install_theme()

    def test_paths_follow_millennium(self):
        self.assertEqual(steam.theme_dir(), self.steam_root.resolve() / "millennium" / "themes" / "vitrum")
        self.assertEqual(steam.config_file(), self.home / ".config" / "millennium" / "config.json")

    def test_not_installed(self):
        with self.assertRaises(steam.SteamThemeError):
            steam.apply(settings(), palette(), run=no_steam)

    def test_apply_writes_the_theme_and_activates_it(self):
        d = self.install()
        self.assertTrue((d / "skin.json").is_file())
        changed = steam.apply(settings(), palette(), run=no_steam)
        css = (d / "colors.css").read_text()
        self.assertIn("--vt-accent: #f2b3e7;", css)
        self.assertIn("._3gleSel._2gleCont", (d / "steam.css").read_text())
        self.assertEqual(self.config()["themes"]["activeTheme"], "vitrum")
        self.assertIn(str(steam.config_file()), changed)
        self.assertEqual(steam.apply(settings(), palette(), run=no_steam), [])   # nothing new

    def test_disabled(self):
        self.install()
        steam.apply(settings(), palette(), run=no_steam)
        steam.apply(settings(enabled=False), palette(), run=no_steam)
        self.assertEqual(self.config()["themes"]["activeTheme"], "default")

    def test_sync_off_keeps_the_colours(self):
        d = self.install()
        steam.apply(settings(), palette("#f2b3e7"), run=no_steam)
        steam.apply(settings(), palette("#00ff00"), sync_colours=False, run=no_steam)
        self.assertIn("--vt-accent: #f2b3e7;", (d / "colors.css").read_text())
        steam.apply(settings(), palette("#00ff00"), run=no_steam)
        self.assertIn("--vt-accent: #00ff00;", (d / "colors.css").read_text())

    def test_vitrum_theme_runs_leave_a_theme_picked_in_millennium(self):
        self.install()
        steam.apply(settings(), palette(), enforce=False, run=no_steam)
        self.assertEqual(self.config()["themes"]["activeTheme"], "vitrum")
        steam.config_file().write_text(json.dumps({"themes": {"activeTheme": "Fluenty"}}))
        steam.apply(settings(), palette(), enforce=False, run=no_steam)
        self.assertEqual(self.config()["themes"]["activeTheme"], "Fluenty")
        steam.apply(settings(enabled=False), palette(), enforce=False, run=no_steam)   # a change of the setting counts
        steam.apply(settings(enabled=True), palette(), enforce=False, run=no_steam)
        self.assertEqual(self.config()["themes"]["activeTheme"], "vitrum")
        steam.config_file().write_text(json.dumps({"themes": {"activeTheme": "Fluenty"}}))
        steam.apply(settings(), palette(), enforce=True, run=no_steam)                 # the helper's apply
        self.assertEqual(self.config()["themes"]["activeTheme"], "vitrum")

    def test_steam_running_starts_the_watcher(self):
        self.install()
        spawned = []
        with mock.patch.object(steam, "steam_pid", lambda run=None: 4242):
            steam.apply(settings(), palette(), spawn=lambda: spawned.append(1))
        self.assertEqual(spawned, [1])
        state = json.loads((steam.theme_dir() / ".vitrum-state.json").read_text())
        self.assertTrue(state["pending"])
        steam.apply(settings(), palette(), spawn=lambda: spawned.append(2))     # Steam has quit now
        self.assertEqual(spawned, [1])
        self.assertFalse(json.loads((steam.theme_dir() / ".vitrum-state.json").read_text())["pending"])

    def test_the_wallpaper_is_not_used(self):
        wall = Path(self.tmp.name) / "wall.png"
        wall.write_bytes(b"not read")
        d = self.install()
        s = settings()
        s["wallpaper"]["path"] = str(wall)
        steam.apply(s, palette(), run=no_steam)
        self.assertFalse((d / "wall.jpg").exists())
        self.assertNotIn("wall", (d / "colors.css").read_text())

    def test_an_old_blurred_wallpaper_is_cleaned_up(self):
        d = self.install()
        (d / "wall.jpg").write_bytes(b"old")
        (d / ".vitrum-state.json").write_text(json.dumps({"wallUrl": "x", "wallStamp": "y"}))
        changed = steam.apply(settings(), palette(), run=no_steam)
        self.assertFalse((d / "wall.jpg").exists())
        self.assertIn(str(d / "wall.jpg"), changed)
        state = json.loads((d / ".vitrum-state.json").read_text())
        self.assertNotIn("wallUrl", state)
        self.assertNotIn("wallStamp", state)

    def test_install_keeps_generated_files_reinstall_replaces(self):
        d = self.install()
        steam.apply(settings(), palette(), run=no_steam)
        steam.install_theme()
        self.assertIn("#f2b3e7", (d / "colors.css").read_text())
        (d / "stray.css").write_text("x")
        steam.install_theme(replace=True)
        self.assertFalse((d / "stray.css").exists())
        self.assertEqual((d / "colors.css").read_text(), (THEME_SRC / "colors.css").read_text())

    def test_remove(self):
        self.install()
        steam.apply(settings(), palette(), run=no_steam)
        self.assertTrue(steam.remove_theme())
        self.assertFalse(steam.theme_dir().exists())
        self.assertEqual(self.config()["themes"]["activeTheme"], "default")
        self.assertFalse(steam.remove_theme())


class Sync(Base):
    def data(self, comps):
        d = Path(self.tmp.name) / "data"
        d.mkdir(exist_ok=True)
        if comps is not None:
            (d / "components.json").write_text(json.dumps(comps))
        return d

    def test_needs_the_component(self):
        steam.install_theme()
        for comps in (None, {"games": True}, {"steam_theme": False}):
            self.assertEqual(steam.sync(settings(), palette(), self.data(comps)), [])
        self.assertFalse(steam.config_file().exists())

    def test_needs_the_theme_installed(self):
        self.assertEqual(steam.sync(settings(), palette(), self.data({"steam_theme": True})), [])

    def test_writes_with_the_component(self):
        steam.install_theme()
        out = steam.sync(settings(), palette("#00ff00"), self.data({"steam_theme": True}))
        self.assertIn(str(steam.theme_dir() / "colors.css"), out)
        self.assertIn("--vt-accent: #00ff00;", (steam.theme_dir() / "colors.css").read_text())

    def test_sync_off_keeps_last_colours(self):
        steam.install_theme()
        data = self.data({"steam_theme": True})
        steam.sync(settings(), palette("#f2b3e7"), data)
        steam.sync(settings(sync=False), palette("#00ff00"), data)
        self.assertIn("#f2b3e7", (steam.theme_dir() / "colors.css").read_text())


class Status(Base):
    def test_status(self):
        s = steam.status()
        self.assertEqual(s, {"millennium": False, "installed": False, "active": False, "steamRunning": False,
                             "themeDir": str(steam.theme_dir())})
        fake_libs(self.lib)
        steam.link_hooks()
        steam.install_theme()
        steam.set_active(True)
        s = steam.status()
        self.assertTrue(s["millennium"] and s["installed"] and s["active"])

    def test_libraries_without_links_are_not_enough(self):
        fake_libs(self.lib)
        self.assertFalse(steam.millennium_found())

    def test_steam_pid(self):
        out = subprocess.CompletedProcess([], 0, "1234\n", "")
        self.assertEqual(ORIGINAL_STEAM_PID(lambda *a, **k: out), 1234)
        self.assertIsNone(ORIGINAL_STEAM_PID(no_steam))


class Watch(Base):
    def test_puts_the_choice_back_until_steam_restarts(self):
        steam.install_theme()
        steam.apply(settings(), palette(), run=no_steam)
        pids = iter([100, 100, 100, 200])
        events = []

        def sleep(_):
            # Steam quitting: Millennium writes its own (old) copy back.
            if not events:
                steam.config_file().write_text(json.dumps({"themes": {"activeTheme": "default"}}))
            events.append(1)
        with mock.patch.object(steam, "steam_pid", lambda run=None: next(pids)):
            why = steam.watch(sleep=sleep)
        self.assertEqual(why, "restarted")
        self.assertEqual(self.config()["themes"]["activeTheme"], "vitrum")

    def test_ends_when_steam_is_gone(self):
        steam.install_theme()
        steam.apply(settings(), palette(), run=no_steam)
        self.assertEqual(steam.watch(sleep=lambda _: None), "quit")


class Millennium(Base):
    def run_recorder(self, handlers=None):
        calls = []

        def run(cmd, **kw):
            calls.append(list(cmd))
            for match, fn in (handlers or {}).items():
                if match in cmd:
                    return fn(cmd)
            return subprocess.CompletedProcess(cmd, 0, "", "")
        return run, calls

    def linux(self):
        p = mock.patch.multiple(steam.platform, system=lambda: "Linux", machine=lambda: "x86_64")
        p.start()
        self.addCleanup(p.stop)

    def test_present(self):
        fake_libs(self.lib)
        steam.link_hooks()
        run, calls = self.run_recorder()
        self.assertEqual(steam.install_millennium(run=run, which=lambda c: None), "present")
        self.assertEqual(calls, [])

    def test_present_but_not_linked(self):
        fake_libs(self.lib)
        self.assertEqual(steam.install_millennium(run=self.run_recorder()[0], which=lambda c: None), "linked")
        self.assertTrue(steam.hooked())
        link = self.steam_root / "ubuntu12_32" / "libXtst.so.6"
        self.assertEqual(os.readlink(link), str(self.lib / "libmillennium_bootstrap_x86.so"))

    def test_arch_without_a_terminal(self):
        self.linux()
        which = {"pacman": "/usr/bin/pacman", "paru": "/usr/bin/paru"}.get
        with self.assertRaises(steam.SteamThemeError) as e:
            steam.install_millennium(interactive=False, run=self.run_recorder()[0], which=which)
        self.assertIn("in a terminal", str(e.exception))

    def test_arch_without_an_aur_helper(self):
        self.linux()
        with self.assertRaises(steam.SteamThemeError) as e:
            steam.install_millennium(interactive=True, run=self.run_recorder()[0],
                                     which={"pacman": "/usr/bin/pacman"}.get)
        self.assertIn("paru or yay", str(e.exception))

    def test_arch_from_the_aur(self):
        self.linux()
        run, calls = self.run_recorder({"millennium": lambda cmd: (fake_libs(self.lib),
                                                                   subprocess.CompletedProcess(cmd, 0))[1]})
        which = {"pacman": "/usr/bin/pacman", "yay": "/usr/bin/yay"}.get
        self.assertEqual(steam.install_millennium(interactive=True, run=run, which=which), "aur")
        self.assertEqual(calls, [["yay", "-S", "--needed", "millennium"]])
        self.assertTrue(steam.millennium_found())
        calls.clear()
        steam.install_millennium(reinstall=True, interactive=True, yes=True, run=run, which=which)
        self.assertEqual(calls, [["yay", "-S", "--noconfirm", "millennium"]])

    def tarball(self, members=None):
        buf = io.BytesIO()
        with tarfile.open(fileobj=buf, mode="w:gz") as tar:
            for name, data in (members or {f"./usr/lib/millennium/{f}": b"\x7fELF" for f in steam.LIB_FILES}).items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
        path = Path(self.tmp.name) / "release.tar.gz"
        path.write_bytes(buf.getvalue())
        return path, steam._sha256(path)

    def release_run(self, tar):
        def curl(cmd):
            shutil.copy(tar, cmd[cmd.index("-o") + 1])
            return subprocess.CompletedProcess(cmd, 0)

        def install(cmd):
            args = cmd[cmd.index("install") + 1:]
            if args[0] == "-d":
                Path(args[-1]).mkdir(parents=True, exist_ok=True)
            else:
                shutil.copy(args[-2], args[-1])
            return subprocess.CompletedProcess(cmd, 0)
        return self.run_recorder({"curl": curl, "install": install})

    def test_other_distributions_get_the_pinned_release(self):
        self.linux()
        tar, sha = self.tarball()
        run, calls = self.release_run(tar)
        which = {"curl": "/usr/bin/curl", "sudo": "/usr/bin/sudo"}.get
        how = steam.install_millennium(interactive=True, run=run, which=which,
                                       release={"version": "t", "url": "https://example.invalid/m.tar.gz", "sha256": sha})
        self.assertEqual(how, "release")
        self.assertTrue(all((self.lib / f).is_file() for f in steam.LIB_FILES))
        self.assertTrue(steam.millennium_found())
        self.assertTrue((self.steam_root / "ubuntu12_64" / "libmillennium_hhx64.so").is_symlink())
        self.assertTrue(any(c[:2] == ["sudo", "install"] for c in calls))

    def test_a_wrong_checksum_installs_nothing(self):
        self.linux()
        tar, _ = self.tarball()
        run, calls = self.release_run(tar)
        with self.assertRaises(steam.SteamThemeError) as e:
            steam.install_millennium(interactive=True, run=run, which={"curl": "c", "sudo": "s"}.get,
                                     release={"version": "t", "url": "u", "sha256": "0" * 64})
        self.assertIn("checksum", str(e.exception))
        self.assertFalse(self.lib.exists())
        self.assertFalse(any("install" in c for c in calls))

    def test_an_unexpected_file_installs_nothing(self):
        self.linux()
        tar, sha = self.tarball({"./usr/lib/millennium/libmillennium_x86.so": b"x", "./etc/evil": b"x"})
        run, _ = self.release_run(tar)
        with self.assertRaises(steam.SteamThemeError) as e:
            steam.install_millennium(interactive=True, run=run, which={"curl": "c", "sudo": "s"}.get,
                                     release={"version": "t", "url": "u", "sha256": sha})
        self.assertIn("unexpected", str(e.exception))
        self.assertFalse(self.lib.exists())

    def test_no_password_without_a_terminal(self):
        self.linux()
        run, _ = self.run_recorder({"-n": lambda cmd: subprocess.CompletedProcess(cmd, 1)})
        with self.assertRaises(steam.SteamThemeError) as e:
            steam.install_millennium(interactive=False, run=run, which={"curl": "c", "sudo": "s"}.get)
        self.assertIn("password", str(e.exception))

    def test_the_pin(self):
        self.assertRegex(steam.RELEASE["sha256"], r"^[0-9a-f]{64}$")
        self.assertIn(f"v{steam.RELEASE['version']}/millennium-v{steam.RELEASE['version']}-linux-x86_64.tar.gz",
                      steam.RELEASE["url"])

    def test_not_linux(self):
        with mock.patch.multiple(steam.platform, system=lambda: "Darwin", machine=lambda: "arm64"):
            with self.assertRaises(steam.SteamThemeError):
                steam.install_millennium(run=self.run_recorder()[0], which=lambda c: None)


class Helper(unittest.TestCase):
    """The command itself, with PATH stubs (pgrep says Steam is not running)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home, self.steam_root, self.lib, env = make_home(self.tmp.name)
        stubs = Path(self.tmp.name) / "stubs"
        stubs.mkdir()
        for name, body in {"pgrep": "exit 1", "matugen": "exit 1", "gsettings": "exit 0"}.items():
            (stubs / name).write_text(f"#!/bin/sh\n{body}\n")
            (stubs / name).chmod(0o755)
        self.env = {**os.environ, **env, "PATH": f"{stubs}:/usr/bin:/bin",
                    "VITRUM_DATA": str(ROOT / "shell" / "data")}
        pal = self.home / ".local/share/vitrum/palette.json"
        pal.parent.mkdir(parents=True)
        pal.write_text(json.dumps({"source": "wallpaper", "palette": palette()}))

    def tearDown(self):
        self.tmp.cleanup()

    def run_helper(self, *args):
        return subprocess.run([sys.executable, str(HELPER), *args], env=self.env, capture_output=True, text=True,
                              stdin=subprocess.DEVNULL)

    def test_status(self):
        r = self.run_helper("status")
        self.assertEqual(r.returncode, 0, r.stderr)
        s = json.loads(r.stdout)
        self.assertEqual(set(s), {"millennium", "installed", "active", "steamRunning", "themeDir"})
        self.assertFalse(s["installed"])
        self.assertEqual(r.stdout.count("\n"), 1)

    def test_apply_without_the_theme_fails_with_a_message(self):
        r = self.run_helper("apply")
        self.assertEqual(r.returncode, 1)
        self.assertIn("not installed", r.stderr)

    def test_install_apply_remove(self):
        fake_libs(self.lib)
        r = self.run_helper("install")
        self.assertEqual(r.returncode, 0, r.stderr)
        tdir = self.steam_root.resolve() / "millennium" / "themes" / "vitrum"
        self.assertTrue((tdir / "skin.json").is_file())
        self.assertIn("--vt-accent: #f2b3e7;", (tdir / "colors.css").read_text())
        cfg = json.loads((self.home / ".config/millennium/config.json").read_text())
        self.assertEqual(cfg["themes"]["activeTheme"], "vitrum")
        s = json.loads(self.run_helper("status").stdout)
        self.assertEqual((s["millennium"], s["installed"], s["active"], s["steamRunning"]), (True, True, True, False))
        # Settings: off.
        (self.home / ".config/vitrum").mkdir(parents=True)
        (self.home / ".config/vitrum/settings.json").write_text(
            json.dumps({"steam": {"theme": {"enabled": False}}}))
        self.assertEqual(self.run_helper("apply").returncode, 0)
        self.assertNotIn("opacity", (tdir / "colors.css").read_text())
        cfg = json.loads((self.home / ".config/millennium/config.json").read_text())
        self.assertEqual(cfg["themes"]["activeTheme"], "default")
        r = self.run_helper("remove")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(tdir.exists())
        self.assertTrue((self.lib / "libmillennium_x86.so").is_file())     # Millennium stays

    def test_install_without_steam(self):
        shutil.rmtree(self.home / ".steam")
        shutil.rmtree(self.steam_root)
        r = self.run_helper("install")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Steam is not installed", r.stderr)


if __name__ == "__main__":
    unittest.main()
