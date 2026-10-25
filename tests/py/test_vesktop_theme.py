"""The vitrum theme for Vesktop (tools/vitrum_theme/vesktop.py, tools/vitrum-vesktop-theme).

Everything runs against a temp HOME with a fake Vesktop data dir
(~/.config/vesktop with Vencord's settings/settings.json and themes/). No real
Vesktop, Discord or network is touched; pgrep is stubbed or patched.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import vitrum_theme as vt  # noqa: E402
from vitrum_theme import vesktop  # noqa: E402

THEME_SRC = ROOT / "assets" / "vesktop" / "vitrum.theme.css"
HELPER = ROOT / "tools" / "vitrum-vesktop-theme"
VITRUM_THEME = ROOT / "tools" / "vitrum-theme"
ORIGINAL_PID = vesktop.vesktop_pid

# Vencord's settings as Vesktop 1.6.8 wrote them on a real install (keys and
# order; plugin settings cut down).
VENCORD = {
    "autoUpdate": True, "autoUpdateNotification": True, "useQuickCss": True, "themeLinks": [],
    "eagerPatches": False, "enabledThemes": [], "enableReactDevtools": False, "frameless": False,
    "transparent": False, "winCtrlQ": False, "windowsMaterial": None, "disableMinSize": False,
    "nativeTitleBar": False, "plugins": {"ChatInputButtonAPI": {"enabled": False}, "Experiments": {"enabled": True}},
    "uiElements": {}, "notifications": {"timeout": 5000, "position": "bottom-right"},
    "cloud": {"authenticated": False, "url": "https://api.vencord.dev/"},
}


def make_home(tmp, vencord=VENCORD):
    home = Path(tmp) / "home"
    vdir = home / ".config" / "vesktop"
    (vdir / "settings").mkdir(parents=True)
    (vdir / "themes").mkdir()
    if vencord is not None:
        (vdir / "settings" / "settings.json").write_text(json.dumps(vencord, indent=4))
    (vdir / "settings.json").write_text(json.dumps({"discordBranch": "stable", "transparencyOption": "none"}, indent=4))
    env = {"HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"), "XDG_DATA_HOME": str(home / ".local/share"),
           "XDG_CACHE_HOME": str(home / ".cache"), "VITRUM_VESKTOP_THEME_SRC": str(THEME_SRC),
           "VITRUM_VESKTOP_PREFIXES": ""}
    return home, vdir, env


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
    s["vesktop"]["theme"].update(theme)
    return s


def theme_info(css):
    """Vencord's header parser (src/main/themes/index.ts getThemeInfo), cut down."""
    block = css.split("/**", 1)[1].split("*/", 1)[0]
    out, field, acc = {}, "", ""
    for line in re.split(r"[^\S\r\n]*?\r?(?:\r\n|\n)[^\S\r\n]*?\*[^\S\r\n]?", block):
        if not line:
            continue
        if line[0] == "@" and line[1:2] != " ":
            out[field] = acc.strip()
            field, _, acc = line[1:].partition(" ")
        else:
            acc += " " + line
    out[field] = acc.strip()
    out.pop("", None)
    return out


class Base(unittest.TestCase):
    vencord = VENCORD

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home, self.vdir, self.env = make_home(self.tmp.name, self.vencord)
        p = mock.patch.dict(os.environ, self.env)
        p.start()
        self.addCleanup(p.stop)
        q = mock.patch.object(vesktop, "vesktop_pid", lambda run=None: None)
        q.start()
        self.addCleanup(q.stop)

    def tearDown(self):
        self.tmp.cleanup()

    def vencord_settings(self):
        return json.loads(vesktop.settings_file().read_text())

    def theme_text(self):
        return vesktop.theme_file().read_text()


# ------------------------------------------------------------------ files ---

class Defaults(unittest.TestCase):
    def test_the_two_keys(self):
        d = json.loads((ROOT / "shell/data/settings.defaults.json").read_text())
        self.assertEqual(d["vesktop"]["theme"], {"enabled": True, "sync": True})

    def test_theme_header_is_what_vencord_reads(self):
        css = THEME_SRC.read_text()
        self.assertTrue(css.startswith("/**"), "the meta header is the first /** block")
        info = theme_info(css)
        self.assertEqual(info["name"], "vitrum")
        for k in ("author", "description", "version"):
            self.assertTrue(info.get(k), k)

    def test_the_shipped_block_is_what_apply_writes_for_the_default_preset(self):
        pal = vt.with_accent2(vt.guard(vt.palette_from_preset("graphite")), {})
        want = vesktop.colours_block(vesktop._roles(pal), "preset graphite (shipped default)")
        self.assertEqual(vesktop.read_block(THEME_SRC.read_text()), want)

    def test_every_variable_used_is_defined(self):
        css = THEME_SRC.read_text()
        defined = set(re.findall(r"(--vt-[\w-]+)\s*:", css))
        used = set(re.findall(r"var\((--vt-[\w-]+)", css))
        self.assertEqual(used - defined, set())

    def test_lit_glass_no_capsules_no_bounce_no_transparency(self):
        css = THEME_SRC.read_text()
        self.assertIn("linear-gradient(180deg, rgba(255, 255, 255, .20), rgba(255, 255, 255, .10))", css)
        self.assertIn("inset 0 0 0 1px rgba(255, 255, 255, .30), inset 0 1px 0 rgba(255, 255, 255, .55)", css)
        self.assertIn("0 4px 16px -6px rgba(var(--vt-glow-rgb), .55)", css)
        self.assertIn("rgba(var(--vt-glow-rgb), .32)", css)               # a switch that is on
        self.assertNotRegex(css, r"border-radius:\s*(9999|999|50%|1337|100px)")
        self.assertNotIn("cubic-bezier(.34", css)                          # overshoot (Motion checks every curve)
        self.assertNotIn("--vt-glass-opacity", css)                        # no opacity setting any more
        self.assertNotIn("transparent: true", css)
        for r in ("12px", "9px", "20px"):
            self.assertIn(r, css)
        self.assertIn('"Inter"', css)

    def test_the_ground_is_opaque(self):
        css = THEME_SRC.read_text()
        self.assertRegex(css, r"html,\s*body,\s*#app-mount\s*\{\s*background: var\(--vt-bg\) !important;")
        self.assertIn("--background-base-lowest: var(--vt-bg);", css)

    def test_selected_text_keeps_the_text_colour(self):
        css = THEME_SRC.read_text()
        self.assertNotRegex(css, r"color:\s*var\(--vt-bg\)")
        self.assertNotIn("onAccent", css)

    def test_every_discord_theme_class_gets_the_variables(self):
        css = THEME_SRC.read_text()
        self.assertIn(":is(.theme-dark, .theme-light, .theme-darker, .theme-midnight):not(.custom-user-profile-theme)", css)


# ----------------------------------------------------------------- motion ---

def _css():
    return re.sub(r"/\*.*?\*/", "", THEME_SRC.read_text(), flags=re.S)


def _block(css, head):
    """The body of the first block whose prelude is exactly head (braces balanced)."""
    i = css.index(head + " {")
    j = css.index("{", i) + 1
    depth = 1
    for k in range(j, len(css)):
        depth += {"{": 1, "}": -1}.get(css[k], 0)
        if depth == 0:
            return css[j:k]
    raise AssertionError(f"unclosed {head}")


def _tokens(css):
    """The shipped tokens block (the first :root is the generated colours)."""
    i = css.index("--vt-ease:")
    return _block(css[css.rindex(":root {", 0, i):], ":root")


def _decls(body):
    return dict(re.findall(r"(--vt-[\w-]+)\s*:\s*([^;]+);", body))


DURATIONS = ("--vt-dur-fast", "--vt-dur", "--vt-dur-slow", "--vt-dur-sweep", "--vt-delay-sweep")
DISTANCES = {"--vt-slide": "0px", "--vt-lift": "0px", "--vt-rise": "0px", "--vt-pop": "1", "--vt-press": "1"}


class Motion(unittest.TestCase):
    def test_nothing_loops(self):
        css = _css()
        self.assertNotIn("infinite", css)
        self.assertNotRegex(css, r"animation-iteration-count\s*:\s*(?!1\b)")
        self.assertNotRegex(css, r"\balternate\b")

    def test_damped_never_overshoots(self):
        """Every curve stays inside 0..1 on the progress axis (no bounce)."""
        curves = re.findall(r"cubic-bezier\(([^)]*)\)", _css())
        self.assertTrue(curves)
        for c in curves:
            x1, y1, x2, y2 = (float(v) for v in c.split(","))
            for y in (y1, y2):
                self.assertTrue(0 <= y <= 1, f"cubic-bezier({c}) overshoots")
        self.assertIn("--vt-ease: cubic-bezier(.2, .8, .2, 1);", _tokens(_css()))
        self.assertNotRegex(_css(), r"\b(ease-out-back|steps\()")

    def test_durations_are_in_range(self):
        tokens = _decls(_tokens(_css()))
        for name in DURATIONS:
            ms = float(tokens[name].removesuffix("ms"))
            lo = 0 if name.startswith("--vt-delay") else 120
            self.assertTrue(lo <= ms <= 380, f"{name}: {tokens[name]}")

    def test_every_timing_goes_through_the_tokens(self):
        """No literal times in animation or transition declarations, so reduced
        motion (which zeroes the tokens) reaches every one of them."""
        for prop, value in re.findall(r"(?<![\w-])(animation|transition)(?:-duration|-delay)?\s*:\s*([^;}]+)", _css()):
            self.assertNotRegex(value, r"(?<![\w-])\d*\.?\d+m?s\b", f"{prop}: {value}")
        for name, value in _decls(_tokens(_css())).items():
            if name.startswith("--vt-tr-"):
                self.assertNotRegex(value, r"(?<![\w-])\d*\.?\d+m?s\b", name)

    def test_reduced_motion_zeroes_everything_both_ways(self):
        css = _css()
        system = _decls(_block(_block(css, "@media (prefers-reduced-motion: reduce)"), ":root"))
        discord = _decls(_block(css, ".reduce-motion"))   # Discord's own setting, on <html>
        for decls in (system, discord):
            for name in DURATIONS:
                self.assertEqual(decls.get(name), "0ms", name)
            for name, rest in DISTANCES.items():
                self.assertEqual(decls.get(name), rest, name)
        self.assertEqual(discord.get("--vt-tr-surface"), "none")
        # the reduced blocks come after everything they override
        self.assertGreater(css.index(".reduce-motion {"), css.rindex("@keyframes"))

    def test_every_animation_has_its_keyframes_and_back(self):
        css = _css()
        defined = set(re.findall(r"@keyframes\s+([\w-]+)", css))
        used = set()
        for value in re.findall(r"(?<![\w-])animation(?:-name)?\s*:\s*([^;}]+)", css):
            used |= set(re.findall(r"\b(vt-[\w-]+)\b", value)) - {n for n in re.findall(r"--(vt-[\w-]+)", value)}
        self.assertEqual(used - defined, set(), "used without keyframes")
        self.assertEqual(defined - used, set(), "keyframes nobody uses")

    def test_the_animated_properties_are_registered(self):
        css = _css()
        for name, syntax, initial in (("--vt-k", "<number>", "1"), ("--vt-sweep-x", "<percentage>", "-20%")):
            body = _block(css, f"@property {name}")
            self.assertIn(f'syntax: "{syntax}"', body)
            self.assertIn("inherits: false", body)
            self.assertIn(f"initial-value: {initial}", body)
        # the sweep rests outside the glass at both ends
        self.assertIn("from { --vt-sweep-x: 120%; }", css)
        self.assertIn("to { --vt-sweep-x: -20%; }", css)

    def test_the_lit_rule_is_the_lit_tokens_at_full_strength(self):
        css = _css()
        tokens = _tokens(css)
        lit = re.search(r"--vt-lit:\s*([^;]+);", tokens).group(1)
        rim = re.search(r"--vt-rim-lit:\s*([^;]+);", tokens).group(1)
        rule = css[css.index("calc(.20 * var(--vt-k, 1))") - 200:]
        bg = re.search(r"linear-gradient\(180deg, rgba\(255, 255, 255, calc\(([.\d]+) \* var\(--vt-k, 1\)\)\), "
                       r"rgba\(255, 255, 255, calc\(([.\d]+) \* var\(--vt-k, 1\)\)\)\)", rule)
        self.assertEqual(re.findall(r"rgba\(255, 255, 255, ([.\d]+)\)", lit), list(bg.groups()))
        shadow = re.search(r"box-shadow:([^;]+);", rule).group(1)
        self.assertEqual(re.findall(r"calc\(([.\d]+) \* var\(--vt-k, 1\)\)", shadow),
                         re.findall(r"(?:255, |-rgb\), )([.\d]+)\)", rim))

    def test_the_new_settings_stand_on_the_ground_and_light_their_row(self):
        """Discord's current settings are an <aside> sidebar and a panel in one
        container over the app; with glass panels the app showed through."""
        css = _css()
        self.assertRegex(css, r':has\(> aside:is\(\[class\^="sidebar_"\], \[class\*=" sidebar_"\]\)[^{]*\{\s*'
                              r'background: var\(--vt-ground\) !important;')
        on_rule = css[:css.index("calc(.20 * var(--vt-k, 1))")]
        self.assertIn('[data-settings-sidebar-item] > [aria-current="page"],', on_rule[on_rule.rindex("}"):])
        self.assertIn("--selected-tab-item-color: var(--vt-text) !important;", css)   # no accent-coloured tab label

    def test_the_selected_channel_sweeps_once_and_the_rest_fade(self):
        css = _css()
        self.assertRegex(css, r"vt-lit-in var\(--vt-dur-slow\) var\(--vt-ease\) backwards,\s*"
                              r"vt-sweep var\(--vt-dur-sweep\) var\(--vt-ease-sweep\) var\(--vt-delay-sweep\) backwards;")
        for what in ('li:is([class^="messageListItem_"]', '[role="menu"]', '[role="dialog"][aria-modal="true"]',
                     ".user-profile-popout", 'typingDots_', 'isUnread_', 'folderGuildsList_'):
            self.assertIn(what, css)


# ---------------------------------------------------------------- colours ---

class Colours(unittest.TestCase):
    def test_block(self):
        b = vesktop.colours_block(vesktop._roles(palette()), "wallpaper")
        self.assertTrue(b.startswith(vesktop.BEGIN) and b.endswith(vesktop.END))
        self.assertIn("--vt-accent: #f2b3e7;", b)
        self.assertIn("--vt-accent-rgb: 242, 179, 231;", b)
        self.assertIn("--vt-surface-highest: #332b38;", b)
        self.assertIn("/* palette: wallpaper */", b)
        self.assertNotIn("/**", b, "only the meta header may open with /**")

    def test_always_the_dark_scheme(self):
        b = vesktop.colours_block(vesktop._roles(palette()))
        self.assertIn("--vt-bg: #100c12;", b)
        self.assertNotIn("#fff7f9", b)

    def test_accent2_from_vitrum_maths(self):
        p = palette()
        self.assertIn(f"--vt-accent2: {p['dark']['accent2']};", vesktop.colours_block(vesktop._roles(p)))
        old = {"dark": {k: v for k, v in p["dark"].items() if k != "accent2"}}
        self.assertIn(f"--vt-accent2: {vt.accent2('#f2b3e7', -100.0, True)};", vesktop.colours_block(vesktop._roles(old)))

    def test_glow_is_kept_from_going_pastel(self):
        import colorsys
        b = vesktop.colours_block(vesktop._roles(palette("#f2d5ee")))
        rgb = [int(x) / 255 for x in re.search(r"--vt-glow-rgb: ([\d, ]+);", b).group(1).split(",")]
        self.assertLessEqual(colorsys.rgb_to_hls(*rgb)[1], 0.625)
        dark = vesktop.colours_block(vesktop._roles(palette("#3a5fa0")))
        self.assertIn("--vt-glow-rgb: 58, 95, 160;", dark, "a deep accent is left as it is")

    def test_an_old_palette_without_the_newer_roles(self):
        p = {"dark": {"bg": "#000000", "surface": "#111111", "surfaceHigh": "#222222", "text": "#eeeeee",
                      "textDim": "#aaaaaa", "accent": "#8ab4f8", "danger": "#f28b82"}}
        b = vesktop.colours_block(vesktop._roles(p))
        self.assertIn("--vt-surface-highest: #222222;", b)
        self.assertIn("--vt-warning: #fdd663;", b)

    def test_with_block_changes_only_the_block(self):
        css = THEME_SRC.read_text()
        new = vesktop.with_block(css, vesktop.colours_block(vesktop._roles(palette())))
        before, after = css.split(vesktop.BEGIN)[0], css.split(vesktop.END)[1]
        self.assertTrue(new.startswith(before) and new.endswith(after))
        self.assertIn("#f2b3e7", new)
        with self.assertRaises(vesktop.VesktopThemeError):
            vesktop.with_block("/** @name x */", "x")


# ------------------------------------------------------- Vencord settings ---

class VencordSettings(Base):
    def test_enable_keeps_every_other_key_and_its_order(self):
        self.assertTrue(vesktop.set_enabled(True))
        raw = vesktop.settings_file().read_text()
        cfg = json.loads(raw)
        self.assertEqual(cfg["enabledThemes"], ["vitrum.theme.css"])
        self.assertEqual(list(cfg), list(VENCORD))
        self.assertEqual({k: v for k, v in cfg.items() if k != "enabledThemes"},
                         {k: v for k, v in VENCORD.items() if k != "enabledThemes"})
        self.assertIn('\n    "autoUpdate": true', raw, "written as Vencord writes it (4 spaces)")
        self.assertFalse(cfg["transparent"], "transparency is not touched")
        self.assertFalse(vesktop.set_enabled(True), "a second time changes nothing")

    def test_other_themes_stay(self):
        cfg = dict(VENCORD, enabledThemes=["midnight.theme.css"])
        vesktop.settings_file().write_text(json.dumps(cfg, indent=4))
        vesktop.set_enabled(True)
        self.assertEqual(self.vencord_settings()["enabledThemes"], ["midnight.theme.css", "vitrum.theme.css"])
        vesktop.set_enabled(False)
        self.assertEqual(self.vencord_settings()["enabledThemes"], ["midnight.theme.css"])

    def test_no_settings_yet(self):
        vesktop.settings_file().unlink()
        self.assertFalse(vesktop.set_enabled(False))
        self.assertFalse(vesktop.settings_file().exists(), "switching off makes no file")
        self.assertTrue(vesktop.set_enabled(True))
        self.assertEqual(self.vencord_settings(), {"enabledThemes": ["vitrum.theme.css"]})

    def test_broken_settings_are_not_touched(self):
        vesktop.settings_file().write_text("{nope")
        with self.assertRaises(vesktop.VesktopThemeError):
            vesktop.set_enabled(True)
        self.assertEqual(vesktop.settings_file().read_text(), "{nope")

    def test_atomic_and_mode_kept(self):
        os.chmod(vesktop.settings_file(), 0o600)
        vesktop.set_enabled(True)
        self.assertEqual(vesktop.settings_file().stat().st_mode & 0o777, 0o600)
        self.assertEqual([p.name for p in vesktop.settings_file().parent.iterdir()], ["settings.json"])

    def test_paths_follow_vesktop(self):
        self.assertEqual(vesktop.themes_dir(), self.vdir / "themes")
        self.assertEqual(vesktop.settings_file(), self.vdir / "settings" / "settings.json")

    def test_flatpak_data_dir(self):
        import shutil
        shutil.rmtree(self.vdir)
        flat = self.home / ".var/app/dev.vencord.Vesktop/config/vesktop"
        flat.mkdir(parents=True)
        self.assertEqual(vesktop.vesktop_dir(), flat)


# ------------------------------------------------------------------ apply ---

class Apply(Base):
    def test_not_installed(self):
        with self.assertRaises(vesktop.VesktopThemeError):
            vesktop.apply(settings(), palette())

    def test_apply_writes_the_colours_and_enables_the_theme(self):
        vesktop.install_theme()
        out = vesktop.apply(settings(), palette(), note="wallpaper")
        self.assertIn(str(vesktop.theme_file()), out)
        self.assertIn(str(vesktop.settings_file()), out)
        text = self.theme_text()
        self.assertIn("--vt-accent: #f2b3e7;", text)
        self.assertIn("/* palette: wallpaper */", text)
        self.assertTrue(text.startswith("/**"))
        self.assertEqual(self.vencord_settings()["enabledThemes"], ["vitrum.theme.css"])
        self.assertEqual(vesktop.apply(settings(), palette(), note="wallpaper"), [], "nothing changed")

    def test_disabled(self):
        vesktop.install_theme()
        vesktop.apply(settings(), palette())
        vesktop.apply(settings(enabled=False), palette())
        self.assertEqual(self.vencord_settings()["enabledThemes"], [])
        self.assertTrue(vesktop.theme_file().is_file(), "off keeps the file")

    def test_sync_off_keeps_the_colours(self):
        vesktop.install_theme()
        vesktop.apply(settings(), palette("#f2b3e7"))
        vesktop.apply(settings(sync=False), palette("#00ff00"))
        self.assertIn("#f2b3e7", self.theme_text())
        self.assertNotIn("#00ff00", self.theme_text())

    def test_vitrum_theme_runs_leave_a_choice_made_in_vencord(self):
        vesktop.install_theme()
        vesktop.apply(settings(), palette(), enforce=False)
        self.assertEqual(self.vencord_settings()["enabledThemes"], ["vitrum.theme.css"])
        vesktop.set_enabled(False)                    # switched off in Vencord's own settings
        vesktop.apply(settings(), palette(), enforce=False)
        self.assertEqual(self.vencord_settings()["enabledThemes"], [])
        vesktop.apply(settings(enabled=False), palette(), enforce=False)
        vesktop.apply(settings(enabled=True), palette(), enforce=False)   # the setting changed: follow it
        self.assertEqual(self.vencord_settings()["enabledThemes"], ["vitrum.theme.css"])

    def test_vesktop_running_starts_the_watcher(self):
        vesktop.install_theme()
        spawned = []
        with mock.patch.object(vesktop, "vesktop_pid", lambda run=None: 4242):
            vesktop.apply(settings(), palette(), spawn=lambda: spawned.append(1))
            self.assertTrue(vesktop.needs_restart())
        self.assertEqual(spawned, [1])
        self.assertFalse(vesktop.needs_restart(), "not while Vesktop is not running")
        # Not running: no watcher.
        vesktop.apply(settings(enabled=False), palette(), spawn=lambda: spawned.append(2))
        self.assertEqual(spawned, [1])

    def test_install_keeps_the_colours_reinstall_replaces(self):
        vesktop.install_theme()
        vesktop.apply(settings(), palette("#f2b3e7"))
        vesktop.install_theme()
        self.assertIn("#f2b3e7", self.theme_text())
        vesktop.install_theme(replace=True)
        self.assertNotIn("#f2b3e7", self.theme_text())
        self.assertEqual(self.theme_text(), THEME_SRC.read_text())

    def test_install_needs_vesktop(self):
        import shutil
        shutil.rmtree(self.vdir)
        with mock.patch.object(vesktop.shutil, "which", lambda name: None):
            with self.assertRaises(vesktop.VesktopThemeError) as e:
                vesktop.install_theme()
        self.assertIn("Vesktop is not installed", str(e.exception))

    def test_installed_but_never_started(self):
        import shutil
        shutil.rmtree(self.vdir)
        with mock.patch.object(vesktop.shutil, "which", lambda name: "/usr/bin/vesktop" if name == "vesktop" else None):
            vesktop.install_theme()
            vesktop.apply(settings(), palette())
        self.assertEqual(self.vencord_settings(), {"enabledThemes": ["vitrum.theme.css"]})

    def test_remove(self):
        vesktop.install_theme()
        vesktop.apply(settings(), palette())
        self.assertTrue(vesktop.remove_theme())
        self.assertFalse(vesktop.theme_file().exists())
        cfg = self.vencord_settings()
        self.assertEqual(cfg["enabledThemes"], [])
        self.assertEqual({k: v for k, v in cfg.items() if k != "enabledThemes"},
                         {k: v for k, v in VENCORD.items() if k != "enabledThemes"})
        self.assertFalse(vesktop.state_file().exists())
        self.assertFalse(vesktop.remove_theme(), "a second time: nothing to delete")

    def test_temp_files_are_not_themes(self):
        vesktop.install_theme()
        vesktop.apply(settings(), palette())
        self.assertEqual(sorted(p.name for p in vesktop.themes_dir().iterdir()), ["vitrum.theme.css"])


class Watch(Base):
    def test_puts_the_choice_back_until_vesktop_restarts(self):
        vesktop.install_theme()
        with mock.patch.object(vesktop, "vesktop_pid", lambda run=None: 100):
            vesktop.apply(settings(), palette(), spawn=lambda: None)
        pids = iter([100, 100, 200])
        ticks = []

        def sleep(_):
            ticks.append(1)
            if len(ticks) == 1:          # Vencord writes its own copy back
                vesktop.settings_file().write_text(json.dumps(VENCORD, indent=4))
        with mock.patch.object(vesktop, "vesktop_pid", lambda run=None: next(pids)):
            self.assertEqual(vesktop.watch(sleep=sleep), "restarted")
        self.assertEqual(self.vencord_settings()["enabledThemes"], ["vitrum.theme.css"])
        self.assertFalse(json.loads(vesktop.state_file().read_text())["pending"])

    def test_ends_when_vesktop_is_gone(self):
        vesktop.install_theme()
        vesktop.apply(settings(), palette())
        self.assertEqual(vesktop.watch(sleep=lambda _: None), "quit")

    def test_ends_when_the_theme_is_removed(self):
        self.assertEqual(vesktop.watch(sleep=lambda _: None), "gone")


class Sync(Base):
    def data(self, comps):
        d = Path(self.tmp.name) / "data"
        d.mkdir(exist_ok=True)
        if comps is not None:
            (d / "components.json").write_text(json.dumps(comps))
        return d

    def test_needs_the_component(self):
        vesktop.install_theme()
        before = vesktop.settings_file().read_text()
        for comps in (None, {"games": True}, {"vesktop_theme": False}, {"steam_theme": True}):
            self.assertEqual(vesktop.sync(settings(), palette(), self.data(comps)), [])
        self.assertEqual(vesktop.settings_file().read_text(), before)
        self.assertNotIn("#f2b3e7", self.theme_text())

    def test_needs_the_theme_installed(self):
        self.assertEqual(vesktop.sync(settings(), palette(), self.data({"vesktop_theme": True})), [])

    def test_writes_with_the_component(self):
        vesktop.install_theme()
        out = vesktop.sync(settings(), palette(), self.data({"vesktop_theme": True}), note="wallpaper")
        self.assertIn(str(vesktop.theme_file()), out)
        self.assertIn("#f2b3e7", self.theme_text())

    def test_sync_off_keeps_last_colours(self):
        vesktop.install_theme()
        data = self.data({"vesktop_theme": True})
        vesktop.sync(settings(), palette("#f2b3e7"), data)
        vesktop.sync(settings(sync=False), palette("#00ff00"), data)
        self.assertIn("#f2b3e7", self.theme_text())

    def test_broken_vencord_settings_warn_but_do_not_fail(self):
        vesktop.install_theme()
        vesktop.settings_file().write_text("{nope")
        with mock.patch("sys.stderr"):
            self.assertEqual(vesktop.sync(settings(), palette(), self.data({"vesktop_theme": True})), [])


class RecordComponent(Base):
    def test_marks_the_part_in_the_installers_file(self):
        f = vesktop.data_home() / "vitrum" / "components.json"
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(json.dumps({"version": 2, "games": True, "vesktop_theme": False}))
        vesktop.record_component(True)
        self.assertEqual(json.loads(f.read_text()), {"version": 2, "games": True, "vesktop_theme": True})

    def test_never_makes_the_file(self):
        vesktop.record_component(True)
        self.assertFalse((vesktop.data_home() / "vitrum" / "components.json").exists())


class Status(Base):
    def test_status(self):
        s = vesktop.status()
        self.assertEqual(set(s), {"vesktop", "installed", "active", "running", "themeDir"})
        self.assertEqual((s["vesktop"], s["installed"], s["active"], s["running"]), (True, False, False, False))
        self.assertEqual(s["themeDir"], str(self.vdir / "themes"))
        vesktop.install_theme()
        vesktop.apply(settings(), palette())
        s = vesktop.status()
        self.assertEqual((s["installed"], s["active"]), (True, True))

    def test_pid_asks_pgrep(self):
        calls = []

        def run(cmd, **kw):
            calls.append(cmd)
            return subprocess.CompletedProcess(cmd, 0, "231414\n", "")
        self.assertEqual(ORIGINAL_PID(run), 231414)
        self.assertEqual(calls[0][:2], ["pgrep", "-u"])
        self.assertIn("-o", calls[0])
        self.assertIsNone(ORIGINAL_PID(lambda cmd, **kw: subprocess.CompletedProcess(cmd, 1, "", "")))

    def test_the_pattern_finds_vesktop_not_vitrum(self):
        rx = re.compile(vesktop.PGREP_PATTERN)
        for line in ("/usr/lib/electron43/electron /usr/lib/vesktop/app.asar env ELECTRON_OZONE_PLATFORM_HINT=auto",
                     "/opt/Vesktop/vesktop --enable-features=UseOzonePlatform",
                     "/bin/sh /usr/bin/vesktop %U",
                     "bwrap --args 41 -- dev.vencord.Vesktop",
                     "/usr/lib/electron43/electron --type=renderer --user-data-dir=/home/u/.config/vesktop --app-path=x"):
            self.assertTrue(rx.search(line), line)
        for line in ("/usr/bin/python3 /home/u/.local/bin/vitrum-vesktop-theme status",
                     "python3 -m vitrum_theme.vesktop watch",
                     "nvim /home/u/.config/vesktop/settings/settings.json"):
            self.assertFalse(rx.search(line), line)


# ---------------------------------------------------------------- the CLIs ---

class Helper(unittest.TestCase):
    """The command itself, with PATH stubs (pgrep says Vesktop is not running)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home, self.vdir, env = make_home(self.tmp.name)
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
        (pal.parent / "components.json").write_text(json.dumps({"version": 2, "vesktop_theme": False}))

    def tearDown(self):
        self.tmp.cleanup()

    def run_tool(self, tool, *args):
        return subprocess.run([sys.executable, str(tool), *args], env=self.env, capture_output=True, text=True,
                              stdin=subprocess.DEVNULL)

    def vencord(self):
        return json.loads((self.vdir / "settings/settings.json").read_text())

    def test_status(self):
        r = self.run_tool(HELPER, "status")
        self.assertEqual(r.returncode, 0, r.stderr)
        s = json.loads(r.stdout)
        self.assertEqual(set(s), {"vesktop", "installed", "active", "running", "themeDir"})
        self.assertEqual((s["vesktop"], s["installed"], s["running"]), (True, False, False))
        self.assertEqual(r.stdout.count("\n"), 1)

    def test_apply_without_the_theme_fails_with_a_message(self):
        r = self.run_tool(HELPER, "apply")
        self.assertEqual(r.returncode, 1)
        self.assertIn("not installed", r.stderr)

    def test_install_apply_remove(self):
        r = self.run_tool(HELPER, "install", "--yes")
        self.assertEqual(r.returncode, 0, r.stderr)
        theme = self.vdir / "themes" / "vitrum.theme.css"
        self.assertIn("--vt-accent: #f2b3e7;", theme.read_text())
        self.assertEqual(self.vencord()["enabledThemes"], ["vitrum.theme.css"])
        self.assertFalse(self.vencord()["transparent"])
        comps = json.loads((self.home / ".local/share/vitrum/components.json").read_text())
        self.assertIs(comps["vesktop_theme"], True)
        s = json.loads(self.run_tool(HELPER, "status").stdout)
        self.assertEqual((s["installed"], s["active"], s["running"]), (True, True, False))
        # Settings: off.
        (self.home / ".config/vitrum").mkdir(parents=True)
        (self.home / ".config/vitrum/settings.json").write_text(json.dumps({"vesktop": {"theme": {"enabled": False}}}))
        self.assertEqual(self.run_tool(HELPER, "apply").returncode, 0)
        self.assertEqual(self.vencord()["enabledThemes"], [])
        r = self.run_tool(HELPER, "remove")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(theme.exists())
        self.assertEqual({k: v for k, v in self.vencord().items() if k != "enabledThemes"},
                         {k: v for k, v in VENCORD.items() if k != "enabledThemes"})

    def test_reinstall(self):
        self.assertEqual(self.run_tool(HELPER, "install").returncode, 0)
        theme = self.vdir / "themes" / "vitrum.theme.css"
        theme.write_text(theme.read_text().replace("@name vitrum", "@name broken"))
        self.assertEqual(self.run_tool(HELPER, "reinstall").returncode, 0)
        self.assertIn("@name vitrum", theme.read_text())

    def test_install_without_vesktop(self):
        import shutil
        shutil.rmtree(self.home / ".config/vesktop")
        r = self.run_tool(HELPER, "install")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Vesktop is not installed", r.stderr)

    def test_vitrum_theme_syncs_only_with_the_component(self):
        self.assertEqual(self.run_tool(HELPER, "install").returncode, 0)
        theme = self.vdir / "themes" / "vitrum.theme.css"
        data = self.home / ".local/share/vitrum"
        args = ["--quiet", "--no-color-scheme", "--out-palette", str(data / "palette.json"),
                "--niri-dir", str(Path(self.tmp.name) / "niri"), "--templates", str(Path(self.tmp.name) / "none")]
        theme.write_text(vesktop.with_block(theme.read_text(), vesktop.colours_block(vesktop._roles(palette("#123456")))))
        (data / "components.json").write_text(json.dumps({"version": 2, "vesktop_theme": False}))
        r = self.run_tool(VITRUM_THEME, *args)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("#123456", theme.read_text(), "without the component the theme is left alone")
        (data / "components.json").write_text(json.dumps({"version": 2, "vesktop_theme": True}))
        r = self.run_tool(VITRUM_THEME, *args)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("#123456", theme.read_text())
        self.assertIn("--vt-bg:", theme.read_text())


if __name__ == "__main__":
    unittest.main()
