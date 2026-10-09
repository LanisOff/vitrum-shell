"""vitrum-theme — turn ~/.config/vitrum/settings.json into the palette and niri's look.

Writes:
  ~/.local/share/vitrum/palette.json                  palette for the shell (both schemes)
  ~/.config/vitrum/niri/generated/look.kdl            gaps, focus treatment, cursor, overview colour
  ~/.config/vitrum/niri/generated/effects.kdl         materials: layer rules per vitrum-<group>, window rules
  ~/.config/vitrum/niri/generated/animations.kdl      the shell's spring tokens, for niri

Only files whose content changed are written, so niri only reloads when it must.
The settings logic mirrors shell/lib/settings.js: wrong types and unknown enum
values fall back to the default with a warning.
"""
from __future__ import annotations

import json
import re
import math
import os
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
DATA_HOME = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local" / "share"))
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "vitrum"

GROUPS = ["bar", "panels", "notifications", "launcher", "lock", "osd", "dock", "dialogs", "widgets", "overlay"]
VIDEO_EXT = {".mp4", ".mkv", ".webm", ".mov", ".avi", ".gif"}

# Spring tokens (damping ratio, stiffness) — the same pairs the shell uses (Motion.qml).
SPRINGS = {"snappy": (1.0, 900), "smooth": (1.0, 600), "bouncy": (0.75, 520)}

GLASS_PRESETS = {
    #           refraction edge  corner depth glow  edge-light sat   dim   boost
    "thin":  (2.4, 0.10, 1.3, 0.8, 0.5, 0.4, 1.05, 0.15, 0.15),
    "lens":  (4.8, 0.12, 1.5, 1.0, 0.8, 0.5, 0.95, 0.15, 0.15),
    "thick": (6.0, 0.18, 1.6, 1.0, 0.9, 0.6, 1.00, 0.20, 0.20),
    "crisp": (3.6, 0.12, 1.2, 0.6, 0.6, 0.3, 1.00, 0.12, 0.12),
}
GLASS_KEYS = ["refraction-strength", "edge-thickness", "corner-fan", "depth-effect", "glow-weight",
              "edge-lighting", "saturation", "adaptive-dim", "adaptive-boost"]
# Glass on a window (Settings → Windows → window materials) over the preset:
# a window is big and its edge is far from the text, so it carries more bend
# and edge light than a panel's; more dimming keeps a terminal readable on it.
# Of those, what makes refraction show at all: lens-distortion bends the whole
# face, fringing splits colour at the rim, a lower power-factor carries the
# bend further in from the edge.
# Under blur the bend itself barely shows, so the frosted lens leans on a
# glowing rim instead.
WINDOW_GLASS = {"refraction-strength": 8.0, "edge-thickness": 0.2, "power-factor": 2.2, "corner-fan": 1.7,
                "glow-weight": 1.5, "edge-lighting": 1.4, "fringing": 0.8, "lens-distortion": 0.9,
                "saturation": 1.18, "adaptive-dim": 0.24, "adaptive-boost": 0.18}
# Clear glass (no blur): what is behind stays sharp, so the bend is plain to
# see; more dimming under the text instead of the blur's.
WINDOW_CLEAR = {**WINDOW_GLASS, "refraction-strength": 8.5, "glow-weight": 1.0, "edge-lighting": 0.9,
                "fringing": 0.7, "lens-distortion": 1.1, "adaptive-dim": 0.32}

MATUGEN_ROLES = {
    "bg": "background", "surface": "surface", "surfaceHigh": "surface_container_high",
    "surfaceHighest": "surface_container_highest", "outline": "outline_variant", "text": "on_surface",
    "textDim": "on_surface_variant", "accent": "primary", "onAccent": "on_primary", "danger": "error",
}
FIXED_ROLES = {"dark": {"warning": "#fdd663", "success": "#81c995"}, "light": {"warning": "#9a5b00", "success": "#1e7a43"}}


# ----------------------------------------------------------------- data -----

def data_dir() -> Path:
    env = os.environ.get("VITRUM_DATA")
    candidates = [Path(env)] if env else []
    candidates += [Path(__file__).resolve().parents[2] / "shell" / "data", CONFIG / "quickshell" / "vitrum" / "data"]
    for c in candidates:
        if (c / "settings.defaults.json").is_file():
            return c
    raise SystemExit("vitrum-theme: cannot find shell data (settings.defaults.json)")


def _json(name: str):
    return json.loads((data_dir() / name).read_text(encoding="utf-8"))


# ------------------------------------------------------------- settings -----

def _type(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "boolean"
    if isinstance(v, (int, float)):
        return "number"
    if isinstance(v, str):
        return "string"
    if isinstance(v, list):
        return "array"
    return "object"


def _enum_for(enums, path):
    if path in enums:
        return enums[path]
    parent = path.rsplit(".", 1)[0] if "." in path else ""
    return enums.get(parent + ".*") if parent else None


def _check(user, defs, enums, prefix, warnings):
    out = {}
    for k, v in user.items():
        path = f"{prefix}.{k}" if prefix else k
        d = defs.get(k) if isinstance(defs, dict) else None
        allowed = _enum_for(enums, path)
        if d is None and not allowed:
            out[k] = v
            continue
        if allowed and v not in allowed:
            warnings.append(f"{path}: expected one of {', '.join(allowed)}, got {json.dumps(v)}")
            continue
        if d is not None and _type(v) != _type(d):
            warnings.append(f"{path}: expected {_type(d)}, got {json.dumps(v)}")
            continue
        if isinstance(v, dict):
            out[k] = _check(v, d if d else {}, enums, path, warnings)
        else:
            out[k] = v
    return out


def deep_merge(base, over):
    if not isinstance(base, dict) or not isinstance(over, dict):
        return base if over is None else over
    out = dict(base)
    for k, v in over.items():
        out[k] = deep_merge(base[k], v) if isinstance(base.get(k), dict) and isinstance(v, dict) else v
    return out


def load_settings(path: Path):
    defaults, enums = _json("settings.defaults.json"), _json("settings.enums.json")
    warnings: list[str] = []
    user = {}
    if path.is_file():
        try:
            user = json.loads(path.read_text(encoding="utf-8"))
        except (ValueError, OSError) as e:
            warnings.append(f"settings.json is not valid JSON ({e}); using defaults")
            user = {}
    if not isinstance(user, dict):
        warnings.append("settings.json is not an object; using defaults")
        user = {}
    return deep_merge(defaults, _check(user, defaults, enums, "", warnings)), warnings


# --------------------------------------------------------------- colour -----

def _rgb(hex_):
    h = hex_.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def _hex(rgb):
    return "#" + "".join(f"{max(0, min(255, round(c * 255))):02x}" for c in rgb)


def _lum(rgb):
    lin = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(a: str, b: str) -> float:
    la, lb = _lum(_rgb(a)), _lum(_rgb(b))
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def _mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def ensure_contrast(fg: str, bg: str, minimum: float = 4.5) -> str:
    """Same algorithm as shell/lib/color.js ensureContrast."""
    if contrast(fg, bg) >= minimum:
        return fg
    f = _rgb(fg)
    for i in range(1, 21):
        t = i * 0.05
        up, down = _hex(_mix(f, (1, 1, 1), t)), _hex(_mix(f, (0, 0, 0), t))
        cu, cd = contrast(up, bg), contrast(down, bg)
        if cu >= minimum or cd >= minimum:
            return up if cu >= cd else down
    return "#ffffff" if contrast("#ffffff", bg) >= contrast("#000000", bg) else "#000000"


def guard(palette: dict) -> dict:
    out = {}
    for scheme, roles in palette.items():
        r = dict(roles)
        r["text"] = ensure_contrast(r["text"], r["surface"])
        r["textDim"] = ensure_contrast(r["textDim"], r["surface"], 3.0)
        r["onAccent"] = ensure_contrast(r["onAccent"], r["accent"])
        out[scheme] = r
    return out


# -------------------------------------------------------------- palette -----

def preset_names():
    return sorted(_json("palettes.json").keys())


def palette_from_preset(name: str, accent: str = "") -> dict:
    presets = _json("palettes.json")
    p = json.loads(json.dumps(presets.get(name) or presets["graphite"]))
    if accent:
        for scheme in p.values():
            scheme["accent"] = accent
            scheme["onAccent"] = "#000000" if contrast("#000000", accent) >= contrast("#ffffff", accent) else "#ffffff"
    return p


def palette_from_matugen(data: dict) -> dict:
    colors = data["colors"]
    out = {}
    for scheme in ("dark", "light"):
        roles = {role: colors[key][scheme]["color"].lower() for role, key in MATUGEN_ROLES.items()}
        roles.update(FIXED_ROLES[scheme])
        out[scheme] = roles
    return out


HEX6 = re.compile(r"^#[0-9a-fA-F]{6}$")


def resolve_palette(settings: dict, wallpaper: Path | None, run=subprocess.run, cache: Path = CACHE):
    """→ (palette, note). Falls back to the preset whenever the wallpaper cannot be used."""
    pal = dict(settings["palette"])
    if pal.get("accent") and not HEX6.match(pal["accent"]):
        print(f"vitrum-theme: warning: palette.accent {pal['accent']!r} is not #rrggbb; ignored", file=sys.stderr)
        pal["accent"] = ""
    pal["accent"] = (pal.get("accent") or "").lower()
    fallback = guard(palette_from_preset(pal["preset"], pal["accent"]))
    try:
        return _from_wallpaper(pal, wallpaper, run, cache, fallback)
    except OSError as e:          # matugen or ffmpeg missing, unreadable file, full disk
        return fallback, f"{e}; preset {pal['preset']}"


def _from_wallpaper(pal, wallpaper, run, cache, fallback):
    if pal["source"] != "wallpaper":
        return fallback, f"preset {pal['preset']}"
    if not wallpaper or not Path(wallpaper).is_file():
        return fallback, f"no wallpaper at {wallpaper}; preset {pal['preset']}"
    source, note = Path(wallpaper), "wallpaper"
    if source.suffix.lower() in VIDEO_EXT:
        cache.mkdir(parents=True, exist_ok=True)
        poster = cache / "poster.png"
        r = run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "1", "-i", str(source), "-frames:v", "1", str(poster)], capture_output=True)
        if r.returncode != 0 or not poster.is_file():
            return fallback, "video poster failed; preset"
        source, note = poster, "video poster frame"
    r = run(["matugen", "image", str(source), "--json", "hex", "--dry-run", "--prefer", "saturation"], capture_output=True)
    try:
        palette = palette_from_matugen(json.loads(r.stdout))
    except (ValueError, KeyError, TypeError):
        return fallback, "matugen failed; preset"
    if pal["accent"]:
        for scheme in palette.values():
            scheme["accent"] = pal["accent"]
    return guard(palette), note


# ----------------------------------------------------------------- niri -----

def _fmt(x) -> str:
    """KDL wants floats written as floats: 1.0, never 1."""
    if isinstance(x, float):
        s = f"{x:.6g}"
        return s if any(ch in s for ch in ".e") else s + ".0"
    return str(x)


# Island heights per density (Tokens.qml): the bar's pieces are capsules.
ISLAND_HEIGHT = {"compact": 30, "regular": 34, "comfortable": 38}


def island_radius(settings: dict) -> int:
    return round(ISLAND_HEIGHT.get(settings.get("density"), 30) / 2)


def launcher_radius(settings: dict) -> int:
    """Half the launcher's capsule (Tokens.launcherHeight: an even 1.6 islands)."""
    return round(ISLAND_HEIGHT.get(settings.get("density"), 30) * 0.8)


def _niri_pid(socket: str | None = None) -> str | None:
    m = re.search(r"\.(\d+)\.sock$", socket if socket is not None else os.environ.get("NIRI_SOCKET", ""))
    return m.group(1) if m else None


def running_niri(socket: str | None = None) -> str | None:
    """The binary of the niri this session runs (from NIRI_SOCKET's pid), or
    None when it cannot be told. "(deleted)" means it was replaced since it
    started: what is on disk now is not what runs."""
    pid = _niri_pid(socket)
    if not pid:
        return None
    try:
        return os.readlink(f"/proc/{pid}/exe")
    except OSError:
        return None


def niri_caps(niri: str | None = None, run=subprocess.run, cache: Path = CACHE, socket: str | None = None) -> dict:
    """What the session's niri can do beyond upstream: {"shapedGlass": bool}.

    Asked by validating a config that uses the option; cached per binary, so
    the probe runs once per niri build. The niri that runs counts, not the one
    on disk: right after an update the session still runs the old one. Its file
    is gone from disk then, but /proc still has it, so that is what is asked —
    a blanket no turned the bar into plain blur until the next login whenever
    a niri that could do it was replaced by another that could too."""
    import shutil
    import tempfile
    running = running_niri(socket) if niri is None else None
    if running and running.endswith(" (deleted)"):
        path = f"/proc/{_niri_pid(socket)}/exe"
    else:
        path = niri or running or shutil.which("niri") or "/usr/local/bin/niri"
    try:
        st = os.stat(path)
        key = f"{path}:{int(st.st_mtime)}:{st.st_size}"
    except OSError:
        return {"shapedGlass": False}
    store = cache / "niri-caps.json"
    try:
        saved = json.loads(store.read_text())
        if saved.get("key") == key:
            return saved["caps"]
    except (OSError, ValueError, KeyError, AttributeError):
        pass
    probe = ('layer-rule {\n    match namespace="^vitrum-probe$"\n    background-effect {\n'
             '        liquid-glass {\n            shape-fillet 1.0\n        }\n    }\n}\n')
    with tempfile.TemporaryDirectory() as tmp:
        cfg = Path(tmp) / "config.kdl"
        cfg.write_text(probe)
        try:
            ok = run([path, "validate", "-c", str(cfg)], capture_output=True).returncode == 0
        except OSError:
            ok = False
    caps = {"shapedGlass": ok}
    try:
        cache.mkdir(parents=True, exist_ok=True)
        store.write_text(json.dumps({"key": key, "caps": caps}))
    except OSError:
        pass
    return caps


def _effect_block(material: str, settings: dict, indent: str = "    ", fillet: float = 0.0, window: bool = False) -> str:
    if material == "solid":
        return f"{indent}background-effect {{\n{indent}    blur false\n{indent}    xray false\n{indent}}}\n"
    if material == "frosted":
        return (f"{indent}background-effect {{\n{indent}    blur true\n{indent}    xray false\n"
                f"{indent}    noise 0.02\n{indent}    saturation 1.1\n{indent}}}\n")
    m = settings["materials"]
    params = dict(zip(GLASS_KEYS, GLASS_PRESETS.get(m["glassPreset"], GLASS_PRESETS["lens"])))
    if window:
        params.update(WINDOW_CLEAR if material == "clear" else WINDOW_GLASS)
    params.update({k: v for k, v in m.get("glassAdvanced", {}).items() if isinstance(v, (int, float)) and not isinstance(v, bool)})
    if fillet > 0:
        params["shape-fillet"] = float(fillet)
    lines = "".join(f"{indent}        {k} {_fmt(v)}\n" for k, v in params.items())
    # Not xray: the glass bends what is really behind it (windows too), not
    # only the wallpaper.
    # noise 0: niri's blur otherwise adds 0.02 of it, grain on a big smooth pane.
    blur = "false" if material == "clear" else "true"
    return (f"{indent}background-effect {{\n{indent}    blur {blur}\n{indent}    xray false\n{indent}    noise 0\n"
            f"{indent}    liquid-glass {{\n{indent}        physical-refraction 0\n{lines}{indent}    }}\n{indent}}}\n")


def effects_kdl(settings: dict, caps: dict | None = None) -> str:
    m = settings["materials"]
    shaped = bool((caps or {}).get("shapedGlass"))
    out = ["// Generated by vitrum-theme from settings.json (materials, windows.materials). Do not edit.\n"]
    for g in GROUPS:
        material = m.get("groups", {}).get(g, m["default"])
        if g in ("bar", "launcher") and material == "glass" and shaped:
            # Shaped glass: every island its own capsule, a panel melts into
            # the island it flows out of (patches/niri-glass); the launcher's
            # results flow out of its search capsule the same way.
            r = island_radius(settings) if g == "bar" else launcher_radius(settings)
            out.append(f'layer-rule {{\n    match namespace="^vitrum-{g}$"\n    geometry-corner-radius {r}\n'
                       f'{_effect_block(material, settings, fillet=r)}}}\n')
            continue
        out.append(f'layer-rule {{\n    match namespace="^vitrum-{g}$"\n{_effect_block(material, settings)}}}\n')
    # The bar's reserve surface and the wallpaper never carry an effect.
    out.append('layer-rule {\n    match namespace="^vitrum-(bar-reserve|wallpaper)$"\n'
               '    background-effect {\n        blur false\n        xray false\n    }\n}\n')
    for w in settings["windows"].get("materials", []):
        if not isinstance(w, dict):
            continue
        app, material = w.get("appId"), w.get("material")
        if not app or material not in ("solid", "frosted", "glass", "clear"):
            continue
        out.append(f'window-rule {{\n    match app-id="^{app}$"\n{_effect_block(material, settings, window=True)}}}\n')
    return "\n".join(out)


def look_kdl(settings: dict, palette: dict, scheme: str) -> str:
    density = settings["density"]
    gap = {"compact": 10, "regular": 14, "comfortable": 18}[density]
    cursor_size = {"compact": 24, "regular": 24, "comfortable": 28}[density]
    p = palette[scheme]
    w = settings["windows"]
    focus = w["focus"]
    if focus == "ring":
        ring = f'focus-ring {{\n        on\n        width 2\n        active-color "{p["accent"]}"\n        inactive-color "#00000000"\n    }}'
    elif focus == "gradient":
        ring = (f'focus-ring {{\n        on\n        width 2\n        active-gradient from="{p["accent"]}" '
                f'to="{p["surfaceHighest"]}" angle=135 relative-to="workspace-view"\n        inactive-color "#00000000"\n    }}')
    else:
        ring = "focus-ring {\n        off\n    }"
    return f"""// Generated by vitrum-theme from settings.json. Do not edit.
layout {{
    gaps {gap}
    {ring}
}}

window-rule {{
    match is-focused=false
    opacity {_fmt(float(w["unfocusedOpacity"]))}
}}

// vitrum's own apps (Settings, Disk Utility, About) are forms to read: opaque,
// focused or not. After the rule above, so it wins.
window-rule {{
    match app-id=r#"^vitrum-(settings|disks|about)$"#
    opacity 1.0
}}

// Games: variable refresh rate while they are on screen (outputs with
// variable-refresh-rate on-demand=true, set in Settings → Displays).
window-rule {{
    match app-id="^steam_app_[0-9]+$"
    match app-id="^gamescope$"
    variable-refresh-rate true
}}

window-rule {{
    match is-focused=true
    shadow {{
        on
        softness 50
        spread 4
        offset x=0 y=12
        color "#00000070"
    }}
}}

cursor {{
    xcursor-theme "{settings["cursor"]["theme"]}"
    xcursor-size {cursor_size}
}}

overview {{
    backdrop-color "{p["bg"]}"
}}
"""


def animations_kdl(settings: dict) -> str:
    mo = settings["motion"]
    if mo["reduce"]:
        return "// Generated by vitrum-theme (motion.reduce). Do not edit.\nanimations {\n    off\n}\n"
    speed = mo["speed"] if mo["speed"] > 0 else 1.0

    def spring(token):
        z, k = SPRINGS[token]
        return f"spring damping-ratio={_fmt(z)} stiffness={k} epsilon=0.0001"

    rows = {
        "window-open": "smooth", "window-movement": "smooth", "window-resize": "snappy",
        "horizontal-view-movement": "smooth", "workspace-switch": "smooth",
        "overview-open-close": "smooth", "config-notification-open-close": "bouncy",
    }
    body = "".join(f"    {name} {{\n        {spring(tok)}\n    }}\n" for name, tok in rows.items())
    body += '    window-close {\n        duration-ms 160\n        curve "ease-out-quad"\n    }\n'
    return f"// Generated by vitrum-theme from settings.json (motion). Do not edit.\nanimations {{\n    slowdown {_fmt(round(1 / speed, 3))}\n{body}}}\n"


# ---------------------------------------------------------------- output ----

def write_if_changed(path: Path, text: str) -> bool:
    path = Path(path)
    if path.is_file() and path.read_text(encoding="utf-8") == text:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    tmp.replace(path)
    return True


def current_scheme(settings: dict) -> str:
    mode = settings["scheme"]["mode"]
    if mode in ("light", "dark"):
        return mode
    state = DATA_HOME / "vitrum" / "scheme"           # written by the shell's Sun service
    if state.is_file() and state.read_text().strip() in ("light", "dark"):
        return state.read_text().strip()
    return "dark"


def set_icon_theme(name: str) -> None:
    """Wayland GTK apps take the icon theme from gsettings, not settings.ini."""
    try:
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", name],
                       capture_output=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        pass


def gtk_theme_name(scheme: str, themes: Path = Path("/usr/share/themes")) -> str:
    """adw-gtk3 when installed: GTK 4's built-in theme (what GTK 4 apps without
    libadwaita — pavucontrol — get from "Adwaita") has its colours baked in and
    ignores vitrum.css's @define-color; adw-gtk3 reads libadwaita's colour names,
    so the palette reaches those apps too, and GTK 3 ones."""
    name = "adw-gtk3-dark" if scheme == "dark" else "adw-gtk3"
    return name if (themes / name).is_dir() else "Adwaita"


def set_gtk_theme_ini(name: str, config: Path = None) -> None:
    """gtk-theme-name in GTK 3's and 4's settings.ini (X11 and non-portal apps read it)."""
    config = Path(config) if config else Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    for ini in (config / "gtk-3.0/settings.ini", config / "gtk-4.0/settings.ini"):
        if not ini.is_file():
            continue
        text = ini.read_text()
        new = re.sub(r"(?m)^gtk-theme-name=.*$", "gtk-theme-name=" + name, text)
        if new != text:
            ini.write_text(new)


def set_color_scheme(scheme: str, gtk: bool = True) -> None:
    """The desktop's light/dark preference; with gtk (toolkits.gtk), also the
    GTK theme (adw-gtk3 when installed) in gsettings and settings.ini."""
    value = "prefer-dark" if scheme == "dark" else "prefer-light"
    pairs = [("color-scheme", value)]
    if gtk:
        theme = gtk_theme_name(scheme)
        set_gtk_theme_ini(theme)
        pairs.append(("gtk-theme", theme))
    for key, val in pairs:
        try:
            subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, val],
                           capture_output=True, timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            pass
