"""vitrum-theme's terminal/toolkit renderer (tools/vitrum_theme/render.py)."""
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import vitrum_theme as vt  # noqa: E402
from vitrum_theme import render as R  # noqa: E402

HEX = re.compile(r"^#[0-9a-f]{6}$")


def templates():
    """Every concrete template TARGETS names (both tmux key sets)."""
    for tpl, dest, theme in R.TARGETS:
        for name in sorted({tpl.format(tmux_keys=k) for k in ("vitrum", "default")}):
            yield name, dest, theme


def palette(scheme):
    return vt.palette_from_preset("graphite")[scheme]


class Colours(unittest.TestCase):
    def test_every_colour_is_hex_in_both_schemes(self):
        for scheme in ("dark", "light"):
            c = R.terminal_colours(palette(scheme), scheme)
            for k, v in c.items():
                if k != "syn":
                    self.assertRegex(v, HEX, f"{scheme}.{k}")
            for k, v in c["syn"].items():
                self.assertRegex(v, HEX, f"{scheme}.syn.{k}")

    def test_text_and_hues_readable_on_the_background(self):
        for scheme in ("dark", "light"):
            c = R.terminal_colours(palette(scheme), scheme)
            self.assertGreaterEqual(vt.contrast(c["fg"], c["bg"]), 7, scheme)
            for hue in ("red", "orange", "yellow", "green", "teal", "blue", "purple"):
                self.assertGreaterEqual(vt.contrast(c[hue], c["bg"]), 3.0, f"{scheme} {hue}")

    def test_text_colours_readable_for_every_preset_and_accent(self):
        # The Settings swatches (apps/common/SettingColor.qml) and a free pick.
        swatches = ["", "#5b8def", "#7c6cf0", "#d4628d", "#e5734b", "#d9a43b", "#4fa66b", "#3aa6a6", "#ffeb3b"]
        for preset in vt.preset_names():
            for accent in swatches:
                for scheme in ("dark", "light"):
                    c = R.terminal_colours(vt.palette_from_preset(preset, accent)[scheme], scheme)
                    s = R.substitutions(c, scheme, {}, "/bin/fish")
                    tag = f"{preset}/{accent or 'default'}/{scheme}"
                    self.assertGreaterEqual(vt.contrast(c["accent_fg"], c["bg"]), 4.5, tag + " accent_fg")
                    self.assertGreaterEqual(vt.contrast(c["accent_fg"], c["pill"]), 3.0, tag + " accent_fg on pill")
                    self.assertGreaterEqual(vt.contrast(c["muted"], c["bg"]), 3.0, tag + " muted")
                    self.assertGreaterEqual(vt.contrast(s["ANSI8"], c["bg"]), 3.0, tag + " ANSI8")
                    if scheme == "light":
                        self.assertGreaterEqual(vt.contrast(s["ANSI0"], c["bg"]), 4.5, tag + " ANSI0 light")
                    for hue in ("orange", "green", "red"):
                        self.assertGreaterEqual(vt.contrast(s[f"ON_{hue.upper()}"], c[hue]), 4.5, f"{tag} on {hue}")

    def test_text_uses_of_the_accent_go_through_accent_fg(self):
        fish = (ROOT / "config/fish/conf.d/00-vitrum-colors.fish.in").read_text(encoding="utf-8")
        self.assertRegex(fish, r"fish_color_command\s+@ACCENT_FG_RAW@")
        self.assertRegex(fish, r"fish_color_cwd\s+@ACCENT_FG_RAW@")
        tmux = (ROOT / "config/tmux/vitrum.conf.in").read_text(encoding="utf-8")
        self.assertNotIn("fg=@ON_ACCENT@,bg=@ORANGE@", tmux)
        self.assertNotIn("fg=@ON_ACCENT@,bg=@GREEN@", tmux)
        self.assertNotIn("fg=@ON_ACCENT@,bg=@RED@", tmux)

    def test_accent_follows_the_palette(self):
        p = palette("dark"); p["accent"] = "#ff8800"
        self.assertEqual(R.terminal_colours(p, "dark")["accent"], "#ff8800")


class Render(unittest.TestCase):
    def test_placeholders_replaced(self):
        self.assertEqual(R.render("a @X@ b @X_RAW@", {"X": "#112233", "X_RAW": "112233"}), "a #112233 b 112233")

    def test_glyph_escapes_become_characters(self):
        self.assertEqual(R.render("x '\\uf07b' y", {}), "x '\uf07b' y")

    def test_no_apple_glyph_anywhere(self):
        for tpl, _d, _t in templates():
            text = (ROOT / "config" / tpl).read_text(encoding="utf-8")
            self.assertNotIn("\uf179", text, tpl)
            self.assertNotIn("\\uf179", text, tpl)

    def test_prompt_has_a_symbol_for_every_target_distro(self):
        # Starship shows "…" for an OS with no symbol; vitrum targets Gentoo and Arch.
        text = (ROOT / "config/starship/starship.toml.in").read_text(encoding="utf-8")
        for distro in ("Gentoo", "Arch"):
            self.assertRegex(text, rf"(?m)^{distro}\s*=", distro)

    def test_unknown_placeholder_is_an_error(self):
        with self.assertRaises(KeyError):
            R.render("@NOPE@", {})

    def test_every_template_renders_completely(self):
        subs = R.substitutions(R.terminal_colours(palette("dark"), "dark"), "dark", {"terminal": {"opacity": 0.9}}, "/usr/bin/fish")
        n = 0
        for tpl, _dest, _theme in templates():
            text = (ROOT / "config" / tpl).read_text(encoding="utf-8")
            out = R.render(text, subs)
            self.assertNotRegex(out, r"@[A-Z][A-Z0-9_]*@", tpl)
            n += 1
        self.assertGreater(n, 8)

    def test_tmux_finds_its_files_under_the_config_dir_rendered_to(self):
        # tmux reads $XDG_CONFIG_HOME/tmux/tmux.conf; what that sources must be beside it.
        with tempfile.TemporaryDirectory() as t:
            cfg = Path(t) / "cfg"
            R.render_all(palette("dark"), "dark", {}, templates=ROOT / "config", config=cfg,
                         data=Path(t) / "share/vitrum", base=True)
            for f in ("tmux/tmux.conf", "tmux/vitrum.conf"):
                text = (cfg / f).read_text()
                self.assertNotIn("~/.config", "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#")), f)
            self.assertIn(f"source-file {cfg}/tmux/vitrum.conf", (cfg / "tmux/tmux.conf").read_text())

    def test_render_all_writes_theme_files_and_leaves_base_ones(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t)
            base = [d for _, d, theme in R.TARGETS if not theme][0]
            mine = home / ".config" / base
            mine.parent.mkdir(parents=True, exist_ok=True)
            mine.write_text("my edits\n")
            written = R.render_all(palette("dark"), "dark", {}, templates=ROOT / "config", config=home / ".config",
                                   data=home / ".local/share/vitrum", base=False)
            self.assertEqual(mine.read_text(), "my edits\n")
            self.assertTrue(written)
            self.assertTrue((home / ".local/share/vitrum/nvim.json").is_file())
            written = R.render_all(palette("dark"), "dark", {}, templates=ROOT / "config", config=home / ".config",
                                   data=home / ".local/share/vitrum", base=True)
            self.assertNotEqual(mine.read_text(), "my edits\n")


class BaseConfigsStayYours(unittest.TestCase):
    """Re-running the installer (vitrum-theme --all) must not eat edits made
    after the first install; an untouched base config still gets updates."""

    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.home = Path(self.t.name)
        self.tpl = self.home / "templates"
        import shutil
        shutil.copytree(ROOT / "config", self.tpl)
        self.cfg = self.home / ".config"
        self.data = self.home / ".local/share/vitrum"

    def tearDown(self):
        self.t.cleanup()

    def run_all(self):
        return R.render_all(palette("dark"), "dark", {}, templates=self.tpl, config=self.cfg, data=self.data, base=True)

    def change_template(self):
        f = self.tpl / "kitty/kitty.conf.in"
        f.write_text(f.read_text(encoding="utf-8") + "\n# a newer vitrum\n", encoding="utf-8")

    def test_an_edited_base_config_is_kept_and_the_new_one_put_beside_it(self):
        self.run_all()
        kitty = self.cfg / "kitty/kitty.conf"
        kitty.write_text(kitty.read_text() + "font_size 15\n")
        self.change_template()
        self.run_all()
        self.assertIn("font_size 15", kitty.read_text())
        self.assertIn("a newer vitrum", (self.cfg / "kitty/kitty.conf.vitrum-new").read_text())

    def test_an_untouched_base_config_is_updated(self):
        self.run_all()
        self.change_template()
        self.run_all()
        self.assertIn("a newer vitrum", (self.cfg / "kitty/kitty.conf").read_text())
        self.assertFalse((self.cfg / "kitty/kitty.conf.vitrum-new").exists())

    def test_an_edited_config_with_nothing_new_is_left_quietly(self):
        self.run_all()
        kitty = self.cfg / "kitty/kitty.conf"
        kitty.write_text("mine\n")
        written = self.run_all()
        self.assertEqual(kitty.read_text(), "mine\n")
        self.assertFalse(kitty.with_name("kitty.conf.vitrum-new").exists())
        self.assertNotIn(kitty, written)


class Components(unittest.TestCase):
    """What the installer was told not to install, vitrum-theme does not write."""

    def test_tmux_opt_out_leaves_tmux_alone(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t); data = home / ".local/share/vitrum"
            data.mkdir(parents=True)
            (data / "components.json").write_text('{"tmux": false, "fish": true}')
            mine = home / ".config/tmux/tmux.conf"; mine.parent.mkdir(parents=True); mine.write_text("mine\n")
            R.render_all(palette("dark"), "dark", {}, templates=ROOT / "config", config=home / ".config", data=data, base=True)
            self.assertEqual(mine.read_text(), "mine\n")
            self.assertFalse((home / ".config/tmux/vitrum.conf").exists())
            self.assertTrue((home / ".config/fish/conf.d/00-vitrum-colors.fish").is_file())

    def test_reload_sources_only_the_colours_and_skips_tmux_when_off(self):
        calls = []
        real = R.subprocess.run
        R.subprocess.run = lambda cmd, **kw: calls.append(cmd)
        try:
            R.reload_running(Path("/cfg"), {"tmux": True})
            self.assertIn(["tmux", "source-file", "/cfg/tmux/vitrum.conf"], calls)
            calls.clear()
            R.reload_running(Path("/cfg"), {"tmux": False})
            self.assertFalse([c for c in calls if c[0] == "tmux"])
        finally:
            R.subprocess.run = real


    def test_running_gtk_apps_reread_their_colours(self):
        calls = []
        real = R.subprocess.run

        class Out:
            returncode, stdout = 0, "'adw-gtk3-dark'\n"
        R.subprocess.run = lambda cmd, **kw: (calls.append(cmd), Out())[1]
        try:
            R.reload_running(Path("/cfg"), {"tmux": False}, [Path("/cfg/gtk-3.0/vitrum.css")])
            sets = [c for c in calls if c[:2] == ["gsettings", "set"]]
            self.assertEqual([c[-1] for c in sets], ["", "adw-gtk3-dark"], "away and back to the same theme")
            calls.clear()
            R.reload_running(Path("/cfg"), {"tmux": False}, [Path("/cfg/kitty/vitrum-colors.conf")])
            self.assertFalse([c for c in calls if c[0] == "gsettings"], "GTK untouched when its colours did not change")
        finally:
            R.subprocess.run = real


class TmuxKeys(unittest.TestCase):
    """The installer asks: vitrum's tmux keys or tmux's own. tmux.conf sources
    keys.conf; the keybind sheet reads tmux-binds.json for the same choice."""

    def run_with(self, comps):
        t = tempfile.TemporaryDirectory(); self.addCleanup(t.cleanup)
        home = Path(t.name); data = home / ".local/share/vitrum"; data.mkdir(parents=True)
        if comps is not None:
            (data / "components.json").write_text(json.dumps(comps))
        R.render_all(palette("dark"), "dark", {}, templates=ROOT / "config", config=home / ".config", data=data, base=True)
        return home / ".config/tmux", data

    def test_vitrum_keys_by_default(self):
        tmux, data = self.run_with(None)
        self.assertIn("set -g prefix C-a", (tmux / "keys.conf").read_text())
        self.assertIn(f"source-file {tmux}/keys.conf", (tmux / "tmux.conf").read_text())
        binds = json.loads((data / "tmux-binds.json").read_text())
        self.assertTrue(any(b["keys"] == "Ctrl+a |" for b in binds))
        self.assertTrue(all(b["section"].startswith("tmux") for b in binds))

    def test_tmux_own_keys(self):
        tmux, data = self.run_with({"tmux": True, "tmux_keys": "default"})
        keys = (tmux / "keys.conf").read_text()
        self.assertNotIn("prefix C-a", keys)
        binds = json.loads((data / "tmux-binds.json").read_text())
        self.assertTrue(any(b["keys"] == "Ctrl+b %" for b in binds))
        self.assertFalse(any("Ctrl+a" in b["keys"] for b in binds))

    def test_no_tmux_no_sheet_section(self):
        tmux, data = self.run_with({"tmux": False})
        self.assertFalse((data / "tmux-binds.json").exists())

    def test_tmux_conf_binds_nothing_itself(self):
        # Keys live in keys.conf only, so the choice is the whole keymap.
        text = (ROOT / "config/tmux/tmux.conf.in").read_text(encoding="utf-8")
        self.assertNotRegex(text, r"(?m)^\s*set -g prefix")
        self.assertNotRegex(text, r"(?m)^\s*bind (?!-n Wheel)")


class KdeColours(unittest.TestCase):
    """Dolphin and every KDE app take their colours from kdeglobals, not from
    the Qt style: without these groups they fall back to Breeze Light's dark
    text, which on the vitrum window is unreadable."""

    def groups(self, text):
        out, cur = {}, None
        for line in text.splitlines():
            if line.startswith("["):
                cur = line.strip()[1:-1]; out[cur] = {}
            elif "=" in line and cur:
                k, v = line.split("=", 1); out[cur][k] = v
        return out

    def test_kdeglobals_gets_readable_colour_groups(self):
        for scheme in ("dark", "light"):
            with tempfile.TemporaryDirectory() as t:
                f = Path(t) / "kdeglobals"
                R.kde_colours(R.terminal_colours(palette(scheme), scheme), scheme, f)
                g = self.groups(f.read_text())
                for grp in ("Colors:View", "Colors:Window", "Colors:Button", "Colors:Selection", "Colors:Tooltip", "Colors:Header"):
                    self.assertIn(grp, g, f"{scheme} {grp}")
                    fg = "#%02x%02x%02x" % tuple(int(x) for x in g[grp]["ForegroundNormal"].split(","))
                    bg = "#%02x%02x%02x" % tuple(int(x) for x in g[grp]["BackgroundNormal"].split(","))
                    self.assertGreaterEqual(vt.contrast(fg, bg), 4.5, f"{scheme} {grp}")
                self.assertEqual(g["General"]["ColorScheme"], "Vitrum")
                # KColorSchemeManager (Dolphin, Kate, Okular…) reads this, through
                # kdeglobals; unset, it puts its own default palette over the style's.
                self.assertEqual(g["UiSettings"]["ColorScheme"], "Vitrum")

    def test_kde_links_readable_with_a_pale_accent(self):
        with tempfile.TemporaryDirectory() as t:
            f = Path(t) / "kdeglobals"
            R.kde_colours(R.terminal_colours(vt.palette_from_preset("graphite", "#ffeb3b")["light"], "light"), "light", f)
            v = self.groups(f.read_text())["Colors:View"]
            hx = lambda k: "#%02x%02x%02x" % tuple(int(x) for x in v[k].split(","))
            for k in ("ForegroundLink", "ForegroundActive"):
                self.assertGreaterEqual(vt.contrast(hx(k), hx("BackgroundNormal")), 4.5, k)

    def test_a_previous_schemes_subgroups_do_not_survive(self):
        # Breeze leaves [Colors:View][Inactive] etc.; they would win for unfocused windows.
        with tempfile.TemporaryDirectory() as t:
            f = Path(t) / "kdeglobals"
            f.write_text("[Colors:Header][Inactive]\nBackgroundNormal=1,2,3\n\n[ColorEffects:Inactive]\nEnable=true\n\n[KDE]\nSingleClick=false\n")
            R.kde_colours(R.terminal_colours(palette("light"), "light"), "light", f)
            g = self.groups(f.read_text())
            self.assertNotIn("Colors:Header][Inactive", g)
            self.assertNotIn("ColorEffects:Inactive", g)
            self.assertEqual(g["KDE"]["SingleClick"], "false")

    def test_setting_off_leaves_kde_alone(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t)
            R.render_all(palette("dark"), "dark", {"toolkits": {"kde": False}}, templates=ROOT / "config",
                         config=home / ".config", data=home / ".local/share/vitrum")
            self.assertFalse((home / ".config/kdeglobals").exists())
            self.assertFalse((home / ".local/share/color-schemes/Vitrum.colors").exists())

    def test_setting_off_leaves_gtk_alone(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t)
            R.render_all(palette("dark"), "dark", {"toolkits": {"gtk": False}}, templates=ROOT / "config",
                         config=home / ".config", data=home / ".local/share/vitrum")
            self.assertFalse((home / ".config/gtk-3.0/vitrum.css").exists())
            self.assertFalse((home / ".config/gtk-4.0/vitrum.css").exists())

    def test_gtk_on_by_default(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t)
            R.render_all(palette("dark"), "dark", {}, templates=ROOT / "config",
                         config=home / ".config", data=home / ".local/share/vitrum")
            self.assertTrue((home / ".config/gtk-4.0/vitrum.css").exists())

    def test_uninstall_takes_back_only_the_colours(self):
        with tempfile.TemporaryDirectory() as t:
            f = Path(t) / "kdeglobals"; orig = Path(t) / "orig"
            orig.write_text("[General]\nColorScheme=BreezeDark\n\n[Colors:View]\nForegroundNormal=9,9,9\n\n[Colors:View][Inactive]\nForegroundNormal=8,8,8\n")
            f.write_text(orig.read_text())
            R.kde_colours(R.terminal_colours(palette("dark"), "dark"), "dark", f)
            with open(f, "a") as h:
                h.write("\n[Shortcuts]\nfoo=Ctrl+K\n")          # written by KDE since install
            R.kde_restore(f, orig)
            g = self.groups(f.read_text())
            self.assertEqual(g["General"]["ColorScheme"], "BreezeDark")
            self.assertEqual(g["Colors:View"]["ForegroundNormal"], "9,9,9")
            self.assertEqual(g["Colors:View][Inactive"]["ForegroundNormal"], "8,8,8")
            self.assertNotIn("UiSettings", g)
            self.assertEqual(g["Shortcuts"]["foo"], "Ctrl+K")

    def test_uninstall_without_an_original_strips_vitrum_and_keeps_the_rest(self):
        with tempfile.TemporaryDirectory() as t:
            f = Path(t) / "kdeglobals"
            R.kde_colours(R.terminal_colours(palette("dark"), "dark"), "dark", f)
            with open(f, "a") as h:
                h.write("\n[KDE]\nSingleClick=false\n")
            R.kde_restore(f, None)
            g = self.groups(f.read_text())
            self.assertEqual(set(g), {"KDE"})
            f.write_text("[General]\nColorScheme=Vitrum\n")
            R.kde_restore(f, None)
            self.assertFalse(f.exists())

    def test_other_kdeglobals_groups_are_kept(self):
        with tempfile.TemporaryDirectory() as t:
            f = Path(t) / "kdeglobals"
            f.write_text("[KDE]\nSingleClick=false\n\n[Colors:View]\nForegroundNormal=1,2,3\n\n[General]\nTerminalApplication=kitty\n")
            R.kde_colours(R.terminal_colours(palette("dark"), "dark"), "dark", f)
            g = self.groups(f.read_text())
            self.assertEqual(g["KDE"]["SingleClick"], "false")
            self.assertEqual(g["General"]["TerminalApplication"], "kitty")
            self.assertNotEqual(g["Colors:View"]["ForegroundNormal"], "1,2,3")

    def test_render_all_writes_kdeglobals(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t)
            R.render_all(palette("dark"), "dark", {}, templates=ROOT / "config", config=home / ".config",
                         data=home / ".local/share/vitrum")
            self.assertIn("[Colors:View]", (home / ".config/kdeglobals").read_text())

    def test_render_all_writes_the_named_colour_scheme(self):
        # kdeglobals names the scheme; KDE's scheme manager loads it by that name
        # and falls back to Breeze Light when the file is missing.
        with tempfile.TemporaryDirectory() as t:
            home = Path(t)
            R.render_all(palette("dark"), "dark", {}, templates=ROOT / "config", config=home / ".config",
                         data=home / ".local/share/vitrum")
            g = self.groups((home / ".local/share/color-schemes/Vitrum.colors").read_text())
            self.assertEqual(g["General"]["Name"], "Vitrum")
            self.assertEqual(g["Colors:View"], self.groups((home / ".config/kdeglobals").read_text())["Colors:View"])



class Fastfetch(unittest.TestCase):
    def test_colours_are_sgr_with_semicolons(self):
        # "38;2;r,g,b" is not an escape a terminal understands: fastfetch printed
        # its tail ("80,248m") into every line. Truecolour SGR is 38;2;r;g;b.
        with tempfile.TemporaryDirectory() as t:
            cfg = Path(t) / "cfg"
            R.render_all(palette("dark"), "dark", {}, templates=ROOT / "config", config=cfg,
                         data=Path(t) / "share/vitrum", base=True)
            text = (cfg / "fastfetch/config.jsonc").read_text()
            for m in re.finditer(r'"(38;2;[^"]*)"', text):
                self.assertRegex(m.group(1), r"^38;2;\d{1,3};\d{1,3};\d{1,3}$")
            self.assertIn("38;2;", text)

    @unittest.skipUnless(__import__("shutil").which("fastfetch"), "fastfetch not installed")
    def test_rendered_config_is_accepted(self):
        import subprocess
        with tempfile.TemporaryDirectory() as t:
            cfg = Path(t) / "cfg"
            R.render_all(palette("light"), "light", {}, templates=ROOT / "config", config=cfg,
                         data=Path(t) / "share/vitrum", base=True)
            r = subprocess.run(["fastfetch", "--config", str(cfg / "fastfetch/config.jsonc"), "--pipe", "--logo", "none"],
                               capture_output=True, text=True, timeout=30)
            self.assertNotIn("Error", r.stdout + r.stderr)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


class FastfetchLogo(unittest.TestCase):
    """Gentoo builds fastfetch without ImageMagick, so "auto" cannot show the
    PNG logo; kitty can read the file itself (kitty-direct), also through tmux.
    A TTY must keep "auto" (kitty-direct would print escape codes there)."""

    @unittest.skipUnless(__import__("shutil").which("fish"), "fish not installed")
    def test_fish_passes_kitty_direct_only_inside_kitty(self):
        import subprocess
        with tempfile.TemporaryDirectory() as t:
            t = Path(t)
            subs = R.substitutions(R.terminal_colours(palette("dark"), "dark"), "dark", {}, "/bin/fish", config=t / "cfg")
            abbr = t / "abbr.fish"
            abbr.write_text(R.render((ROOT / "config/fish/conf.d/10-vitrum-abbr.fish.in").read_text(encoding="utf-8"), subs))
            (t / "bin").mkdir()
            stub = t / "bin/fastfetch"; stub.write_text("#!/bin/sh\necho \"args: $*\"\n"); stub.chmod(0o755)
            env = {"PATH": f"{t}/bin:/usr/bin:/bin", "HOME": str(t)}
            def run(extra):
                return subprocess.run([__import__("shutil").which("fish"), "--no-config", "-i", "-c", f"source {abbr}; fastfetch --x"],
                                      env={**env, **extra}, capture_output=True, text=True, timeout=30).stdout
            self.assertIn("--logo-type kitty-direct --x", run({"KITTY_WINDOW_ID": "1"}))
            self.assertNotIn("kitty-direct", run({}))


class NvimConfig(unittest.TestCase):
    def test_aerial_follows_its_branch_for_neovim_0_11(self):
        # aerial's master needs Neovim 0.12 and errors on 0.11 (Gentoo stable).
        text = (ROOT / "config/nvim/lua/plugins/editor.lua").read_text(encoding="utf-8")
        spec = text[text.index('"stevearc/aerial.nvim"'):]
        spec = spec[:spec.index("\n  },")]
        self.assertRegex(spec, r'branch\s*=.*nvim-0\.12.*"nvim-0\.11"')


if __name__ == "__main__":
    unittest.main()


class KvantumMenus(unittest.TestCase):
    """Qt menus (Dolphin's right click, every Kvantum app): rounded, padded, the
    hovered entry an accent capsule — elements vitrum adds to the base SVG."""

    def theme(self, scheme="dark"):
        tmp = Path(tempfile.mkdtemp())
        name = "KvGnomeDark" if scheme == "dark" else "KvGnome"
        base = tmp / "base" / name
        base.mkdir(parents=True)
        (base / f"{name}.kvconfig").write_text(
            "[%General]\ncomposite=true\nmenu_shadow_depth=6\n\n[GeneralColors]\nwindow.color=#000000\n\n"
            "[Menu]\ninherits=PanelButtonCommand\nframe.top=1\nframe.element=menu\ninterior.element=menu\n"
            "text.normal.color=white\n\n[MenuItem]\ninherits=PanelButtonCommand\nframe.element=menuitem\n"
            "interior.element=menuitem\ntext.normal.color=white\ntext.focus.color=white\nframe.top=2\n\n[MenuBar]\nframe=true\n")
        (base / f"{name}.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg"><g id="base"/></svg>\n')
        c = R.terminal_colours(palette(scheme), scheme)
        cfg = R.kvantum_theme(c, scheme, tmp / "out", base_dir=tmp / "base")
        return c, cfg.read_text(), (tmp / "out" / "vitrum.svg").read_text()

    def section(self, cfg, name):
        m = re.search(r"^\[%s\]\n(.*?)(?=^\[|\Z)" % re.escape(name), cfg, re.S | re.M)
        return dict(l.split("=", 1) for l in m.group(1).splitlines() if "=" in l)

    def test_menu_points_at_the_rounded_elements(self):
        c, cfg, svg = self.theme()
        menu, item = self.section(cfg, "Menu"), self.section(cfg, "MenuItem")
        self.assertEqual(menu["frame.element"], "vitrum-menu")
        self.assertEqual(menu["interior.element"], "vitrum-menu")
        self.assertEqual(item["frame.element"], "vitrum-menuitem")
        self.assertEqual(menu["frame.top"], str(R.MENU_RADIUS))
        self.assertEqual(item["text.focus.color"], c["on_accent"])
        self.assertEqual(menu["text.normal.color"], c["fg"])
        self.assertEqual(self.section(cfg, "MenuBar")["frame"], "true", "other sections untouched")
        general = self.section(cfg, "%General")
        # Kvantum draws a composited menu's edge from its -shadow pieces only on
        # the blurring path; items inset from the edge, not spread to it.
        self.assertEqual(general["blurring"], "true")
        self.assertEqual(general["spread_menuitems"], "false")
        self.assertEqual(general["menu_shadow_depth"], str(R.MENU_SHADOW))
        self.assertEqual(general["composite"], "true")

    def test_svg_has_every_piece_in_the_palette(self):
        for scheme in ("dark", "light"):
            c, _, svg = self.theme(scheme)
            self.assertIn('<g id="base"/>', svg, "the base theme stays")
            for part in ("", "-top", "-bottom", "-left", "-right", "-topleft", "-topright", "-bottomleft", "-bottomright"):
                self.assertIn(f'id="vitrum-menu-normal{part}"', svg)
                if part:
                    self.assertIn(f'id="vitrum-menu-shadow{part}"', svg)
                for state in ("focused", "pressed", "toggled"):
                    self.assertIn(f'id="vitrum-menuitem-{state}{part}"', svg)
            self.assertIn(c["accent"], svg)
            self.assertTrue(svg.rstrip().endswith("</svg>"))
            for side in ("left", "top", "right", "bottom"):
                self.assertIn(f'id="vitrum-menu-shadow-hint-{side}"', svg)

    def test_shadow_hint_is_the_shadow_share_of_a_piece(self):
        # Kvantum: shadow = (frame + depth) * hint / piece, so the hint is
        # depth units of a (frame + depth)-unit piece.
        _, _, svg = self.theme()
        m = re.search(r'<rect id="vitrum-menu-shadow-hint-left" x="[^"]+" y="[^"]+" width="([^"]+)"', svg)
        self.assertEqual(float(m.group(1)), R.MENU_SHADOW)
        m = re.search(r'<rect id="vitrum-menu-shadow-hint-top" x="[^"]+" y="[^"]+" width="[^"]+" height="([^"]+)"', svg)
        self.assertEqual(float(m.group(1)), R.MENU_SHADOW)


class KvantumWidgets(KvantumMenus):
    """Dolphin and every Kvantum app: rounded buttons, tool buttons, tabs, line
    edits and item-view selections in the palette, no focus dots, flat bars."""

    def test_sections_point_at_vitrum_elements(self):
        c, cfg, svg = self.theme()
        for section, element in (("PanelButtonCommand", "vitrum-button"), ("ComboBox", "vitrum-button"),
                                 ("ToolbarButton", "vitrum-tbutton"), ("PanelButtonTool", "vitrum-tbutton"),
                                 ("ItemView", "vitrum-itemview"), ("Tab", "vitrum-tab"), ("LineEdit", "vitrum-lineedit")):
            keys = self.section(cfg, section)
            self.assertEqual(keys["frame.element"], element, section)
            self.assertEqual(keys["interior.element"], element, section)
            self.assertEqual(keys["frame.expansion"], "0", section)
        self.assertEqual(self.section(cfg, "ItemView")["text.press.color"], c["fg"], "selected text stays readable")
        self.assertEqual(self.section(cfg, "Focus")["frame"], "false")
        self.assertEqual(self.section(cfg, "Toolbar")["interior"], "false")
        self.assertEqual(self.section(cfg, "TabBarFrame")["frame"], "false")

    def test_every_state_piece_is_in_the_svg(self):
        _, _, svg = self.theme()
        for element, states in (("vitrum-button", ("normal", "focused", "pressed", "toggled", "disabled")),
                                ("vitrum-tbutton", ("focused", "pressed", "toggled")),
                                ("vitrum-itemview", ("focused", "pressed", "toggled")),
                                ("vitrum-tab", ("focused", "toggled")),
                                ("vitrum-lineedit", ("normal", "focused", "disabled"))):
            for state in states:
                for part in ("", "-top", "-bottomright"):
                    self.assertIn(f'id="{element}-{state}{part}"', svg)

    def test_window_set_off_from_the_view(self):
        c, cfg, _ = self.theme()
        colours = self.section(cfg, "GeneralColors")
        self.assertEqual(colours["base.color"], c["bg"])
        self.assertNotEqual(colours["window.color"], c["bg"], "the sidebar and toolbar stand apart from the file view")


class IconsFollowTheScheme(unittest.TestCase):
    def roots(self, *themes):
        root = Path(tempfile.mkdtemp())
        for t in themes:
            (root / t).mkdir()
            (root / t / "index.theme").write_text("[Icon Theme]\n")
        return [root]

    def test_a_theme_with_variants_follows_the_scheme(self):
        roots = self.roots("Papirus", "Papirus-Dark", "Papirus-Light")
        self.assertEqual(R.icon_theme("Papirus-Dark", "light", roots), "Papirus-Light")
        self.assertEqual(R.icon_theme("Papirus-Dark", "dark", roots), "Papirus-Dark")
        self.assertEqual(R.icon_theme("Papirus-Light", "dark", roots), "Papirus-Dark")
        self.assertEqual(R.icon_theme("Papirus", "dark", roots), "Papirus-Dark")

    def test_without_the_variant_the_choice_stands(self):
        roots = self.roots("Papirus-Dark", "Adwaita")
        self.assertEqual(R.icon_theme("Papirus-Dark", "light", roots), "Papirus-Dark", "no Papirus-Light installed")
        self.assertEqual(R.icon_theme("Adwaita", "dark", roots), "Adwaita")

    def test_written_where_every_toolkit_reads_it(self):
        cfg = Path(tempfile.mkdtemp())
        for rel, text in (("gtk-3.0/settings.ini", "[Settings]\ngtk-theme-name=Adwaita\ngtk-icon-theme-name=Papirus-Dark\n"),
                          ("gtk-4.0/settings.ini", "[Settings]\ngtk-icon-theme-name=Papirus-Dark\n"),
                          ("qt6ct/qt6ct.conf", "[Appearance]\nstyle=kvantum\nicon_theme=Papirus-Dark\n"),
                          ("kdeglobals", "[General]\nColorScheme=Vitrum\n")):
            (cfg / rel).parent.mkdir(parents=True, exist_ok=True)
            (cfg / rel).write_text(text)
        written = R.apply_icon_theme("Papirus-Light", cfg)
        self.assertIn("gtk-icon-theme-name=Papirus-Light", (cfg / "gtk-3.0/settings.ini").read_text())
        self.assertIn("gtk-theme-name=Adwaita", (cfg / "gtk-3.0/settings.ini").read_text(), "the rest kept")
        self.assertIn("gtk-icon-theme-name=Papirus-Light", (cfg / "gtk-4.0/settings.ini").read_text())
        self.assertIn("icon_theme=Papirus-Light", (cfg / "qt6ct/qt6ct.conf").read_text())
        self.assertRegex((cfg / "kdeglobals").read_text(), r"\[Icons\]\nTheme=Papirus-Light")
        self.assertEqual(len(written), 4)
        self.assertEqual(R.apply_icon_theme("Papirus-Light", cfg), [], "nothing to do the second time")
        self.assertFalse((cfg / "qt5ct").exists(), "files that are not there are not made")


class KvantumCompact(KvantumMenus):
    """vitrumcompact: the same look, tighter, for dense apps (Throne): small
    radii and paddings, tabs on the left."""

    def compact(self):
        tmp = Path(tempfile.mkdtemp())
        base = tmp / "base" / "KvGnomeDark"
        base.mkdir(parents=True)
        (base / "KvGnomeDark.kvconfig").write_text("[%General]\ncomposite=true\nleft_tabs=false\n\n[GeneralColors]\n\n[ItemView]\nframe.top=2\n")
        (base / "KvGnomeDark.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg"></svg>\n')
        c = R.terminal_colours(palette("dark"), "dark")
        cfg = R.kvantum_theme(c, "dark", tmp / "out", base_dir=tmp / "base", name="vitrumcompact", compact=True)
        return c, cfg, tmp / "out"

    def test_compact_theme_is_its_own_files(self):
        _, cfg, out = self.compact()
        self.assertEqual(cfg.name, "vitrumcompact.kvconfig")
        self.assertTrue((out / "vitrumcompact.svg").is_file())

    def test_compact_is_tighter_with_tabs_on_the_left(self):
        _, cfg, _ = self.compact()
        text = cfg.read_text()
        self.assertEqual(self.section(text, "%General")["left_tabs"], "true")
        self.assertEqual(self.section(text, "ItemView")["frame.top"], "3")
        self.assertEqual(self.section(text, "PanelButtonCommand")["frame.top"], "4")
        self.assertEqual(self.section(text, "Tab")["frame.top"], "4")
