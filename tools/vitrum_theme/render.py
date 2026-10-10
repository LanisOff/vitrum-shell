"""The terminal and toolkit side of vitrum-theme.

From the current scheme of the palette it derives the colours a terminal,
an editor and the toolkits need — the UI roles plus a set of hues tuned for
dark and for light — and renders the templates in config/ (installed to
~/.local/share/vitrum/templates) with them.

Templates use @NAME@ placeholders (NAME_RAW: without "#", NAME_RGB: "r,g,b",
NAME_SGR: "r;g;b" for terminal escapes).
An unknown placeholder is an error: nothing half-rendered is ever written.

"Theme" outputs are rewritten on every run; "base" outputs (configs that are
yours once installed) only with base=True, which the installer passes.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from . import _hex, _rgb as _rgbf, _mix as _mixt, contrast, deep_merge, ensure_contrast


def _mix(a: str, b: str, t: float) -> str:
    """Hex colour a moved toward b by t (0..1)."""
    return _hex(_mixt(_rgbf(a), _rgbf(b), t))

# (template under config/, destination under ~/.config, rewritten every run?)
TARGETS = [
    ("kitty/vitrum-colors.conf.in",         "kitty/vitrum-colors.conf",          True),
    ("kitty/kitty.conf.in",                 "kitty/kitty.conf",                  False),
    ("fish/config.fish.in",                 "fish/config.fish",                  False),
    ("fish/conf.d/00-vitrum-colors.fish.in", "fish/conf.d/00-vitrum-colors.fish", True),
    ("fish/conf.d/10-vitrum-abbr.fish.in",  "fish/conf.d/10-vitrum-abbr.fish",   False),
    ("fish/functions/fish_greeting.fish.in", "fish/functions/fish_greeting.fish", False),
    ("starship/starship.toml.in",           "starship.toml",                     True),
    ("tmux/tmux.conf.in",                   "tmux/tmux.conf",                    False),
    # The keys: keys-vitrum or keys-default, as components.json tmux_keys says.
    ("tmux/keys-{tmux_keys}.conf.in",       "tmux/keys.conf",                    False),
    ("tmux/vitrum.conf.in",                 "tmux/vitrum.conf",                  True),
    ("tmux/tmux-nerd-font-window-name.yml.in", "tmux/tmux-nerd-font-window-name.yml", False),
    ("fastfetch/config.jsonc.in",           "fastfetch/config.jsonc",            False),
    ("gtk-3.0/vitrum.css.in",               "gtk-3.0/vitrum.css",                True),
    ("gtk-3.0/gtk.css.in",                  "gtk-3.0/gtk.css",                   False),
    ("gtk-4.0/vitrum.css.in",               "gtk-4.0/vitrum.css",                True),
    ("gtk-4.0/gtk.css.in",                  "gtk-4.0/gtk.css",                   False),
    ("MangoHud/MangoHud.conf.in",           "MangoHud/MangoHud.conf",            True),
]

# Hues, tuned per scheme: readable on the background, calm next to the UI.
HUES = {
    "dark": {"red": "#ef6f6c", "orange": "#f0965a", "yellow": "#e8c766", "green": "#8fcf86",
             "mint": "#7dd6c2", "teal": "#5fc1d0", "blue": "#6fa8f0", "indigo": "#8f8cf2",
             "purple": "#c38df0", "pink": "#f08ab6", "brown": "#c4a07a", "graphite": "#9aa0a8"},
    "light": {"red": "#c8423e", "orange": "#b8621f", "yellow": "#8f6d00", "green": "#2f7d32",
              "mint": "#00796b", "teal": "#00788a", "blue": "#2a62c9", "indigo": "#4a47c2",
              "purple": "#8442b8", "pink": "#b83776", "brown": "#7d5a35", "graphite": "#6b7078"},
}


def terminal_colours(p: dict, scheme: str) -> dict:
    """The palette's scheme (roles bg, surface…, accent) → terminal/editor colours."""
    dark = scheme == "dark"
    ink = "#000000" if dark else "#ffffff"
    hi = "#ffffff" if dark else "#000000"
    c = {
        "bg": p["bg"],
        "bg_dim": _mix(p["bg"], ink, 0.25),
        "bg_alt": p["surface"],
        "bg_elev": p["surfaceHigh"],
        "bg_high": p["surfaceHighest"],
        "sel": _mix(p["accent"], p["bg"], 0.65),
        "line": p["outline"],
        "muted": _mix(p["textDim"], p["bg"], 0.55),
        "subtle": _mix(p["textDim"], p["bg"], 0.2),
        "fg_dim": p["textDim"],
        "fg": p["text"],
        "fg2": _mix(p["text"], p["textDim"], 0.4),
        "fg_hi": hi,
        "accent": p["accent"],
        "on_accent": p["onAccent"],
        "pill": p["surfaceHigh"],
        "pill_alt": p["surfaceHighest"],
    }
    c.update(HUES["dark" if dark else "light"])
    c["syn"] = {
        "keyword": c["purple"], "string": c["green"], "number": c["orange"], "comment": c["subtle"],
        "doc": c["subtle"], "doc_keyword": c["fg_dim"], "type": c["teal"], "class": c["mint"],
        "func": c["blue"], "func_other": c["indigo"], "const": c["orange"], "const_other": c["yellow"],
        "property": c["teal"], "property_other": c["fg"], "preproc": c["pink"], "attribute": c["brown"],
        "url": c["accent"], "mark": c["fg_hi"],
    }
    # Text must stay readable even with an odd palette (an accent-heavy wallpaper).
    if contrast(c["fg"], c["bg"]) < 7:
        c["fg"] = hi if contrast(hi, c["bg"]) > contrast(c["fg"], c["bg"]) else c["fg"]
    # The accent as text (a command, a path, a link) is moved until it reads on
    # the background and on a pill; fills keep the accent itself.
    c["accent_fg"] = ensure_contrast(ensure_contrast(p["accent"], c["bg"], 4.5), c["pill"], 3.0)
    c["syn"]["url"] = c["accent_fg"]
    # Hints (autosuggestions, bright black) stay faint but legible.
    c["muted"] = ensure_contrast(c["muted"], c["bg"], 3.0)
    return c


def _rgb(hex_: str) -> str:
    h = hex_.lstrip("#")
    return ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


def substitutions(c: dict, scheme: str, settings: dict, shell: str, source: str = "", config=None) -> dict:
    s = {}
    names = {"ACCENT": "accent", "ON_ACCENT": "on_accent", "BG": "bg", "BG_ALT": "bg_alt", "BG_ELEV": "bg_elev",
             "BG_HIGH": "bg_high", "SEL": "sel", "FG": "fg", "FG2": "fg2", "FG_HI": "fg_hi", "DIM": "fg_dim", "LINE": "line",
             "MUTED": "muted", "SUBTLE": "subtle", "PILL": "pill", "PILL_ALT": "pill_alt", "ACCENT_FG": "accent_fg"}
    for hue in HUES["dark"]:
        names[hue.upper()] = hue
    for name, key in names.items():
        s[name] = c[key]
        s[name + "_RAW"] = c[key].lstrip("#")
        s[name + "_RGB"] = _rgb(c[key])
        s[name + "_SGR"] = _rgb(c[key]).replace(",", ";")      # for 38;2;r;g;b escapes
    # Text on a hue-coloured pill: the background or the text colour, whichever reads.
    for hue in HUES["dark"]:
        s["ON_" + hue.upper()] = ensure_contrast(max((c["bg"], c["fg"]), key=lambda x: contrast(x, c[hue])), c[hue], 4.5)
    # The sixteen terminal colours: 0-7 normal, 8-15 bright.
    dark = scheme == "dark"
    lift = (lambda h: _mix(h, "#ffffff", 0.18)) if dark else (lambda h: _mix(h, "#000000", 0.12))
    # Black: near the background in dark; a real dark grey in light, where it is text.
    ramp = [c["bg_high"] if dark else c["fg2"], c["red"], c["green"], c["yellow"], c["blue"], c["purple"], c["teal"], c["fg_dim"]]
    bright = [c["muted"]] + [lift(h) for h in ramp[1:7]] + [c["fg_hi"]]
    for i, v in enumerate(ramp + bright):
        s[f"ANSI{i}"] = v
    fonts = (settings.get("fonts") or {}) if isinstance(settings, dict) else {}
    s["FONT_MONO"] = fonts.get("mono") or "JetBrains Mono"
    s["FONT_SANS"] = fonts.get("sans") or "Inter"
    term = (settings.get("terminal") or {}) if isinstance(settings, dict) else {}
    opacity = term.get("opacity", 0.9)
    s["TERM_OPACITY"] = f"{float(opacity):.2f}" if isinstance(opacity, (int, float)) else "0.90"
    s["MODE"] = scheme
    s["SOURCE"] = source or "palette"
    s["SHELL"] = shell
    # The config dir the files are rendered into: what they source sits beside them.
    config = Path(config) if config else Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    s["CONFIG_HOME"] = str(config)
    s["VITRUM_PREFIX"] = str(config / "vitrum")
    s["VITRUM_STATE"] = str(Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "vitrum")
    return s


PLACEHOLDER = re.compile(r"@([A-Z][A-Z0-9_]*)@")


GLYPH = re.compile(r"\\u([0-9a-fA-F]{4})")


def render(text: str, subs: dict) -> str:
    """Replace every @NAME@ (an unknown one raises KeyError) and turn \\uXXXX
    escapes into the characters (Nerd Font glyphs; written as escapes so the
    templates stay readable without the font)."""
    text = GLYPH.sub(lambda m: chr(int(m.group(1), 16)), text)
    return PLACEHOLDER.sub(lambda m: subs[m.group(1)], text)


def find_shell() -> str:
    return shutil.which("fish") or os.environ.get("SHELL") or "/bin/sh"


def _write(path: Path, text: str) -> bool:
    if path.is_file() and path.read_text(encoding="utf-8") == text:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    tmp.replace(path)
    return True


# Theme outputs rewritten with every palette, and the file of yours laid over
# each: your keys win, the rest keeps following the wallpaper.
LOCAL_OF = {"starship.toml": "starship.local.toml", "MangoHud/MangoHud.conf": "MangoHud/MangoHud.local.conf"}


def overlay(dest: str, text: str, config: Path) -> str:
    """The rendered text with the user's local file for dest laid over it."""
    local = LOCAL_OF.get(dest)
    if not local:
        return text
    try:
        mine = (Path(config) / local).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return text
    if dest.endswith(".toml"):
        return _toml_overlay(text, mine, local)
    return _keys_overlay(text, mine)


def _toml_overlay(text: str, mine: str, name: str) -> str:
    """Table by table, key by key. A file that does not parse is left out (with
    a warning) rather than taking the prompt down with it."""
    try:
        import tomllib
        base, over = tomllib.loads(text), tomllib.loads(mine)
    except Exception as e:  # ImportError (Python < 3.11) or a TOML error
        print(f"vitrum-theme: ~/.config/{name} not applied: {e}", file=sys.stderr)
        return text
    if not over:
        return text
    return f"# Written by vitrum-theme with ~/.config/{name} laid over it.\n\n" + _toml_dump(deep_merge(base, over))


def _toml_key(k: str) -> str:
    return k if re.fullmatch(r"[A-Za-z0-9_-]+", k) else json.dumps(k, ensure_ascii=False)


def _toml_value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, list):
        return "[" + ", ".join(_toml_value(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{_toml_key(k)} = {_toml_value(x)}" for k, x in v.items()) + " }"
    # JSON's string escapes are TOML's basic-string escapes.
    return json.dumps(str(v), ensure_ascii=False)


def _toml_dump(d: dict, path: tuple = ()) -> str:
    """Plain keys first, then each sub-table as its own [a.b] section."""
    lines = [f"{_toml_key(k)} = {_toml_value(v)}" for k, v in d.items() if not isinstance(v, dict)]
    out = ""
    if path and (lines or not any(isinstance(v, dict) for v in d.values())):
        out += "[" + ".".join(_toml_key(k) for k in path) + "]\n"
    if lines:
        out += "\n".join(lines) + "\n\n"
    for k, v in d.items():
        if isinstance(v, dict):
            out += _toml_dump(v, path + (k,))
    return out


def _keys_overlay(text: str, mine: str) -> str:
    """key=value (or a bare flag) lines: a key of yours replaces vitrum's line,
    a new one is added at the end. Comments in yours are skipped."""
    key = lambda line: line.split("=", 1)[0].strip()
    yours = [l.strip() for l in mine.splitlines() if l.strip() and not l.strip().startswith("#")]
    keys = {key(l) for l in yours}
    kept = [l for l in text.splitlines() if not (l.strip() and not l.strip().startswith("#") and key(l) in keys)]
    return "\n".join(kept).rstrip("\n") + "\n\n# ~/.config/MangoHud/MangoHud.local.conf\n" + "\n".join(yours) + "\n"


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class _BaseRecord:
    """What vitrum last wrote to each base config (a hash), so a re-run can
    tell an untouched file (update it) from one you edited (leave it)."""

    def __init__(self, path: Path):
        self.path = path
        try:
            self.hashes = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            self.hashes = {}
        self.dirty = False

    def set(self, dest: str, text: str):
        if self.hashes.get(dest) != _sha(text):
            self.hashes[dest] = _sha(text); self.dirty = True

    def save(self):
        if self.dirty:
            _write(self.path, json.dumps(self.hashes, indent=1, sort_keys=True) + "\n")


def _write_base(out: Path, text: str, dest: str, record: "_BaseRecord"):
    """A base config: written when missing, when it is still what vitrum last
    wrote, or the first time vitrum takes it over (the installer has backed it
    up). Edited since — kept, and a newer version goes beside it as
    <name>.vitrum-new. → the path written, or None."""
    known = record.hashes.get(dest)
    if out.is_file() and known is not None:
        try:
            current = _sha(out.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError):
            current = None
        if current != known:                     # yours now
            if _sha(text) == known:
                return None                      # nothing new from vitrum
            side = out.with_name(out.name + ".vitrum-new")
            return side if _write(side, text) else None
    record.set(dest, text)
    side = out.with_name(out.name + ".vitrum-new")
    if side.is_file():
        side.unlink()
    return out if _write(out, text) else None


def components(data: Path) -> dict:
    """The installer's component choices (components.json beside palette.json)."""
    try:
        return json.loads((Path(data) / "components.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def tmux_keys(comps: dict) -> str:
    """vitrum (Ctrl+a, | and - splits) or default (tmux's own keys)."""
    return "default" if comps.get("tmux_keys") == "default" else "vitrum"


# Files that belong to a component under another name.
COMPONENT_OF = {"MangoHud": "extras"}


def _component(dest: str) -> str:
    """kitty/kitty.conf → kitty, starship.toml → starship, MangoHud/… → extras."""
    name = dest.split("/", 1)[0].split(".", 1)[0]
    return COMPONENT_OF.get(name, name)


def _toolkit_on(settings, name: str) -> bool:
    """toolkits.<name>: on unless set to false."""
    return ((settings.get("toolkits") or {}) if isinstance(settings, dict) else {}).get(name, True) is not False


def render_all(pal: dict, scheme: str, settings: dict, templates: Path, config: Path, data: Path,
               base: bool = False, source: str = "") -> list:
    """Render the theme outputs (and the base ones with base=True); → paths written."""
    c = terminal_colours(pal, scheme)
    subs = substitutions(c, scheme, settings, find_shell(), source, config)
    comps = components(data)
    record = _BaseRecord(Path(data) / "base-configs.json")
    written = []
    for tpl, dest, theme in TARGETS:
        if not theme and not base:
            continue
        # GTK colours (vitrum.css), unless turned off; gtk.css itself is the user's.
        if theme and dest.startswith("gtk-") and not _toolkit_on(settings, "gtk"):
            continue
        if not comps.get(_component(dest), True):
            continue
        src = Path(templates) / tpl.format(tmux_keys=tmux_keys(comps))
        if not src.is_file():
            continue
        out = Path(config) / dest
        text = overlay(dest, render(src.read_text(encoding="utf-8"), subs), Path(config))
        if theme:
            if _write(out, text):
                written.append(out)
        else:
            w = _write_base(out, text, dest, record)
            if w:
                written.append(w)
    kv = kvantum_theme(c, scheme, Path(config) / "Kvantum" / "vitrum")
    if kv:
        written.append(kv)
    # The tight variant, for the apps kvantum.kvconfig gives it (Throne).
    kv = kvantum_theme(c, scheme, Path(config) / "Kvantum" / "vitrumcompact", name="vitrumcompact", compact=True)
    if kv:
        written.append(kv)
    # KDE apps (Dolphin…): kdeglobals and the scheme it names, unless turned off.
    if _toolkit_on(settings, "kde"):
        if kde_colours(c, scheme, Path(config) / "kdeglobals"):
            written.append(Path(config) / "kdeglobals")
        if kde_colour_scheme(c, Path(data).parent / "color-schemes" / "Vitrum.colors"):
            written.append(Path(data).parent / "color-schemes" / "Vitrum.colors")
    # The icon theme follows the scheme (after kdeglobals, which it writes into).
    icons = ((settings.get("icons") or {}) if isinstance(settings, dict) else {}).get("theme") or "Papirus-Dark"
    written += apply_icon_theme(icon_theme(icons, scheme), Path(config))
    record.save()
    # The tmux keys for the keybind sheet (Super+/), the same choice as keys.conf.
    sheet = Path(data) / "tmux-binds.json"
    src = Path(templates) / f"tmux/keys-{tmux_keys(comps)}.json"
    if comps.get("tmux", True) and src.is_file():
        if _write(sheet, src.read_text(encoding="utf-8")):
            written.append(sheet)
    elif sheet.exists():
        sheet.unlink()
    # Neovim reads its colours from here (and reloads when it changes).
    nvim = {"background": scheme, "p": c}
    if _write(Path(data) / "nvim.json", json.dumps(nvim, indent=1) + "\n"):
        written.append(Path(data) / "nvim.json")
    return written


KVANTUM_BASE = Path("/usr/share/Kvantum")

# Qt menus: the menu's corner radius, its shadow, and the hovered entry's capsule.
MENU_RADIUS = 10
MENU_SHADOW = 6
MENUITEM_RADIUS = 6


def _quarter_ring(cx: float, cy: float, dx: int, dy: int, r0: float, r1: float, colour: str, opacity: float = 1.0) -> str:
    """A quarter annulus around (cx, cy) between radii r0 < r1 (a quarter disc
    when r0 is 0), towards (dx, dy) — filled, so it never reaches past its box."""
    op = "" if opacity >= 1 else f";fill-opacity:{opacity:g}"
    sweep = 1 if dx * dy > 0 else 0
    d = (f"M {cx + dx * r1} {cy} A {r1} {r1} 0 0 {sweep} {cx} {cy + dy * r1} L {cx} {cy + dy * r0}"
         + (f" A {r0} {r0} 0 0 {1 - sweep} {cx + dx * r0} {cy}" if r0 else "") + " Z")
    return f'<path d="{d}" style="fill:{colour}{op}"/>'


def _nine_slice(name: str, r: int, fill: str, line: str | None, x0: int, y0: int = 3000, opacity: float = 1.0) -> str:
    """Kvantum's nine pieces of a rounded rectangle with corner radius r: the
    corners quarter discs, the sides r thick, the centre a square. With a line
    colour the outer edge gets a 1px border — filled, not stroked: a stroke
    reaches half a pixel past its piece and Kvantum then scales the piece
    wrong. Drawn side by side from (x0, y0), away from the base theme's art."""
    c = 2 * r                        # the centre square's side
    x, y = x0 + r, y0 + r            # the centre square's top-left
    op = "" if opacity >= 1 else f";fill-opacity:{opacity:g}"

    def rect(bx, by, w, h, colour, id_=""):
        idattr = f'id="{id_}" ' if id_ else ""
        return f'<rect {idattr}x="{bx}" y="{by}" width="{w}" height="{h}" style="fill:{colour}{op}"/>'

    def side(id_, bx, by, w, h, lx, ly, lw, lh):
        edge = rect(lx, ly, lw, lh, line) if line else ""
        return f'<g id="{id_}">{rect(bx, by, w, h, fill)}{edge}</g>'

    def corner(id_, cx, cy, dx, dy):
        # Around (cx, cy), the corner it shares with the centre square.
        if not line:
            return f'<g id="{id_}">{_quarter_ring(cx, cy, dx, dy, 0, r, fill, opacity)}</g>'
        return (f'<g id="{id_}">{_quarter_ring(cx, cy, dx, dy, 0, r - 1, fill, opacity)}'
                f'{_quarter_ring(cx, cy, dx, dy, r - 1, r, line, opacity)}</g>')

    return "".join([
        rect(x, y, c, c, fill, name),
        side(f"{name}-top", x, y0, c, r, x, y0, c, 1),
        side(f"{name}-bottom", x, y + c, c, r, x, y + c + r - 1, c, 1),
        side(f"{name}-left", x0, y, r, c, x0, y, 1, c),
        side(f"{name}-right", x + c, y, r, c, x + c + r - 1, y, 1, c),
        corner(f"{name}-topleft", x, y, -1, -1),
        corner(f"{name}-topright", x + c, y, 1, -1),
        corner(f"{name}-bottomleft", x, y + c, -1, 1),
        corner(f"{name}-bottomright", x + c, y + c, 1, 1),
    ])


def _menu_edge(name: str, r: int, d: int, fill: str, line: str, x0: int) -> str:
    """The pieces Kvantum draws a composited menu's edge from (<name>-shadow-*):
    each is r + d units, the outer d a shadow fading out, then a 1px line and
    the rounded body. <name>-shadow-hint-* tell Kvantum how much of a piece is
    shadow. One unit is one pixel: [Menu] frame is r, menu_shadow_depth is d."""
    S, y0 = r + d, 3100
    alpha = [0.28 * (1 - k / d) ** 2 for k in range(d)]           # k: distance from the body
    def rect(x, y, w, h, colour, a=None):
        op = f";fill-opacity:{a:.3f}" if a is not None else ""
        return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" style="fill:{colour}{op}"/>'
    def ring(cx, cy, dx, dy, r0, r1, colour, a=None):
        return _quarter_ring(cx, cy, dx, dy, r0, r1, colour, 1.0 if a is None else a)
    out, W = [], 2 * S                                             # sides are W long
    # Corners: the inner corner of the piece is the centre of the rounding.
    for i, (part, dx, dy) in enumerate((("topleft", -1, -1), ("topright", 1, -1), ("bottomleft", -1, 1), ("bottomright", 1, 1))):
        bx = x0 + i * (S + 4)
        cx, cy = bx + (S if dx < 0 else 0), y0 + (S if dy < 0 else 0)
        body = ring(cx, cy, dx, dy, 0, r - 1, fill) + ring(cx, cy, dx, dy, r - 1, r, line)
        shade = "".join(ring(cx, cy, dx, dy, r + k, r + k + 1, "#000000", a) for k, a in enumerate(alpha))
        out.append(f'<g id="{name}-shadow-{part}">{shade}{body}</g>')
    # Sides: shadow bands outside, the line, the body inside.
    sx, sy = x0, y0 + S + 4
    t = "".join(rect(sx, sy + d - 1 - k, W, 1, "#000000", a) for k, a in enumerate(alpha))
    out.append(f'<g id="{name}-shadow-top">{t}{rect(sx, sy + d, W, 1, line)}{rect(sx, sy + d + 1, W, r - 1, fill)}</g>')
    sy += S + 4
    b = "".join(rect(sx, sy + r + k, W, 1, "#000000", a) for k, a in enumerate(alpha))
    out.append(f'<g id="{name}-shadow-bottom">{rect(sx, sy, W, r - 1, fill)}{rect(sx, sy + r - 1, W, 1, line)}{b}</g>')
    sx, sy = x0 + W + 4, y0 + S + 4
    lft = "".join(rect(sx + d - 1 - k, sy, 1, W, "#000000", a) for k, a in enumerate(alpha))
    out.append(f'<g id="{name}-shadow-left">{lft}{rect(sx + d, sy, 1, W, line)}{rect(sx + d + 1, sy, r - 1, W, fill)}</g>')
    sx += S + 4
    rgt = "".join(rect(sx + r + k, sy, 1, W, "#000000", a) for k, a in enumerate(alpha))
    out.append(f'<g id="{name}-shadow-right">{rect(sx, sy, r - 1, W, fill)}{rect(sx + r - 1, sy, 1, W, line)}{rgt}</g>')
    # Hints: d of a piece's S is shadow (Kvantum scales them by frame + depth).
    hx, hy = x0, y0 + 3 * S + 20
    out.append(f'<rect id="{name}-shadow-hint-left" x="{hx}" y="{hy}" width="{d}" height="2" style="fill:#b74aff"/>')
    out.append(f'<rect id="{name}-shadow-hint-right" x="{hx + 10}" y="{hy}" width="{d}" height="2" style="fill:#b74aff"/>')
    out.append(f'<rect id="{name}-shadow-hint-top" x="{hx + 20}" y="{hy}" width="2" height="{d}" style="fill:#b74aff"/>')
    out.append(f'<rect id="{name}-shadow-hint-bottom" x="{hx + 30}" y="{hy}" width="2" height="{d}" style="fill:#b74aff"/>')
    return "".join(out)


def _menu_svg(c: dict) -> str:
    """vitrum's menu elements, in the palette: the menu's body and edge with its
    shadow (vitrum-menu-normal*, vitrum-menu-shadow-*), and the hovered/pressed/
    checked entry as an accent capsule (vitrum-menuitem-{focused,pressed,toggled}-*)."""
    out = [_nine_slice("vitrum-menu-normal", MENU_RADIUS, c["bg_elev"], c["line"], 3000),
           _menu_edge("vitrum-menu", MENU_RADIUS, MENU_SHADOW, c["bg_elev"], c["line"], 3300)]
    for i, state in enumerate(("focused", "pressed", "toggled")):
        out.append(_nine_slice(f"vitrum-menuitem-{state}", MENUITEM_RADIUS, c["accent"], None, 3100 + i * 40))
    return '<g id="vitrum-menus">' + "".join(out) + "</g>"


def _menu_keys(c: dict) -> dict:
    """[Menu] and [MenuItem] keys pointing Kvantum at those elements."""
    r, ri = str(MENU_RADIUS), str(MENUITEM_RADIUS)
    return {
        # The blurring path is the one where Kvantum draws a composited menu's
        # edge (vitrum-menu-shadow-*); items keep off the edge instead of spreading to it.
        "%General": {"composite": "true", "blurring": "true", "spread_menuitems": "false",
                     "menu_shadow_depth": str(MENU_SHADOW)},
        "Menu": {"frame.element": "vitrum-menu", "interior.element": "vitrum-menu",
                 "frame.top": r, "frame.bottom": r, "frame.left": r, "frame.right": r,
                 "text.normal.color": c["fg"]},
        "MenuItem": {"frame.element": "vitrum-menuitem", "interior.element": "vitrum-menuitem",
                     "frame.top": ri, "frame.bottom": ri, "frame.left": ri, "frame.right": ri,
                     "text.margin.top": "4", "text.margin.bottom": "4",
                     "text.normal.color": c["fg"], "text.focus.color": c["on_accent"],
                     "text.press.color": c["on_accent"], "text.toggle.color": c["on_accent"]},
    }


def _mix(a: str, b: str, t: float) -> str:
    """#rrggbb a moved t of the way to b."""
    pa, pb = bytes.fromhex(a[1:]), bytes.fromhex(b[1:])
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(pa, pb))


def qt_window(c: dict) -> str:
    """Qt's window colour (sidebars, toolbars, tabs): a step off the view's
    background, so a file manager's sidebar stands apart from its files."""
    return _mix(c["bg"], c["bg_elev"], 0.45)


# Corner radius (= Kvantum frame) per widget; the compact theme's are tighter,
# for dense apps like Throne whose layouts were drawn for small frames.
WIDGET_RADII = {"button": 8, "tbutton": 6, "itemview": 6, "tab": 8, "lineedit": 8}
COMPACT_RADII = {"button": 4, "tbutton": 4, "itemview": 3, "tab": 4, "lineedit": 4}


# Widgets: (element, corner radius, {state: (fill, opacity, line or None)}).
def _widget_specs(c: dict, radii: dict = WIDGET_RADII) -> list:
    a, t = c["accent"], c["fg"]
    return [
        ("vitrum-button", radii["button"], {"normal": (c["bg_elev"], 1, None), "focused": (c["bg_high"], 1, None),
                              "pressed": (c["line"], 1, None), "toggled": (a, 0.3, None),
                              "disabled": (c["bg_elev"], 0.5, None)}),
        ("vitrum-tbutton", radii["tbutton"], {"focused": (t, 0.08, None), "pressed": (t, 0.14, None), "toggled": (a, 0.26, None)}),
        ("vitrum-itemview", radii["itemview"], {"focused": (a, 0.12, None), "pressed": (a, 0.3, None), "toggled": (a, 0.22, None)}),
        ("vitrum-tab", radii["tab"], {"focused": (t, 0.06, None), "toggled": (c["bg_high"], 1, None)}),
        ("vitrum-lineedit", radii["lineedit"], {"normal": (c["bg"], 1, c["line"]), "focused": (c["bg"], 1, a),
                                "disabled": (c["bg"], 0.5, c["line"])}),
    ]


def _widgets_svg(c: dict, radii: dict = WIDGET_RADII) -> str:
    out, y = [], 3400
    for element, r, states in _widget_specs(c, radii):
        for i, (state, (fill, opacity, line)) in enumerate(states.items()):
            out.append(_nine_slice(f"{element}-{state}", r, fill, line, 3000 + i * 40, y, opacity))
        y += 40
    return '<g id="vitrum-widgets">' + "".join(out) + "</g>"


def _widget_keys(c: dict, radii: dict = WIDGET_RADII) -> dict:
    """The sections of the widgets above, and flat bars without focus dots."""
    def look(element, r, **text):
        keys = {"frame": "true", "interior": "true", "frame.element": element, "interior.element": element,
                "frame.expansion": "0", "frame.top": str(r), "frame.bottom": str(r), "frame.left": str(r), "frame.right": str(r)}
        keys.update({f"text.{k}.color": v for k, v in text.items()})
        return keys
    fg = c["fg"]
    button = look("vitrum-button", radii["button"], normal=fg, focus=fg, press=fg, toggle=fg)
    tool = look("vitrum-tbutton", radii["tbutton"], normal=fg, focus=fg, press=fg, toggle=fg)
    return {
        "PanelButtonCommand": button,
        "ComboBox": dict(button),
        "PanelButtonTool": dict(tool),
        "ToolbarButton": dict(tool),
        "ItemView": look("vitrum-itemview", radii["itemview"], normal=fg, focus=fg, press=fg, toggle=fg),
        "Tab": look("vitrum-tab", radii["tab"], normal=c["fg_dim"], focus=fg, toggle=fg),
        "LineEdit": look("vitrum-lineedit", radii["lineedit"]),
        "TabBarFrame": {"frame": "false", "interior": "false"},
        "Toolbar": {"frame": "false", "interior": "false"},
        "Focus": {"frame": "false"},
    }


def kvantum_theme(c: dict, scheme: str, out: Path, base_dir: Path = None, name: str = "vitrum",
                  compact: bool = False):
    """Kvantum's look is in its SVG: take KvGnome (light) or KvGnomeDark, keep
    its shapes and settings, and replace only [GeneralColors] with the palette.
    Nothing happens without Kvantum. compact: the tighter variant (small radii
    and paddings, tabs on the left) for dense apps; it is written as <name>.*."""
    base_dir = base_dir or KVANTUM_BASE
    base_name = "KvGnomeDark" if scheme == "dark" else "KvGnome"
    src = Path(base_dir) / base_name
    if not (src / f"{base_name}.kvconfig").is_file() or not (src / f"{base_name}.svg").is_file():
        return None
    win = qt_window(c)
    colours = {
        "window.color": win, "inactive.window.color": win,
        "base.color": c["bg"], "inactive.base.color": c["bg"],
        "alt.base.color": c["bg_elev"], "inactive.alt.base.color": c["bg_elev"],
        "button.color": c["bg_elev"], "light.color": c["bg_high"], "mid.light.color": c["bg_high"],
        "dark.color": c["bg_dim"], "mid.color": c["line"],
        "highlight.color": c["accent"], "inactive.highlight.color": c["accent"],
        "text.color": c["fg"], "inactive.text.color": c["fg_dim"],
        "window.text.color": c["fg"], "inactive.window.text.color": c["fg_dim"],
        "button.text.color": c["fg"], "disabled.text.color": c["muted"],
        "tooltip.text.color": c["fg"], "highlight.text.color": c["on_accent"],
        "link.color": c["accent"], "link.visited.color": c["purple"],
        "progress.indicator.text.color": c["on_accent"],
    }
    radii = COMPACT_RADII if compact else WIDGET_RADII
    menus = _menu_keys(c)
    for section_, keys in _widget_keys(c, radii).items():
        menus.setdefault(section_, {}).update(keys)
    if compact:
        menus["%General"]["left_tabs"] = "true"
    lines, skipping, section, seen = [], False, "", set()
    for line in (src / f"{base_name}.kvconfig").read_text(encoding="utf-8", errors="replace").splitlines():
        if line.strip().startswith("["):
            section = line.strip()[1:-1]
            seen.add(section)
            skipping = section == "GeneralColors"
            if skipping:
                lines.append("[GeneralColors]")
                lines += [f"{k}={v}" for k, v in colours.items()]
                continue
            lines.append(line)
            # The menu keys right under their section header: Kvantum takes the
            # first occurrence of a key, so these win over the base theme's.
            lines += [f"{k}={v}" for k, v in menus.get(section, {}).items()]
            continue
        if not skipping and section in menus and line.split("=", 1)[0].strip() in menus[section]:
            continue
        if not skipping:
            lines.append(line)
    # Sections the base theme does not have.
    for section_, keys in menus.items():
        if section_ not in seen:
            lines += ["", f"[{section_}]"] + [f"{k}={v}" for k, v in keys.items()]
    out.mkdir(parents=True, exist_ok=True)
    base_svg = (src / f"{base_name}.svg").read_text(encoding="utf-8", errors="replace")
    end = base_svg.rfind("</svg>")
    svg = (base_svg[:end] + _menu_svg(c) + _widgets_svg(c, radii) + base_svg[end:]).encode("utf-8") if end >= 0 else base_svg.encode("utf-8")
    if not (out / f"{name}.svg").is_file() or (out / f"{name}.svg").read_bytes() != svg:
        (out / f"{name}.svg").write_bytes(svg)
    cfg = out / f"{name}.kvconfig"
    return cfg if _write(cfg, "\n".join(lines) + "\n") else None


def _kde_rgb(h: str) -> str:
    return ",".join(str(v) for v in bytes.fromhex(h[1:]))


def kde_scheme(c: dict) -> dict:
    """The [Colors:*] groups of a KDE colour scheme from the terminal colours."""
    def group(bg, alt, fg):
        return {
            "BackgroundNormal": bg, "BackgroundAlternate": alt,
            "ForegroundNormal": fg, "ForegroundInactive": c["fg_dim"], "ForegroundActive": c["accent_fg"],
            "ForegroundLink": c["accent_fg"], "ForegroundVisited": c["purple"],
            "ForegroundNegative": c["red"], "ForegroundNeutral": c["orange"], "ForegroundPositive": c["green"],
            "DecorationFocus": c["accent"], "DecorationHover": c["accent"],
        }
    return {
        "Colors:View": group(c["bg"], c["bg_alt"], c["fg"]),
        "Colors:Window": group(qt_window(c), c["bg_elev"], c["fg"]),
        "Colors:Button": group(c["bg_elev"], c["bg_high"], c["fg"]),
        "Colors:Header": group(qt_window(c), c["bg_elev"], c["fg"]),
        "Colors:Tooltip": group(c["bg_elev"], c["bg_high"], c["fg"]),
        "Colors:Complementary": group(c["bg_dim"], c["bg_alt"], c["fg"]),
        "Colors:Selection": {**group(c["accent"], c["accent"], c["on_accent"]),
                             "ForegroundInactive": c["on_accent"], "ForegroundActive": c["on_accent"]},
    }


def _kde_groups_text(colours: dict) -> str:
    return "\n\n".join(f"[{n}]\n" + "\n".join(f"{k}={_kde_rgb(v)}" for k, v in g.items())
                       for n, g in colours.items())


def kde_colour_scheme(c: dict, path: Path) -> bool:
    """~/.local/share/color-schemes/Vitrum.colors — what kdeglobals' ColorScheme=
    names. KDE's scheme manager (Dolphin has one) loads the palette from it by
    name and uses Breeze Light when it is missing."""
    return _write(path, _kde_groups_text(kde_scheme(c)) + "\n\n[General]\nName=Vitrum\nColorScheme=Vitrum\n")


def _kde_read(path: Path):
    """kdeglobals → (group order, {group: [lines]}); "" holds anything before the first group."""
    order, groups, cur = [""], {"": []}, ""
    if path and Path(path).is_file():
        for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
            st = line.strip()
            if st.startswith("[") and st.endswith("]"):
                cur = st[1:-1]
                if cur not in groups:
                    groups[cur] = []; order.append(cur)
            elif st:
                groups[cur].append(line)
    return order, groups


def _kde_text(order, groups) -> str:
    parts = ["\n".join(groups[""])] if groups.get("") else []
    parts += [f"[{n}]\n" + "\n".join(groups[n]) for n in order if n and n in groups]
    return "\n\n".join(parts) + "\n" if parts else ""


def _kde_is_colours(group: str) -> bool:
    # Every group a colour scheme owns, subgroups ([Colors:View][Inactive]) included.
    return group.startswith("Colors:") or group.startswith("ColorEffects:")


def _kde_set(order, groups, group, key, value):
    """Set (value) or remove (None) one key; an emptied group goes."""
    lines = [l for l in groups.get(group, []) if l.split("=", 1)[0].strip() != key]
    if value is not None:
        lines.append(f"{key}={value}")
    if lines:
        if group not in groups:
            order.append(group)
        groups[group] = lines
    else:
        groups.pop(group, None)


def _kde_get(groups, group, key):
    for l in groups.get(group, []):
        k, _, v = l.partition("=")
        if k.strip() == key:
            return v
    return None


ICON_ROOTS = (Path("/usr/share/icons"), Path("/usr/local/share/icons"), Path.home() / ".local/share/icons")


def icon_theme(name: str, scheme: str, roots=None) -> str:
    """The icon theme for the scheme. One with -Dark/-Light variants follows it
    (Papirus-Dark in the dark, Papirus-Light in the light): a dark theme's light
    symbolic icons all but vanish on a light window. Without the variant
    installed, the choice stands."""
    roots = ICON_ROOTS if roots is None else roots
    family = re.sub(r"-(Dark|Light)$", "", name or "")
    want = f"{family}-{'Dark' if scheme == 'dark' else 'Light'}"
    return want if any((Path(r) / want / "index.theme").is_file() for r in roots) else name


def apply_icon_theme(theme: str, config: Path) -> list:
    """The icon theme where each toolkit reads it: GTK's settings.ini, qt6ct /
    qt5ct, kdeglobals' [Icons]. Only files that exist are touched, and only
    that one line. → the paths written."""
    written = []
    for rel, key in (("gtk-3.0/settings.ini", "gtk-icon-theme-name"), ("gtk-4.0/settings.ini", "gtk-icon-theme-name"),
                     ("qt6ct/qt6ct.conf", "icon_theme"), ("qt5ct/qt5ct.conf", "icon_theme")):
        path = Path(config) / rel
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        new = re.sub(rf"^{re.escape(key)}=.*$", f"{key}={theme}", text, flags=re.M)
        if new != text and _write(path, new):
            written.append(path)
    kde = Path(config) / "kdeglobals"
    if kde.is_file():
        order, groups = _kde_read(kde)
        _kde_set(order, groups, "Icons", "Theme", theme)
        if _write(kde, _kde_text(order, groups)):
            written.append(kde)
    return written


def kde_colours(c: dict, scheme: str, path: Path) -> bool:
    """KDE apps (Dolphin, Ark, Okular…) colour their views from kdeglobals'
    [Colors:*] groups, not from the Qt style — without them they use Breeze
    Light's dark text. Replace every colour group (a previous scheme's
    subgroups too, or they would win for unfocused windows) and the scheme
    names; every other group in the file is yours and kept. → True when the
    file changed."""
    order, groups = _kde_read(path)
    for name in [n for n in order if _kde_is_colours(n)]:
        groups.pop(name, None)
    for name, g in kde_scheme(c).items():
        if name not in order:
            order.append(name)
        groups[name] = [f"{k}={_kde_rgb(v)}" for k, v in g.items()]
    _kde_set(order, groups, "General", "ColorScheme", "Vitrum")
    # KDE apps' scheme manager reads UiSettings/ColorScheme (their own rc, falling
    # back to kdeglobals); unset, it replaces the style's palette with a default.
    _kde_set(order, groups, "UiSettings", "ColorScheme", "Vitrum")
    return _write(path, _kde_text(order, groups))


def kde_restore(path: Path, original) -> None:
    """Uninstall: take back only what vitrum put in kdeglobals — the colour
    groups and the scheme names — and put the original's back (original: the
    file as it was before vitrum, or None when there was none). Everything KDE
    wrote there since stays."""
    path = Path(path)
    order, groups = _kde_read(path)
    for name in [n for n in order if _kde_is_colours(n)]:
        groups.pop(name, None)
    o_order, o_groups = _kde_read(Path(original) if original else None)
    for name in o_order:
        if _kde_is_colours(name):
            if name not in order:
                order.append(name)
            groups[name] = o_groups[name]
    for group in ("General", "UiSettings"):
        _kde_set(order, groups, group, "ColorScheme", _kde_get(o_groups, group, "ColorScheme"))
    text = _kde_text(order, groups)
    if text.strip():
        _write(path, text)
    elif path.exists():
        path.unlink()


def _gsettings_get(key: str) -> str:
    try:
        r = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", key], capture_output=True, text=True, timeout=5)
        return r.stdout.strip().strip("'") if r.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def reload_running(config: Path = None, comps: dict = None, written: list = None) -> None:
    """Running kitty windows and the tmux server pick the new colours up. tmux
    sources only its colour file — the whole tmux.conf would rerun plugin
    bootstraps — and not at all when tmux was not installed. Running GTK apps
    reread their CSS when the GTK theme name changes, so when the GTK colours
    were rewritten the theme is set away and straight back."""
    config = Path(config) if config else Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    comps = comps or {}
    cmds = [["pkill", "-USR1", "-x", "kitty"]]
    if comps.get("tmux", True):
        cmds.append(["tmux", "source-file", str(config / "tmux/vitrum.conf")])
    if any("gtk-" in str(w) for w in (written or [])):
        theme = _gsettings_get("gtk-theme") or "Adwaita"
        key = ["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme"]
        cmds += [key + [""], key + [theme]]
    for cmd in cmds:
        try:
            subprocess.run(cmd, capture_output=True, timeout=5)
        except (OSError, subprocess.SubprocessError):
            pass
