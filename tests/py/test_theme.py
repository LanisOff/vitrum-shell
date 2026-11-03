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
        self.assertEqual(s["materials"]["groups"], {"bar": "solid", "lock": "glass", "launcher": "glass", "widgets": "glass", "dock": "glass"})

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

    def test_accent2_is_the_accent_turned(self):
        # Dichroic glass: the accent's hue + look.dichroic.shift (−100 by
        # default), saturation 0.72, lightness 0.74 dark / 0.42 light — the
        # same maths as shell/lib/color.js dichroic().
        import colorsys
        def hls(c):
            return colorsys.rgb_to_hls(*(int(c[i:i + 2], 16) / 255 for i in (1, 3, 5)))
        pink = "#f2b3e7"
        h0 = hls(pink)[0]
        for dark, light in ((True, 0.74), (False, 0.42)):
            h, l, s = hls(vt.accent2(pink, -100, dark))
            self.assertAlmostEqual(((h - h0) * 360) % 360, 260, delta=1.5)
            self.assertAlmostEqual(l, light, delta=0.01)
            self.assertAlmostEqual(s, 0.72, delta=0.02)
        # a grey accent counts as hue 0
        self.assertEqual(vt.accent2("#808080", -100, True), vt.accent2("#ff0000", -100, True))
        self.assertEqual(vt.dichroic_shift({}), -100.0)
        self.assertEqual(vt.dichroic_shift({"look": {"dichroic": {"shift": 40}}}), 40.0)
        self.assertEqual(vt.dichroic_shift({"look": {"dichroic": {"shift": 999}}}), 180.0)
        for bad in ("50", True, None, float("nan")):
            self.assertEqual(vt.dichroic_shift({"look": {"dichroic": {"shift": bad}}}), -100.0)

    def test_palette_carries_accent2_in_both_schemes(self):
        s, _ = vt.load_settings(Path("/nonexistent"))
        s["look"] = {"dichroic": {"shift": 60}}
        p, _ = vt.resolve_palette(s, None)
        for scheme in ("dark", "light"):
            self.assertEqual(p[scheme]["accent2"], vt.accent2(p[scheme]["accent"], 60, scheme == "dark"))

    def test_missing_wallpaper_falls_back_to_preset(self):
        s, _ = vt.load_settings(Path("/nonexistent"))
        s["palette"]["source"] = "wallpaper"
        p, note = vt.resolve_palette(s, Path("/no/such/wallpaper.png"))
        self.assertEqual(p, vt.with_accent2(vt.guard(vt.palette_from_preset(s["palette"]["preset"])), s))
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

    def test_window_material_app_ids_match_exactly_and_stay_valid_kdl(self):
        s = self.settings(windows__materials=[{"appId": "org.kde.dolphin", "material": "glass"},
                                              {"appId": 'foo(bar"', "material": "clear"}])
        k = vt.effects_kdl(s)
        self.assertIn('app-id="^org\\\\.kde\\\\.dolphin$"', k)
        self.assertIn('app-id="^foo\\\\(bar\\"$"', k)

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
        dock = k.split('match namespace="^vitrum-dock$"')[1].split("layer-rule")[0]
        self.assertIn("refraction-strength 3", dock)
        self.assertIn('match app-id="^kitty$"', k)

    def test_shaped_glass_on_the_bar(self):
        # A niri with shaped glass: the bar's pieces are rounded by niri and melt
        # into a drop with its panel.
        s = self.settings(materials__groups={"bar": "glass"}, density="regular")
        k = vt.effects_kdl(s, caps={"shapedGlass": True})
        bar = k.split('match namespace="^vitrum-bar$"')[1].split("layer-rule")[0]
        self.assertIn("geometry-corner-radius 11", bar)
        self.assertIn("shape-fillet 11.0", bar)
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
        # Glass on the launcher: its search field, category buttons and results
        # melt into one drop too, every piece rounded like a tile (radiusLauncher).
        for density, r in (("compact", 12), ("regular", 13), ("comfortable", 14)):
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
        # Tokens.radiusIsland: 10 at compact, scaled like the panel radius.
        for density, r in (("compact", 10), ("regular", 11), ("comfortable", 12)):
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
            self.assertTrue(caps["ownGlass"])
            self.assertEqual(calls[0][1:3], ["validate", "-c"])
            probed = len(calls)
            vt.niri_caps(niri=str(niri), run=run, cache=Path(tmp) / "c")
            self.assertEqual(len(calls), probed, "cached")
            def fail(cmd, **kw):
                class R: returncode = 1
                return R()
            gone = vt.niri_caps(niri=str(Path(tmp) / "missing"), run=fail, cache=Path(tmp) / "d")
            self.assertFalse(gone["shapedGlass"])
            self.assertFalse(gone["ownGlass"])

    def test_niri_caps_tell_the_old_niri_from_ours(self):
        # An older build knows shape-fillet but not sheen.
        def run(cmd, **kw):
            class R: returncode = 1 if "sheen" in Path(cmd[3]).read_text() else 0
            return R()
        with tempfile.TemporaryDirectory() as tmp:
            niri = Path(tmp) / "niri"; niri.write_text("#!/bin/sh\n")
            caps = vt.niri_caps(niri=str(niri), run=run, cache=Path(tmp) / "c")
        self.assertEqual(caps, {"shapedGlass": True, "ownGlass": False})

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

    def outside_the_session(self, tmp, exes):
        """ssh or a tty: no NIRI_SOCKET, the runtime folder holds a socket per
        pid in exes ({pid: its /proc/PID/exe, or None when it is gone}), and
        a new niri on disk that accepts everything."""
        for pid in exes:
            (Path(tmp) / f"niri.wayland-1.{pid}.sock").touch()
        disk = Path(tmp) / "disk-niri"; disk.write_text("#!/bin/sh\n")
        real_stat = os.stat
        class St: st_mtime = 1; st_size = 2
        def stat(path, *a, **kw):
            return St() if re.fullmatch(r"/proc/\d+/exe", str(path)) else real_stat(path, *a, **kw)
        def readlink(path):
            exe = exes.get(int(path.split("/")[2]))
            if exe is None:
                raise FileNotFoundError(path)
            return exe
        env = {k: v for k, v in os.environ.items() if k != "NIRI_SOCKET"}
        env["XDG_RUNTIME_DIR"] = tmp
        return disk, (mock.patch.dict(os.environ, env, clear=True),
                      mock.patch.object(vt.os, "readlink", side_effect=readlink),
                      mock.patch.object(vt.os, "stat", side_effect=stat))

    def test_niri_caps_find_the_session_from_outside_it(self):
        # vitrum update over ssh: the session's niri is older than the one on disk
        # and would refuse what the new one accepts, until the next login.
        def old_niri(cmd, **kw):
            class R: returncode = 1 if "/proc/" in cmd[0] and "sheen" in Path(cmd[3]).read_text() else 0
            return R()
        with tempfile.TemporaryDirectory() as tmp:
            disk, patches = self.outside_the_session(tmp, {4242: "/usr/local/bin/niri (deleted)"})
            with patches[0], patches[1], patches[2], mock.patch("shutil.which", return_value=str(disk)):
                caps = vt.niri_caps(run=old_niri, cache=Path(tmp) / "c")
                self.assertEqual(caps, {"shapedGlass": True, "ownGlass": False})
                self.assertNotIn("sheen", vt.effects_kdl(self.settings(materials__groups={"bar": "glass"}), caps))

    def test_niri_caps_conservative_when_a_replaced_niri_cannot_be_asked(self):
        def gone(cmd, **kw):
            raise PermissionError(cmd[0])
        with tempfile.TemporaryDirectory() as tmp:
            disk, patches = self.outside_the_session(tmp, {4242: "/usr/local/bin/niri (deleted)"})
            with patches[0], patches[1], patches[2], mock.patch("shutil.which", return_value=str(disk)):
                self.assertEqual(vt.niri_caps(run=gone, cache=Path(tmp) / "c"),
                                 {"shapedGlass": False, "ownGlass": False})

    def test_session_socket_skips_what_is_not_a_running_niri(self):
        # A crash leaves the socket behind, and its pid can come round again.
        with tempfile.TemporaryDirectory() as tmp:
            _, patches = self.outside_the_session(tmp, {11: None, 22: "/usr/bin/bash"})
            with patches[0], patches[1], patches[2]:
                self.assertIsNone(vt.session_socket())

    def test_session_socket_prefers_the_sessions_niri_over_a_nested_one(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, patches = self.outside_the_session(tmp, {50: "/usr/local/bin/niri", 60: "/usr/local/bin/niri"})
            os.utime(Path(tmp) / "niri.wayland-1.60.sock", (1, 1))     # the older one
            with patches[0], patches[1], patches[2]:
                self.assertEqual(vt.session_socket(), str(Path(tmp) / "niri.wayland-1.60.sock"))

    def test_session_socket_ignores_a_dead_niri_socket_variable(self):
        # A tmux from an earlier login keeps that session's variable.
        with tempfile.TemporaryDirectory() as tmp:
            _, patches = self.outside_the_session(tmp, {70: "/usr/local/bin/niri"})
            with patches[0], patches[1], patches[2]:
                os.environ["NIRI_SOCKET"] = str(Path(tmp) / "niri.wayland-1.9.sock")
                self.assertEqual(vt.session_socket(), str(Path(tmp) / "niri.wayland-1.70.sock"))
                os.environ["NIRI_SOCKET"] = str(Path(tmp) / "niri.wayland-1.70.sock")
                self.assertEqual(vt.session_socket(), str(Path(tmp) / "niri.wayland-1.70.sock"))

    def test_window_glass_is_weaker_than_the_shells(self):
        # The user's call: a window's edge is felt, not looked at. Less bend, a
        # thinner bevel and a quieter rim than the panels', more dimming under the text.
        s = self.settings(materials__glassPreset="lens", windows__materials=[{"appId": "kitty", "material": "glass"}])
        kdl = vt.effects_kdl(s)
        rule = kdl[kdl.index('match app-id="^kitty$"'):]
        lens = dict(zip(vt.GLASS_KEYS, vt.GLASS_PRESETS["lens"]))
        val = lambda k: float(re.search(rf"{k} ([0-9.]+)", rule).group(1))
        self.assertLess(val("refraction-strength"), lens["refraction-strength"])
        self.assertLess(val("edge-thickness"), lens["edge-thickness"])
        self.assertLess(val("glow-weight"), lens["glow-weight"])
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
        self.assertGreater(val(rule, "adaptive-dim"), val(g, "adaptive-dim"), "dimming does the blur's work")

    def launcher(self, caps=None, **kw):
        s = self.settings(materials__groups={"bar": "glass", "launcher": "glass"}, **kw)
        return vt.effects_kdl(s, caps=caps).split('match namespace="^vitrum-launcher$"')[1].split("layer-rule")[0]

    def test_the_launcher_is_nearly_clear_glass(self):
        # The user's call: fully frosted it "looks like blur and only slightly like
        # glass", fully clear it was too transparent. Legible from dimming, a real
        # blur strength for the matte, never grain.
        own = {"shapedGlass": True, "ownGlass": True}
        rule = self.launcher(own)
        val = lambda k: float(re.search(rf"{k} ([0-9.]+)", rule).group(1))
        self.assertIn("blur true", rule)
        self.assertEqual(val("blur-amount"), 0.2)
        self.assertEqual(val("noise"), 0.0)
        self.assertEqual(val("refraction-strength"), 5.0)
        self.assertEqual(val("adaptive-dim"), 0.42)
        self.assertEqual(val("vibrancy"), 0.45)
        self.assertIn("saturation 1.0", rule.split("liquid-glass")[1], "the glass's own")
        self.assertIn("    saturation 1.25\n", rule.split("liquid-glass")[0], "niri's own, under the neon of its 1.5")
        frosted = vt.effects_kdl(self.settings(materials__groups={"launcher": "frosted"}), caps=own)
        self.assertNotIn("liquid-glass", frosted.split('match namespace="^vitrum-launcher$"')[1].split("layer-rule")[0])

    def test_the_launcher_without_frost_or_our_niri_stays_clear(self):
        own = {"shapedGlass": True, "ownGlass": True}
        with mock.patch.object(vt, "LAUNCHER_FROST", 0.0):
            rule = self.launcher(own)
            self.assertIn("blur false", rule)
            self.assertNotIn("blur-amount", rule)
            self.assertNotIn("saturation", rule.split("liquid-glass")[0])
        # A niri that has no such key gets none, and all-or-nothing blur means clear.
        rule = self.launcher({"shapedGlass": True})
        self.assertIn("blur false", rule)
        self.assertNotIn("blur-amount", rule)
        self.assertIn("blur false", self.launcher(), "and on a niri without shapes")

    def rule(self, group, kdl):
        return kdl.split(f'match namespace="^vitrum-{group}$"')[1].split("layer-rule")[0]

    def test_the_bars_islands_keep_their_approved_look(self):
        # The user approved them bevelled, with a soft second contour. Every other
        # surface has no inner rim, and a panel on the bar's surface goes by its size.
        own = {"shapedGlass": True, "ownGlass": True}
        s = self.settings(materials__groups={"bar": "glass", "dock": "glass"})
        k = vt.effects_kdl(s, caps=own)
        bar, dock = self.rule("bar", k), self.rule("dock", k)
        self.assertIn("inner-rim 0.6", bar)
        self.assertIn("glow-weight 1.0", bar)
        self.assertIn(f"blur-amount {vt.BAR_BLUR}", bar)
        self.assertIn("inner-rim 0.0", dock)
        self.assertIn(f"blur-amount {vt.GLASS_BLUR}", dock)

    def test_the_body_has_life_and_the_rim_takes_the_backdrops_hue(self):
        # One hue from the backdrop, in every preset; never a split.
        at = vt.GLASS_KEYS.index("edge-lighting")
        for name, values in vt.GLASS_PRESETS.items():
            self.assertGreater(values[at], 0.0, name)
            self.assertGreater(vt.GLASS_BODY[name]["vibrancy"], 0.0, name)
            self.assertGreater(vt.GLASS_BODY[name]["sheen"], 0.0, name)
        kdl = vt.effects_kdl(self.settings(materials__default="glass"), caps={"shapedGlass": True, "ownGlass": True})
        self.assertNotIn("fringing", kdl)

    def test_widgets_and_the_dock_are_shaped_glass(self):
        # Both have surfaces bigger than their glass (the widgets a whole screen):
        # without pieces the glass would be that surface, with no rim on the widgets.
        for density, panel, widget in (("compact", 20, 25), ("regular", 22, 28), ("comfortable", 24, 30)):
            s = self.settings(materials__groups={"widgets": "glass", "dock": "glass"}, density=density)
            k = vt.effects_kdl(s, caps={"shapedGlass": True, "ownGlass": True})
            self.assertIn(f"geometry-corner-radius {widget}", self.rule("widgets", k))
            self.assertIn(f"shape-fillet {float(widget)}", self.rule("widgets", k))
            self.assertIn(f"geometry-corner-radius {panel}", self.rule("dock", k))
            self.assertIn(f"shape-fillet {float(panel)}", self.rule("dock", k))
        self.assertNotIn("shape-fillet", self.rule("dock", vt.effects_kdl(self.settings(materials__groups={"dock": "frosted"}), caps={"shapedGlass": True})))

    def test_widget_text_is_read_through_dimming_under_the_rim(self):
        k = vt.effects_kdl(self.settings(materials__groups={"widgets": "glass", "dock": "glass"}), caps={"shapedGlass": True, "ownGlass": True})
        self.assertIn("adaptive-dim 0.6", self.rule("widgets", k))
        self.assertNotIn("adaptive-dim 0.6", self.rule("dock", k))

    def test_new_defaults_reach_only_who_chose_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "settings.json"
            p.write_text(json.dumps({"materials": {"groups": {"bar": "solid", "widgets": "frosted", "dock": ""}}}))
            g = vt.load_settings(p)[0]["materials"]["groups"]
            self.assertEqual(g["widgets"], "frosted", "an explicit choice stays")
            self.assertEqual(g["dock"], "", '"Default" is a choice too')
            self.assertEqual(g["launcher"], "glass", "unset follows the default")
            p.write_text(json.dumps({"materials": {"groups": {"bar": "glass"}}}))
            g = vt.load_settings(p)[0]["materials"]["groups"]
            self.assertEqual((g["widgets"], g["dock"]), ("glass", "glass"))

    def test_only_keys_niri_knows_reach_it(self):
        # niri refuses a whole config over one unknown key, so an old setting
        # must not get through; neither must what only the other niri knows.
        old = {"fringing": 0.3, "power-factor": 2.2, "lens-distortion": 0.9, "brightness": 1.1, "refraction-strength": 2.0}
        s = self.settings(materials__default="glass", materials__glassAdvanced=old,
                          windows__materials=[{"appId": "kitty", "material": "glass"}])
        ours = vt.effects_kdl(s, caps={"shapedGlass": True, "ownGlass": True})
        for key in ("fringing", "power-factor", "lens-distortion", "brightness", "physical-refraction"):
            self.assertNotIn(key, ours)
        self.assertIn("refraction-strength 2", ours, "a slider's value still counts")
        self.assertIn("sheen", ours)
        # An older niri, until the next login: no new keys, and told not to split colours.
        before = vt.effects_kdl(s, caps={"shapedGlass": True})
        for key in ("inner-rim", "blur-amount", "sheen", "vibrancy"):
            self.assertNotIn(key, before)
        self.assertIn("fringing 0.0", before)

    def test_window_glass_glows_less_than_a_panel(self):
        # A window's long edge is where colour reads as a line: its glow stays below
        # a panel's, and it's the backdrop's one hue, with no split.
        val = lambda r, k: float(re.search(rf"{k} ([0-9.]+)", r).group(1))
        lens = dict(zip(vt.GLASS_KEYS, vt.GLASS_PRESETS["lens"]))
        for material in ("glass", "clear"):
            s = self.settings(windows__materials=[{"appId": "kitty", "material": material}])
            rule = vt.effects_kdl(s, caps={"shapedGlass": True, "ownGlass": True}).split('match app-id="^kitty$"')[1]
            self.assertLess(val(rule, "edge-lighting"), lens["edge-lighting"], material)
            self.assertNotIn("fringing", rule)

    def test_vitrum_apps_stay_opaque(self):
        # Settings, Disk Utility, About: forms to read, never faded when unfocused;
        # after the unfocused rule, so it wins.
        look = vt.look_kdl(self.settings(), vt.palette_from_preset("graphite"), "dark")
        rule = 'match app-id=r#"^vitrum-(settings|disks|about)$"#'
        self.assertIn(rule, look)
        self.assertGreater(look.index(rule), look.index("match is-focused=false"))
        self.assertIn("opacity 1.0", look[look.index(rule):].split("}")[0])

    def test_steam_toasts_sit_bottom_right(self):
        # Steam's notification toasts are windows titled notificationtoasts_N_…;
        # niri would float them in the middle. Bottom-right, no focus, not dimmed
        # (after the unfocused rule, so it wins), the card's radius.
        look = vt.look_kdl(self.settings(), vt.palette_from_preset("graphite"), "dark")
        match = 'match app-id="^steam$" title="^notificationtoasts_"'
        self.assertIn(match, look)
        self.assertGreater(look.index(match), look.index("match is-focused=false"))
        rule = look[look.index(match):].split("}")[0]
        for line in ("open-floating true", "open-focused false",
                     'default-floating-position x=24 y=24 relative-to="bottom-right"',
                     "geometry-corner-radius 12", "opacity 1.0"):
            self.assertIn(line, rule)

    def test_games_get_vrr_with_the_users_list(self):
        # The same games as the shell's game mode: Steam, gamescope and games.extra
        # (substrings of the app id or title, any case), escaped for the regex and KDL.
        pal = vt.palette_from_preset("graphite")
        look = vt.look_kdl(self.settings(games__extra=["Minecraft", 'a.b"c', " "]), pal, "dark")
        rule = look.split('match app-id="^steam_app_[0-9]+$"')[1].split("}")[0]
        self.assertIn('match app-id="(?i)Minecraft"', rule)
        self.assertIn('match title="(?i)Minecraft"', rule)
        self.assertIn('match title="(?i)a\\\\.b\\"c"', rule)
        self.assertIn("variable-refresh-rate true", rule)
        self.assertIn("opacity 1.0", rule, "not see-through beside a focused window")
        self.assertEqual(rule.count("match"), 5, "a blank entry adds nothing")

    def test_glass_advanced_overrides(self):
        s = self.settings(materials__default="glass", materials__glassAdvanced={"refraction-strength": 9.5})
        self.assertIn("refraction-strength 9.5", vt.effects_kdl(s))

    def test_animations_reduce_and_speed(self):
        self.assertIn("off", vt.animations_kdl(self.settings(motion__reduce=True)))
        self.assertIn("slowdown 0.5", vt.animations_kdl(self.settings(motion__speed=2.0)))
        # Every spring niri gets is critically damped (no bounce), as the shell's.
        self.assertNotRegex(vt.animations_kdl(self.settings()), r"damping-ratio=0\.")
        self.assertEqual(vt.SPRINGS, {"snappy": (1.0, 900), "smooth": (1.0, 600)})
        # KDL: a float property must be written as a float (1.0, not 1)
        self.assertIn("damping-ratio=1.0 stiffness=900", vt.animations_kdl(self.settings()))
        self.assertNotRegex(vt.animations_kdl(self.settings()), r"damping-ratio=\d+ ")
        self.assertIn("opacity 1.0", vt.look_kdl(self.settings(windows__unfocusedOpacity=1), vt.guard(vt.palette_from_preset("graphite")), "dark"))

    def test_look_focus_modes(self):
        pal = vt.guard(vt.palette_from_preset("graphite"))
        self.assertIn("opacity 0.92", vt.look_kdl(self.settings(), pal, "dark"))
        self.assertIn("relative-to=\"workspace-view\"", vt.look_kdl(self.settings(windows__focus="gradient"), pal, "dark"))
        # The gradient ring is dichroic: accent → accent2 (from the palette, or
        # computed when a palette has none).
        grad = vt.look_kdl(self.settings(windows__focus="gradient"), vt.with_accent2(pal, self.settings()), "dark")
        a2 = vt.accent2(pal["dark"]["accent"], -100, True)
        self.assertIn(f'active-gradient from="{pal["dark"]["accent"]}" to="{a2}"', grad)
        self.assertIn(f'to="{a2}"', vt.look_kdl(self.settings(windows__focus="gradient"), pal, "dark"))
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

    def test_adw_gtk3_from_the_user_themes(self):
        """Void has no package: the installer unpacks it into ~/.local/share/themes."""
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "themes" / "adw-gtk3-dark").mkdir(parents=True)
            old = os.environ.get("XDG_DATA_HOME")
            os.environ["XDG_DATA_HOME"] = tmp
            try:
                self.assertEqual(vt.gtk_theme_name("dark"), "adw-gtk3-dark")
            finally:
                if old is None: del os.environ["XDG_DATA_HOME"]
                else: os.environ["XDG_DATA_HOME"] = old

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


class BindsAndInput(unittest.TestCase):
    """Settings → keybinds / mouse: vitrum-theme writes niri's binds.kdl and input.kdl."""

    def catalogue(self):
        import subprocess, json as _j
        with tempfile.TemporaryDirectory() as tmp:
            kdl, js = Path(tmp) / "b.kdl", Path(tmp) / "b.json"
            subprocess.run([sys.executable, str(ROOT / "lib/keybinds.py"), str(ROOT / "KEYBINDS.md"), str(kdl), str(js)],
                           check=True, capture_output=True)
            return _j.loads(js.read_text()), kdl.read_text()

    def lines(self, text):
        return [l for l in text.splitlines() if re.match(r"^\s{4}\S", l)]

    def keys(self, text):
        return [l.split()[0].lower() for l in self.lines(text)]

    def settings(self, changes=None, own=None, inp=None):
        return {"keybinds": {"changes": changes or {}, "own": own or []}, "input": inp or {}}

    def test_no_changes_is_the_installers_keymap(self):
        from vitrum_theme import niri_input as N
        cat, kdl = self.catalogue()
        self.assertEqual(sorted(self.lines(N.binds_kdl(cat, self.settings()))), sorted(self.lines(kdl)))

    def test_rebind_turn_off_and_unknown(self):
        from vitrum_theme import niri_input as N
        cat, _ = self.catalogue()
        out = N.binds_kdl(cat, self.settings({"Mod+Space": "Mod+Alt+Space", "Mod+N": None, "Mod+Nope": "Mod+X"}))
        launcher = next(l for l in self.lines(out) if '"launcher" "toggle"' in l)
        self.assertTrue(launcher.strip().startswith("Mod+Alt+Space "))
        self.assertNotIn("mod+n", self.keys(out))
        self.assertNotIn("mod+x", self.keys(out))

    def test_never_a_duplicate_key(self):
        from vitrum_theme import niri_input as N
        cat, _ = self.catalogue()
        # A change onto another bind's keys, and an own bind on a vitrum key (both by hand).
        out = N.binds_kdl(cat, self.settings({"Mod+Space": "Mod+N"},
                                             [{"keys": "Mod+Q", "command": "foot", "title": "Foot"},
                                              {"keys": "mod+q", "command": "kitty", "title": "Kitty"}]))
        ks = self.keys(out)
        self.assertEqual(len(ks), len(set(ks)))
        self.assertIn('"launcher" "toggle"', next(l for l in self.lines(out) if l.strip().lower().startswith("mod+n ")))
        q = next(l for l in self.lines(out) if l.strip().lower().startswith("mod+q "))
        self.assertIn('spawn-sh "kitty"', q)

    def test_own_bind_quoting_and_malformed(self):
        from vitrum_theme import niri_input as N
        cat, _ = self.catalogue()
        out = N.binds_kdl(cat, self.settings(own=[
            {"keys": "Mod+Shift+B", "command": 'notify-send "hi \\\\ there"', "title": 'Say "hi"'},
            {"keys": "", "command": "x"}, {"keys": "Mod+Shift+Y", "command": ""}, "junk"]))
        b = next(l for l in self.lines(out) if l.strip().startswith("Mod+Shift+B "))
        self.assertIn('hotkey-overlay-title="Say \\"hi\\""', b)
        self.assertIn('spawn-sh "notify-send \\"hi \\\\\\\\ there\\""', b)
        self.assertNotIn("mod+shift+y", self.keys(out))

    def test_input_defaults_match_todays_config(self):
        from vitrum_theme import niri_input as N
        out = N.input_kdl(vt.load_settings(Path("/nonexistent"))[0])
        self.assertIn('mouse {\n        accel-profile "flat"\n        accel-speed 0.00\n        scroll-factor 1.00\n    }', out)
        for line in ("tap", "dwt", "natural-scroll", 'accel-profile "adaptive"', "accel-speed 0.25",
                     'scroll-method "two-finger"', 'click-method "clickfinger"'):
            self.assertIn("        " + line + "\n", out.split("touchpad {")[1])

    def test_input_values_and_clamping(self):
        from vitrum_theme import niri_input as N
        out = N.input_kdl({"input": {"mouse": {"speed": 3, "accel": True, "scroll": 0, "natural": True},
                                     "touchpad": {"speed": -2, "natural": False, "tap": False}}})
        mouse, pad = out.split("touchpad {")
        self.assertIn('accel-profile "adaptive"', mouse); self.assertIn("accel-speed 1.00", mouse)
        self.assertIn("scroll-factor 0.10", mouse); self.assertIn("natural-scroll", mouse)
        self.assertIn("accel-speed -1.00", pad)
        self.assertNotIn("natural-scroll", pad); self.assertNotIn("        tap\n", pad)

    # Settings → Keyboard → Layouts. niri replaces a whole included xkb block, so
    # the generated one carries config.kdl's options (the switching keys).
    CONFIG_XKB = (
        'input {\n    keyboard {\n        // xkb { layout "fr" }\n        xkb {\n'
        '            layout "us,ru"\n            options "grp:alt_shift_toggle,compose:ralt"\n        }\n'
        '        repeat-delay 400\n    }\n}\n')

    def test_no_layouts_leaves_config_kdl_alone(self):
        from vitrum_theme import niri_input as N
        out = N.input_kdl(vt.load_settings(Path("/nonexistent"))[0], N.xkb_from_kdl(self.CONFIG_XKB))
        self.assertNotIn("keyboard", out)
        self.assertNotIn("xkb", out)

    def test_layouts_reach_niri_with_configs_options(self):
        from vitrum_theme import niri_input as N
        out = N.input_kdl({"keyboard": {"layouts": ["us", "ru", "de"]}}, N.xkb_from_kdl(self.CONFIG_XKB))
        self.assertIn('    keyboard {\n        xkb {\n            layout "us,ru,de"\n'
                      '            options "grp:alt_shift_toggle,compose:ralt"\n        }\n    }\n', out)
        self.assertNotIn("variant", out)
        self.assertIn("mouse {", out)   # the pointer sections stay

    def test_layout_variants_and_cleaning(self):
        from vitrum_theme import niri_input as N
        out = N.input_kdl({"keyboard": {"layouts": ["us", "de(nodeadkeys)", 'x"; spawn', 7, "us", "ru", "fr", "it"]}}, None)
        self.assertIn('layout "us,de,ru,fr"', out)
        self.assertIn('variant ",nodeadkeys,,"', out)
        self.assertNotIn("options", out)
        self.assertNotIn("spawn", out)

    def test_xkb_from_kdl(self):
        from vitrum_theme import niri_input as N
        self.assertEqual(N.xkb_from_kdl(self.CONFIG_XKB), {"layout": "us,ru", "options": "grp:alt_shift_toggle,compose:ralt"})
        self.assertIsNone(N.xkb_from_kdl("input { }"))
        self.assertIsNone(N.xkb_from_kdl('/* xkb { layout "fr" } */'))
        with_model = N.xkb_from_kdl('xkb {\n model "pc105"\n layout "us"\n}')
        self.assertEqual(N.keyboard_kdl({"keyboard": {"layouts": ["de"]}}, with_model).count('model "pc105"'), 1)

    def test_layouts_setting_loads_without_warnings(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "s.json"
            p.write_text(json.dumps({"keyboard": {"layouts": ["us", "de(nodeadkeys)"]}}))
            s, warnings = vt.load_settings(p)
            self.assertEqual(warnings, [])
            self.assertEqual(s["keyboard"], {"perApp": True, "layouts": ["us", "de(nodeadkeys)"]})

    def test_settings_types_survive_load(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "s.json"
            p.write_text(json.dumps({"keybinds": {"changes": {"Mod+N": None, "Mod+T": "Mod+Y"}, "own": []},
                                     "input": {"mouse": {"speed": 0}}}))
            s, warnings = vt.load_settings(p)
            self.assertEqual(warnings, [])
            self.assertEqual(s["keybinds"]["changes"], {"Mod+N": None, "Mod+T": "Mod+Y"})
            self.assertEqual(s["input"]["mouse"]["speed"], 0)

    def test_missing_catalogue_is_none(self):
        from vitrum_theme import niri_input as N
        self.assertIsNone(N.load_catalogue(Path("/nonexistent/binds.json")))

    def test_invalid_keys_never_reach_niri(self):
        from vitrum_theme import niri_input as N
        cat, _ = self.catalogue()
        out = N.binds_kdl(cat, self.settings({"Mod+Space": "Mod + X", "Mod+T": "  "},
                                             [{"keys": "Mod+{", "command": "x"}, {"keys": "Mod+Shift+Y z", "command": "x"}]))
        launcher = next(l for l in self.lines(out) if '"launcher" "toggle"' in l)
        self.assertTrue(launcher.strip().startswith("Mod+Space "))
        self.assertIn("mod+t", self.keys(out))
        self.assertNotIn("Mod+{", out)
        self.assertNotIn("mod+shift+y", self.keys(out))

    def test_old_format_or_empty_catalogue_is_none(self):
        from vitrum_theme import niri_input as N
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "b.json"
            p.write_text(json.dumps([{"section": "A", "keys": "Mod+Q", "action": "x", "kind": "k", "title": "Q"}]))
            self.assertIsNone(N.load_catalogue(p))
            p.write_text("[]")
            self.assertIsNone(N.load_catalogue(p))
            p.write_text(json.dumps([{"keys": "Mod+Q", "kdl": "{ close-window; }"}, {"hidden": True, "keys": "Mod+Z"}]))
            self.assertIsNotNone(N.load_catalogue(p))

    def test_canonical_keys(self):
        from vitrum_theme import niri_input as N
        self.assertEqual(N.canonical_keys("Control+Alt+Y"), "Ctrl+Alt+Y")
        self.assertEqual(N.canonical_keys(" shift+mod+q "), "Mod+Shift+q")
        self.assertEqual(N.canonical_keys("Win+Ctrl+Slash"), "Super+Ctrl+Slash")
        self.assertEqual(N.canonical_keys("XF86AudioRaiseVolume"), "XF86AudioRaiseVolume")
        for bad in ("Mod+", "+Q", "Mod++Q", "", "Foo+Q", "Mod+Mod+Q", "Mod+Shift+Y z", "Mod+{"):
            self.assertIsNone(N.canonical_keys(bad), bad)

    def test_catalogue_keys_are_canonical(self):
        from vitrum_theme import niri_input as N
        cat, _ = self.catalogue()
        for b in cat:
            if b.get("keys"):
                self.assertEqual(N.canonical_keys(b["keys"]), b["keys"])

    def test_alias_spellings_never_duplicate(self):
        from vitrum_theme import niri_input as N
        cat, _ = self.catalogue()
        out = N.binds_kdl(cat, self.settings({"Mod+Space": "Control+Alt+Y"},
                                             [{"keys": "Shift+Mod+Q", "command": "foot", "title": "F"},
                                              {"keys": "Mod+", "command": "x"}, {"keys": "+Q", "command": "x"},
                                              {"keys": "Mod++Q", "command": "x"}]))
        ks = self.keys(out)
        self.assertEqual(len(ks), len(set(ks)))
        self.assertIn("ctrl+alt+y", ks)
        self.assertNotIn("control+alt+y", ks)
        self.assertIn('spawn-sh "foot"', next(l for l in self.lines(out) if l.strip().startswith("Mod+Shift+Q ")))
        self.assertNotIn("Mod+ ", out)
        self.assertNotIn("+Q ", out.replace("Shift+Q ", "").replace("Mod+Q ", ""))



class CursorTheme(unittest.TestCase):
    """Settings → Fonts & icons → Cursor theme reaches GTK's settings.ini too."""

    def test_rewrites_the_cursor_line_in_both_settings_ini(self):
        import tempfile
        from unittest import mock
        with tempfile.TemporaryDirectory() as t, mock.patch("subprocess.run"):
            cfg = Path(t)
            for v in ("gtk-3.0", "gtk-4.0"):
                (cfg / v).mkdir()
                (cfg / v / "settings.ini").write_text("[Settings]\ngtk-cursor-theme-name=Adwaita\ngtk-cursor-theme-size=24\n")
            vt.set_cursor_theme("Bibata-Modern-Ice", config=cfg)
            for v in ("gtk-3.0", "gtk-4.0"):
                text = (cfg / v / "settings.ini").read_text()
                self.assertIn("gtk-cursor-theme-name=Bibata-Modern-Ice", text)
                self.assertIn("gtk-cursor-theme-size=24", text)


class LiteMode(unittest.TestCase):
    """Settings → Lite mode: what reaches niri through effects, look and animations."""

    def settings(self, **lite):
        s, _ = vt.load_settings(Path("/nonexistent"))
        auto = lite.pop("auto", None)
        s["lite"].update(lite)
        if auto:
            s["lite"]["auto"].update(auto)
        return s

    def layer(self, kdl, group):
        return kdl.split(f'match namespace="^vitrum-{group}$"')[1].split("layer-rule")[0]

    def test_defaults_cut_nothing(self):
        f = vt.lite_flags(self.settings())
        self.assertEqual(set(f), set(vt.LITE_PARTS) | {"active"})
        self.assertFalse(any(f.values()))
        s = self.settings()
        pal = vt.guard(vt.palette_from_preset("graphite"))
        # Off, the files are exactly what they were without lite mode.
        self.assertEqual(vt.effects_kdl(s, None, f).replace(", lite", ""), vt.effects_kdl(s).replace(", lite", ""))
        self.assertEqual(vt.look_kdl(s, pal, "dark", f), vt.look_kdl(s, pal, "dark"))
        self.assertEqual(vt.animations_kdl(s, f), vt.animations_kdl(s))

    def test_master_switch_cuts_everything(self):
        f = vt.lite_flags(self.settings(enabled=True))
        self.assertTrue(all(f.values()))

    def test_one_switch_on_its_own(self):
        f = vt.lite_flags(self.settings(shadows=True))
        self.assertTrue(f["shadows"])
        self.assertFalse(f["active"])
        self.assertEqual([p for p in vt.LITE_PARTS if f[p]], ["shadows"])

    def test_automatic_reason_needs_its_switch(self):
        # The shell wrote "battery": lite mode only while auto.onBattery is still on.
        self.assertTrue(vt.lite_flags(self.settings(auto={"onBattery": True}), "battery")["active"])
        self.assertFalse(vt.lite_flags(self.settings(), "battery")["active"])
        self.assertTrue(vt.lite_flags(self.settings(auto={"lowBattery": True}), "low")["blur"])
        self.assertFalse(vt.lite_flags(self.settings(auto={"onBattery": True}), "low")["active"])
        self.assertTrue(vt.lite_flags(self.settings(auto={"powerSaver": True}), "saver")["windowAnimations"])
        self.assertFalse(vt.lite_flags(self.settings(auto={"powerSaver": True}), "manual")["active"])

    def test_lite_auto_reads_the_shells_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "lite"
            self.assertEqual(vt.lite_auto(p), "", "no file yet")
            p.write_text("battery\n")
            self.assertEqual(vt.lite_auto(p), "battery")
            p.write_text("\n")
            self.assertEqual(vt.lite_auto(p), "")
            p.write_text("nonsense\n")
            self.assertEqual(vt.lite_auto(p), "", "an unknown reason is none")

    def test_blur_cut_no_effect_on_the_shell_but_the_lock(self):
        s = self.settings(blur=True)
        k = vt.effects_kdl(s, {"shapedGlass": True, "ownGlass": True}, vt.lite_flags(s))
        for g in vt.GROUPS:
            if g == "lock":
                continue
            self.assertIn("blur false", self.layer(k, g), g)
            self.assertNotIn("liquid-glass", self.layer(k, g), g)
            self.assertNotIn("geometry-corner-radius", self.layer(k, g), f"{g}: no shaped rule")
        self.assertIn("liquid-glass", self.layer(k, "lock"), "the lock keeps its own glass")
        # Window materials stay: blur behind panels is not window glass.
        self.assertIn('match app-id="^kitty$"', k)

    def test_glass_cut_makes_glass_frosted(self):
        s = self.settings(glass=True)
        k = vt.effects_kdl(s, {"shapedGlass": True, "ownGlass": True}, vt.lite_flags(s))
        for g in ("bar", "launcher", "widgets", "dock"):
            block = self.layer(k, g)
            self.assertNotIn("liquid-glass", block, g)
            self.assertIn("blur true", block, g)
            self.assertNotIn("geometry-corner-radius", block, g)
        self.assertIn("liquid-glass", self.layer(k, "lock"))
        # A frosted group is left as it is.
        self.assertIn("noise 0.02", self.layer(k, "panels"))

    def test_window_glass_cut(self):
        s = self.settings(windowGlass=True)
        f = vt.lite_flags(s)
        k = vt.effects_kdl(s, None, f)
        self.assertNotIn("window-rule", k, "no window materials")
        pal = vt.guard(vt.palette_from_preset("graphite"))
        look = vt.look_kdl(s, pal, "dark", f)
        self.assertIn("match is-focused=false\n    opacity 1.0", look, "unfocused windows not dimmed")
        self.assertIn("match is-focused=false\n    opacity 0.92", vt.look_kdl(s, pal, "dark"))
        # The terminal goes opaque; nothing else in the settings changes.
        r = vt.lite_render_settings(s, f)
        self.assertEqual(r["terminal"]["opacity"], 1.0)
        self.assertEqual(s["terminal"]["opacity"], 0.72, "the settings themselves are not touched")
        self.assertIs(vt.lite_render_settings(s, vt.lite_flags(self.settings())), s)

    def test_shadows_cut(self):
        pal = vt.guard(vt.palette_from_preset("graphite"))
        s = self.settings(shadows=True)
        look = vt.look_kdl(s, pal, "dark", vt.lite_flags(s))
        layout = look.split("layout {")[1].split("\n}\n")[0]
        self.assertIn("shadow {\n        off\n    }", layout)
        self.assertIn("workspace-shadow {\n        off\n    }", look.split("overview {")[1])
        self.assertIn("window-rule {\n    shadow {\n        off\n    }\n}", look)
        self.assertNotIn("softness 50", look, "no focused-window shadow")
        # The red shadow round a window being cast stays, after the rule that turns them off.
        self.assertGreater(look.index("match is-window-cast-target=true"), look.index("window-rule {\n    shadow {\n        off"))
        self.assertIn("softness 50", vt.look_kdl(s, pal, "dark"))

    def test_focus_by_shadow_gets_a_ring_when_nothing_else_shows_it(self):
        pal = vt.guard(vt.palette_from_preset("graphite"))
        both = self.settings(shadows=True, windowGlass=True)
        self.assertIn("focus-ring {\n        on", vt.look_kdl(both, pal, "dark", vt.lite_flags(both)))
        # Dimming still shows it with only the shadows cut.
        one = self.settings(shadows=True)
        self.assertIn("focus-ring {\n        off", vt.look_kdl(one, pal, "dark", vt.lite_flags(one)))

    def test_window_animations_cut(self):
        s = self.settings(windowAnimations=True)
        self.assertIn("animations {\n    off\n}", vt.animations_kdl(s, vt.lite_flags(s)))
        self.assertIn("slowdown", vt.animations_kdl(s))
        # The shell's own animations are the shell's: niri keeps its springs.
        s2 = self.settings(animations=True)
        self.assertIn("slowdown", vt.animations_kdl(s2, vt.lite_flags(s2)))

    def test_cli_reads_the_reason_next_to_the_palette(self):
        with tempfile.TemporaryDirectory() as tmp:
            write(tmp, "settings.json", {"palette": {"source": "preset"}, "lite": {"auto": {"onBattery": True}}})
            args = [sys.executable, str(ROOT / "tools" / "vitrum-theme"), "--settings", str(Path(tmp) / "settings.json"),
                    "--out-palette", str(Path(tmp) / "palette.json"), "--niri-dir", str(Path(tmp) / "gen"),
                    "--no-color-scheme", "--templates", str(Path(tmp) / "none")]
            r = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertNotIn("off", (Path(tmp) / "gen" / "animations.kdl").read_text())
            (Path(tmp) / "lite").write_text("battery\n")
            r = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn("animations {\n    off\n}", (Path(tmp) / "gen" / "animations.kdl").read_text())
            self.assertIn("blur false", (Path(tmp) / "gen" / "effects.kdl").read_text())

    @unittest.skipUnless(shutil.which("niri"), "niri not installed")
    def test_lite_kdl_validates(self):
        s = self.settings(enabled=True)
        f = vt.lite_flags(s)
        pal = vt.guard(vt.palette_from_preset("graphite"))
        with tempfile.TemporaryDirectory() as tmp:
            for name, text in (("look", vt.look_kdl(s, pal, "dark", f)), ("effects", vt.effects_kdl(s, None, f)),
                               ("animations", vt.animations_kdl(s, f))):
                (Path(tmp) / f"{name}.kdl").write_text(text)
            (Path(tmp) / "config.kdl").write_text('include "look.kdl"\ninclude "effects.kdl"\ninclude "animations.kdl"\n')
            r = subprocess.run(["niri", "validate", "-c", str(Path(tmp) / "config.kdl")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr[-800:])
