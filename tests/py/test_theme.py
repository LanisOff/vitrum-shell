"""Tests for vitrum-theme (tools/vitrum_theme). Run: python3 -m unittest discover -s tests/py"""
import json
import re
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import vitrum_theme as vt  # noqa: E402

FIX = Path(__file__).parent / "fixtures"
ROLES = ["bg", "surface", "surfaceHigh", "surfaceHighest", "outline", "text", "textDim",
         "accent", "onAccent", "danger", "warning", "success"]


def write(tmp, name, data):
    p = Path(tmp) / name
    p.write_text(json.dumps(data))
    return p


class Settings(unittest.TestCase):
    def test_missing_file_gives_defaults(self):
        s, warnings = vt.load_settings(Path("/nonexistent/settings.json"))
        self.assertEqual(s["density"], "compact")
        self.assertEqual(s["materials"]["default"], "frosted")
        self.assertEqual(warnings, [])

    def test_wrong_type_falls_back_and_warns(self):
        with tempfile.TemporaryDirectory() as tmp:
            s, warnings = vt.load_settings(write(tmp, "s.json", {"density": 3, "motion": {"speed": 2.0}}))
        self.assertEqual(s["density"], "compact")
        self.assertEqual(s["motion"]["speed"], 2.0)
        self.assertEqual(len(warnings), 1)

    def test_bad_enum_falls_back(self):
        with tempfile.TemporaryDirectory() as tmp:
            s, _ = vt.load_settings(write(tmp, "s.json", {"materials": {"default": "chrome", "groups": {"bar": "solid", "dock": "x"}}}))
        self.assertEqual(s["materials"]["default"], "frosted")
        # The bad one is dropped; the user's bar and the default groups stay.
        self.assertEqual(s["materials"]["groups"], {"bar": "solid", "lock": "glass", "launcher": "glass"})

    def test_invalid_json_gives_defaults_with_warning(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "s.json"
            p.write_text("{nope")
            s, warnings = vt.load_settings(p)
        self.assertEqual(s["density"], "compact")
        self.assertTrue(warnings)


class Palette(unittest.TestCase):
    def test_every_preset_has_every_role_in_both_schemes(self):
        for name in vt.preset_names():
            p = vt.palette_from_preset(name)
            for scheme in ("dark", "light"):
                for role in ROLES:
                    self.assertRegex(p[scheme][role], r"^#[0-9a-f]{6}$", f"{name}.{scheme}.{role}")

    def test_manual_accent_overrides_preset(self):
        p = vt.palette_from_preset("graphite", accent="#ff0066")
        self.assertEqual(p["dark"]["accent"], "#ff0066")
        self.assertEqual(p["light"]["accent"], "#ff0066")

    def test_from_matugen_json_maps_roles(self):
        data = json.loads((FIX / "matugen.json").read_text())
        p = vt.palette_from_matugen(data)
        self.assertEqual(p["dark"]["accent"], data["colors"]["primary"]["dark"]["color"])
        self.assertEqual(p["light"]["surface"], data["colors"]["surface"]["light"]["color"])
        for role in ROLES:
            self.assertIn(role, p["dark"])

    def test_guard_lifts_dim_text(self):
        p = {"dark": {r: "#202020" for r in ROLES}, "light": {r: "#f0f0f0" for r in ROLES}}
        p["dark"]["text"] = "#303030"
        g = vt.guard(p)
        self.assertGreaterEqual(vt.contrast(g["dark"]["text"], g["dark"]["surface"]), 4.5)
        self.assertGreaterEqual(vt.contrast(g["dark"]["onAccent"], g["dark"]["accent"]), 4.5)

    def test_missing_wallpaper_falls_back_to_preset(self):
        s, _ = vt.load_settings(Path("/nonexistent"))
        s["palette"]["source"] = "wallpaper"
        p, note = vt.resolve_palette(s, Path("/no/such/wallpaper.png"))
        self.assertEqual(p, vt.guard(vt.palette_from_preset(s["palette"]["preset"])))
        self.assertIn("preset", note)

    def test_video_wallpaper_uses_poster(self):
        calls = []
        def fake_run(cmd, **kw):
            calls.append(cmd[0])
            if cmd[0] == "ffmpeg":
                Path(cmd[-1]).write_bytes(b"png")
                return subprocess.CompletedProcess(cmd, 0, b"", b"")
            return subprocess.CompletedProcess(cmd, 0, (FIX / "matugen.json").read_bytes(), b"")
        with tempfile.TemporaryDirectory() as tmp:
            video = Path(tmp) / "w.mp4"
            video.write_bytes(b"x")
            s, _ = vt.load_settings(Path("/nonexistent"))
            p, note = vt.resolve_palette(s, video, run=fake_run, cache=Path(tmp))
        self.assertEqual(calls, ["ffmpeg", "matugen"])
        self.assertIn("poster", note)


class BadShapes(unittest.TestCase):
    """Values that pass the type check but are the wrong shape must not crash the tool."""

    def settings(self, **over):
        s, _ = vt.load_settings(Path("/nonexistent"))
        for path, value in over.items():
            cur = s
            keys = path.split("__")
            for k in keys[:-1]:
                cur = cur[k]
            cur[keys[-1]] = value
        return s

    def test_bad_accent_falls_back_to_the_preset_accent(self):
        for bad in ("#abc", "red", "#12345z"):
            s = self.settings(palette__source="preset", palette__accent=bad)
            pal, _ = vt.resolve_palette(s, None)
            self.assertRegex(pal["dark"]["accent"], r"^#[0-9a-f]{6}$", bad)

    def test_window_material_entries_that_are_not_objects_are_skipped(self):
        s = self.settings(windows__materials=["kitty", {"appId": "foot", "material": "glass"}, 3])
        k = vt.effects_kdl(s)
        self.assertIn('app-id="^foot$"', k)
        self.assertNotIn("kitty", k)

    def test_missing_matugen_or_ffmpeg_falls_back(self):
        def boom(*a, **kw):
            raise FileNotFoundError("matugen")
        with tempfile.TemporaryDirectory() as tmp:
            img = Path(tmp) / "w.jpg"; img.write_bytes(b"x")
            vid = Path(tmp) / "w.mp4"; vid.write_bytes(b"x")
            s = self.settings(palette__source="wallpaper")
            for wp in (img, vid):
                pal, note = vt.resolve_palette(s, wp, run=boom, cache=Path(tmp) / "c")
                self.assertIn("preset", note)
                self.assertIn("accent", pal["dark"])


class Kdl(unittest.TestCase):
    def settings(self, **over):
        s, _ = vt.load_settings(Path("/nonexistent"))
        for path, value in over.items():
            cur = s
            keys = path.split("__")
            for k in keys[:-1]:
                cur = cur[k]
            cur[keys[-1]] = value
        return s

    def test_effects_groups_and_presets(self):
        s = self.settings(materials__default="glass", materials__glassPreset="lens", materials__groups={"bar": "solid"})
        k = vt.effects_kdl(s)
        bar = k.split('match namespace="^vitrum-bar$"')[1].split("layer-rule")[0]
        self.assertIn("blur false", bar)
        launcher = k.split('match namespace="^vitrum-launcher$"')[1].split("layer-rule")[0]
        self.assertIn("refraction-strength 4.8", launcher)
        self.assertIn('match app-id="^kitty$"', k)

    def test_shaped_glass_on_the_bar(self):
        # A niri with shaped glass: the bar's pieces are rounded by niri and melt
        # into a drop with its panel.
        s = self.settings(materials__groups={"bar": "glass"}, density="regular")
        k = vt.effects_kdl(s, caps={"shapedGlass": True})
        bar = k.split('match namespace="^vitrum-bar$"')[1].split("layer-rule")[0]
        self.assertIn("geometry-corner-radius 17", bar)
        self.assertIn("shape-fillet 17.0", bar)
        launcher = k.split('match namespace="^vitrum-launcher$"')[1].split("layer-rule")[0]
        self.assertNotIn("shape-fillet", launcher)

    def test_glass_bends_what_is_behind_not_only_the_wallpaper(self):
        # xray would sample the wallpaper alone: a panel over a window showed
        # the wallpaper through it, as if the window were not there.
        s = self.settings(materials__groups={"bar": "glass"})
        bar = vt.effects_kdl(s).split('match namespace="^vitrum-bar$"')[1].split("layer-rule")[0]
        self.assertIn("liquid-glass", bar)
        self.assertIn("xray false", bar)
        self.assertNotIn("xray true", bar)

    def test_shaped_glass_on_the_launcher(self):
        # Glass on the launcher: its capsule, category buttons and results melt
        # into one drop too, every piece rounded to half the capsule's height.
        for density, r in (("compact", 24), ("regular", 27), ("comfortable", 30)):
            s = self.settings(materials__groups={"bar": "glass", "launcher": "glass"}, density=density)
            launcher = vt.effects_kdl(s, caps={"shapedGlass": True}).split('match namespace="^vitrum-launcher$"')[1].split("layer-rule")[0]
            self.assertIn(f"geometry-corner-radius {r}", launcher)
            self.assertIn(f"shape-fillet {float(r)}", launcher)
        frosted = self.settings(materials__groups={"launcher": "frosted"})
        self.assertNotIn("shape-fillet", vt.effects_kdl(frosted, caps={"shapedGlass": True}).split('match namespace="^vitrum-launcher$"')[1].split("layer-rule")[0])

    def test_no_shaped_glass_without_support(self):
        s = self.settings(materials__groups={"bar": "glass"})
        self.assertNotIn("shape-fillet", vt.effects_kdl(s))
        self.assertNotIn("shape-fillet", vt.effects_kdl(s, caps={"shapedGlass": False}))
        # frosted or solid bars never ask for it
        self.assertNotIn("shape-fillet", vt.effects_kdl(self.settings(materials__groups={"bar": "frosted"}), caps={"shapedGlass": True}))

    def test_island_radius_follows_density(self):
        for density, r in (("compact", 15), ("regular", 17), ("comfortable", 19)):
            s = self.settings(materials__groups={"bar": "glass"}, density=density)
            self.assertIn(f"geometry-corner-radius {r}", vt.effects_kdl(s, caps={"shapedGlass": True}))

    def test_niri_caps_probe(self):
        # The probe validates a config with the new option; the answer is cached
        # per niri binary.
        calls = []
        def run(cmd, **kw):
            calls.append(cmd)
            class R: returncode = 0
            return R()
        with tempfile.TemporaryDirectory() as tmp:
            niri = Path(tmp) / "niri"; niri.write_text("#!/bin/sh\n"); niri.chmod(0o755)
            caps = vt.niri_caps(niri=str(niri), run=run, cache=Path(tmp) / "c")
            self.assertTrue(caps["shapedGlass"])
            self.assertEqual(calls[0][1:3], ["validate", "-c"])
            vt.niri_caps(niri=str(niri), run=run, cache=Path(tmp) / "c")
            self.assertEqual(len(calls), 1, "cached")
            def fail(cmd, **kw):
                class R: returncode = 1
                return R()
            self.assertFalse(vt.niri_caps(niri=str(Path(tmp) / "missing"), run=fail, cache=Path(tmp) / "d")["shapedGlass"])

    def test_niri_caps_follow_the_running_niri(self):
        # Replaced since the session started: the old niri still runs, and it is
        # the one asked, through /proc — the answer is whatever it can do.
        class St: st_mtime = 1; st_size = 2
        real_stat = os.stat
        def stat(path, *a, **kw):
            return St() if str(path) == "/proc/4242/exe" else real_stat(path, *a, **kw)
        sock = "/run/user/1000/niri.wayland-1.4242.sock"
        for code, want in ((0, True), (1, False)):
            calls = []
            def run(cmd, **kw):
                calls.append(cmd)
                class R: returncode = code
                return R()
            with tempfile.TemporaryDirectory() as tmp, \
                 mock.patch.object(vt.os, "readlink", return_value="/usr/local/bin/niri (deleted)"), \
                 mock.patch.object(vt.os, "stat", side_effect=stat):
                self.assertEqual(vt.niri_caps(socket=sock, run=run, cache=Path(tmp))["shapedGlass"], want)
            self.assertEqual(calls[0][0], "/proc/4242/exe")
        self.assertIsNone(vt.running_niri(socket="/tmp/elsewhere"))

    def test_window_glass_is_bolder_than_the_shells(self):
        # A window's glass sits behind a terminal's text: more refraction and edge
        # light than the panels', and more dimming under the text.
        s = self.settings(materials__glassPreset="lens", windows__materials=[{"appId": "kitty", "material": "glass"}])
        kdl = vt.effects_kdl(s)
        rule = kdl[kdl.index('match app-id="^kitty$"'):]
        lens = dict(zip(vt.GLASS_KEYS, vt.GLASS_PRESETS["lens"]))
        val = lambda k: float(re.search(rf"{k} ([0-9.]+)", rule).group(1))
        self.assertGreater(val("refraction-strength"), lens["refraction-strength"])
        self.assertGreater(val("edge-lighting"), lens["edge-lighting"])
        self.assertGreater(val("adaptive-dim"), lens["adaptive-dim"])
        s2 = self.settings(windows__materials=[{"appId": "kitty", "material": "glass"}], materials__glassAdvanced={"refraction-strength": 2.0})
        kdl2 = vt.effects_kdl(s2)
        self.assertIn("refraction-strength 2", kdl2[kdl2.index('match app-id="^kitty$"'):], "your own values still win")

    def test_glass_has_no_grain(self):
        # niri's blur adds noise 0.02 unless told otherwise: on a big smooth pane
        # (Spotlight) it reads as grain.
        kdl = vt.effects_kdl(self.settings(materials__groups={"launcher": "glass"}))
        launcher = kdl.split('match namespace="^vitrum-launcher$"')[1].split("layer-rule")[0]
        self.assertIn("noise 0\n", launcher)

    def test_clear_window_glass_has_no_blur_and_bends_more(self):
        s = self.settings(windows__materials=[{"appId": "kitty", "material": "clear"}])
        rule = vt.effects_kdl(s).split('match app-id="^kitty$"')[1]
        self.assertIn("blur false", rule)
        self.assertIn("liquid-glass", rule)
        val = lambda r, k: float(re.search(rf"{k} ([0-9.]+)", r).group(1))
        g = vt.effects_kdl(self.settings(windows__materials=[{"appId": "kitty", "material": "glass"}])).split('match app-id="^kitty$"')[1]
        self.assertIn("blur true", g)
        self.assertGreaterEqual(val(rule, "refraction-strength"), val(g, "refraction-strength"))
        for k in ("lens-distortion", "fringing", "power-factor"):
            self.assertIn(k, g, "the frosted lens sets what makes refraction show")

    def test_vitrum_apps_stay_opaque(self):
        # Settings, Disk Utility, About: forms to read, never faded when unfocused;
        # after the unfocused rule, so it wins.
        look = vt.look_kdl(self.settings(), vt.palette_from_preset("graphite"), "dark")
        rule = 'match app-id=r#"^vitrum-(settings|disks|about)$"#'
        self.assertIn(rule, look)
        self.assertGreater(look.index(rule), look.index("match is-focused=false"))
        self.assertIn("opacity 1.0", look[look.index(rule):].split("}")[0])

    def test_glass_advanced_overrides(self):
        s = self.settings(materials__default="glass", materials__glassAdvanced={"refraction-strength": 9.5})
        self.assertIn("refraction-strength 9.5", vt.effects_kdl(s))

    def test_animations_reduce_and_speed(self):
        self.assertIn("off", vt.animations_kdl(self.settings(motion__reduce=True)))
        self.assertIn("slowdown 0.5", vt.animations_kdl(self.settings(motion__speed=2.0)))
        self.assertIn("damping-ratio=0.75 stiffness=520", vt.animations_kdl(self.settings()))
        # KDL: a float property must be written as a float (1.0, not 1)
        self.assertIn("damping-ratio=1.0 stiffness=900", vt.animations_kdl(self.settings()))
        self.assertNotRegex(vt.animations_kdl(self.settings()), r"damping-ratio=\d+ ")
        self.assertIn("opacity 1.0", vt.look_kdl(self.settings(windows__unfocusedOpacity=1), vt.guard(vt.palette_from_preset("graphite")), "dark"))

    def test_look_focus_modes(self):
        pal = vt.guard(vt.palette_from_preset("graphite"))
        self.assertIn("opacity 0.92", vt.look_kdl(self.settings(), pal, "dark"))
        self.assertIn("relative-to=\"workspace-view\"", vt.look_kdl(self.settings(windows__focus="gradient"), pal, "dark"))
        self.assertIn('xcursor-theme "Bibata-Modern-Classic"', vt.look_kdl(self.settings(), pal, "dark"))

    def test_write_if_changed(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "a" / "x.kdl"
            self.assertTrue(vt.write_if_changed(p, "one"))
            self.assertFalse(vt.write_if_changed(p, "one"))
            self.assertTrue(vt.write_if_changed(p, "two"))

    @unittest.skipUnless(shutil.which("niri"), "niri not installed")
    def test_generated_kdl_validates(self):
        s = self.settings(materials__default="glass", windows__focus="gradient")
        pal = vt.guard(vt.palette_from_preset("graphite"))
        with tempfile.TemporaryDirectory() as tmp:
            for name, text in (("look", vt.look_kdl(s, pal, "dark")), ("effects", vt.effects_kdl(s)), ("animations", vt.animations_kdl(s))):
                (Path(tmp) / f"{name}.kdl").write_text(text)
            (Path(tmp) / "config.kdl").write_text('include "look.kdl"\ninclude "effects.kdl"\ninclude "animations.kdl"\n')
            r = subprocess.run(["niri", "validate", "-c", str(Path(tmp) / "config.kdl")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr[-800:])


if __name__ == "__main__":
    unittest.main()


class GtkTheme(unittest.TestCase):
    def test_adw_gtk3_when_installed(self):
        with tempfile.TemporaryDirectory() as tmp:
            themes = Path(tmp)
            self.assertEqual(vt.gtk_theme_name("dark", themes), "Adwaita")
            (themes / "adw-gtk3").mkdir(); (themes / "adw-gtk3-dark").mkdir()
            self.assertEqual(vt.gtk_theme_name("dark", themes), "adw-gtk3-dark")
            self.assertEqual(vt.gtk_theme_name("light", themes), "adw-gtk3")

    def test_ini_rewritten_in_place(self):
        with tempfile.TemporaryDirectory() as tmp:
            cfg = Path(tmp)
            (cfg / "gtk-4.0").mkdir()
            ini = cfg / "gtk-4.0/settings.ini"
            ini.write_text("[Settings]\ngtk-theme-name=Adwaita\ngtk-font-name=Inter 11\n")
            vt.set_gtk_theme_ini("adw-gtk3-dark", cfg)
            self.assertEqual(ini.read_text(), "[Settings]\ngtk-theme-name=adw-gtk3-dark\ngtk-font-name=Inter 11\n")
            self.assertFalse((cfg / "gtk-3.0/settings.ini").exists())


    def test_gtk_off_touches_only_the_colour_scheme(self):
        with mock.patch.object(vt.subprocess, "run") as run, mock.patch.object(vt, "set_gtk_theme_ini") as ini:
            vt.set_color_scheme("dark", gtk=False)
        keys = [c.args[0][3] for c in run.call_args_list]
        self.assertEqual(keys, ["color-scheme"])
        ini.assert_not_called()

class Cli(unittest.TestCase):
    def run_cli(self, tmp, *extra):
        env = dict(os.environ, PATH=os.environ["PATH"])
        args = [sys.executable, str(ROOT / "tools" / "vitrum-theme"),
                "--settings", str(Path(tmp) / "settings.json"),
                "--out-palette", str(Path(tmp) / "palette.json"),
                "--niri-dir", str(Path(tmp) / "gen"), "--no-color-scheme", *extra]
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def test_dry_run_writes_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            write(tmp, "settings.json", {"palette": {"source": "preset"}})
            r = self.run_cli(tmp, "--dry-run")
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertFalse((Path(tmp) / "palette.json").exists())
            self.assertFalse((Path(tmp) / "gen").exists())
            self.assertIn("would write", r.stdout)

    def test_writes_all_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            write(tmp, "settings.json", {"palette": {"source": "preset", "preset": "ink"}})
            r = self.run_cli(tmp)
            self.assertEqual(r.returncode, 0, r.stderr)
            pal = json.loads((Path(tmp) / "palette.json").read_text())
            self.assertIn("dark", pal["palette"])
            self.assertEqual(pal["source"], "preset ink")
            for f in ("look", "effects", "animations"):
                self.assertTrue((Path(tmp) / "gen" / f"{f}.kdl").is_file())
            r2 = self.run_cli(tmp)
            self.assertIn("nothing changed", r2.stdout)
