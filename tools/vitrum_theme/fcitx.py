"""fcitx5, vitrum's input method (the input_method component).

With the component on, fcitx5 holds every layout and engine and niri keeps one
xkb layout: the base. Without it nothing here runs and niri switches its own
layouts, as it always did.

keyboard.layouts stays the one list, in xkb's spelling: jp, kr and cn mean
their engines here (mozc, hangul, pinyin) and plain keymaps on the other path,
so turning the component on moves an existing `jp` to fcitx5 and turning it off
brings it back, with nothing to migrate. shell/lib/keyboard.js has the twin of
the naming rules.

What fcitx5 reads (checked against fcitx5 5.1.23):
  ~/.config/fcitx5/profile             the group and its input methods. fcitx5
                                       writes this back itself, comments lost and
                                       DefaultIM updated, so it is compared by
                                       meaning and rewritten only when the list
                                       changed. A running fcitx5 never rereads it:
                                       SetInputMethodGroupInfo sets it live.
  ~/.config/fcitx5/config              hotkeys and behaviour; only vitrum's keys
                                       are touched.
  ~/.config/fcitx5/conf/classicui.conf the candidate window's theme and font.
  ~/.local/share/fcitx5/themes/vitrum  the theme: theme.conf and two SVG pieces.

Files that were there before vitrum are kept once as <name>.pre-vitrum, and
uninstall.sh puts them back. Dictionaries (~/.local/share/fcitx5, ~/.config/mozc)
are never touched.

Glass: niri keeps input-method popups out of its popup rules (src/window/mapped.rs,
"IME popups aren't affected by rules"), so vitrum's own glass can't reach the
candidate window. fcitx5 asks for blur itself (EnableBlur, ext-background-effect-v1)
and niri honours that (seen on the a8562a1 pin), so the pane is frosted translucent.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

COMPONENT = "input_method"
ENGINES = {"jp": "mozc", "kr": "hangul", "cn": "pinyin"}
# fcitx5 has no limit; this is the same number shell/lib/keyboard.js keeps to.
MAX_IMS = 8
THEME = "vitrum"
GROUP = "Default"

# Current fcitx5 Wayland guidance (fcitx-im.org, Using Fcitx 5 on Wayland) for a
# compositor with text-input-v3 and input-method-v2, as sway and niri are:
#   XMODIFIERS    for X11 apps under xwayland-satellite.
#   QT_IM_MODULES Qt 6.7+ tries these in order; "wayland" is text-input-v3.
#   QT_IM_MODULE  what Qt 5 and older Qt 6 read.
#   SDL_IM_MODULE SDL2 on X11, where Steam's runtime puts most games.
#   GLFW_IM_MODULE kitty on X11 only ("ibus" is its name for the protocol
#                 fcitx5 speaks too); on Wayland kitty has wayland_enable_ime.
# GTK_IM_MODULE is left unset on purpose: GTK 3 and 4 use text-input-v3 by
# themselves, and setting it would move them to the client-side candidate
# window instead of niri's input popup.
ENVIRONMENT = (("XMODIFIERS", "@im=fcitx"), ("QT_IM_MODULE", "fcitx"), ("QT_IM_MODULES", "wayland;fcitx;ibus"),
               ("SDL_IM_MODULE", "fcitx"), ("GLFW_IM_MODULE", "ibus"))

# Chromium has its own text-input client, off by default and on v1 unless told;
# niri has only v3. No environment variable does this, so the flags go where the
# distributions' wrappers read them (Arch's electron and chromium, Fedora's
# chromium-browser); an app started any other way needs them in its own launcher.
ELECTRON_FLAGS = ("--enable-wayland-ime", "--wayland-text-input-version=3")
FLAG_FILES = {"electron-flags.conf": None, "chromium-flags.conf": "chromium", "chrome-flags.conf": "google-chrome-stable",
              "brave-flags.conf": "brave", "vesktop-flags.conf": "vesktop", "code-flags.conf": "code",
              "codium-flags.conf": "codium"}
FLAGS_BEGIN = "# >>> vitrum input method"
FLAGS_END = "# <<< vitrum input method"

_ENTRY = re.compile(r"^([a-z][a-z0-9_\-]*)(?:\(([A-Za-z0-9_\-]+)\))?$")


def config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")


def data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")


def enabled(data: Path) -> bool:
    """The component, as the installer recorded it (components.json beside palette.json)."""
    try:
        comps = json.loads((Path(data) / "components.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return False
    return isinstance(comps, dict) and comps.get(COMPONENT) is True


def applies(data: Path, input_kdl: Path, explicit: bool = False, env=os.environ) -> bool:
    """Whether to render for fcitx5 now. A session that started without the
    component has no fcitx5 and no environment for it: taking its layouts away
    from niri there would leave it on one layout until the next login, and any
    wallpaper change renders. So not inside such a session, unless the installer
    asks (explicit) or an earlier run already did (input.kdl has the environment);
    the render at the next login does it."""
    if not enabled(data):
        return False
    if explicit or not env.get("NIRI_SOCKET") or env.get("XMODIFIERS") == "@im=fcitx":
        return True
    try:
        return "XMODIFIERS" in Path(input_kdl).read_text(encoding="utf-8")
    except OSError:
        return False


# -------------------------------------------------------------- the list ----

def entries(settings: dict, base_xkb: dict | None = None) -> list[tuple[str, str]]:
    """keyboard.layouts as (layout, variant) pairs, or config.kdl's own until
    Settings first changed them: valid, distinct, MAX_IMS at most."""
    kb = (settings.get("keyboard") or {}) if isinstance(settings, dict) else {}
    raw = kb.get("layouts") if isinstance(kb, dict) else None
    if not (isinstance(raw, list) and raw):
        ls = (base_xkb or {}).get("layout", "").split(",")
        vs = (base_xkb or {}).get("variant", "").split(",")
        raw = [f"{l.strip()}({v.strip()})" if v.strip() else l.strip()
               for l, v in zip(ls, vs + [""] * len(ls)) if l.strip()]
    out = []
    for x in raw:
        m = _ENTRY.match(x.strip()) if isinstance(x, str) else None
        if m and (m.group(1), m.group(2) or "") not in out:
            out.append((m.group(1), m.group(2) or ""))
        if len(out) == MAX_IMS:
            break
    return out


def is_engine(layout: str, variant: str) -> bool:
    return not variant and layout in ENGINES


def im_name(layout: str, variant: str = "") -> str:
    """us → keyboard-us, de(nodeadkeys) → keyboard-de-nodeadkeys, jp → mozc."""
    if is_engine(layout, variant):
        return ENGINES[layout]
    return f"keyboard-{layout}-{variant}" if variant else f"keyboard-{layout}"


def base_layout(pairs: list[tuple[str, str]]) -> tuple[str, str]:
    """niri's one layout: the first keymap in the list, us when it holds only engines."""
    for layout, variant in pairs:
        if not is_engine(layout, variant):
            return layout, variant
    return "us", ""


def input_methods(pairs: list[tuple[str, str]]) -> list[str]:
    """fcitx5's list. Its first entry is what "off" means to fcitx5 and must be
    a keymap, so the base comes first even when the list starts with an engine."""
    base = im_name(*base_layout(pairs))
    names = [im_name(l, v) for l, v in pairs]
    return [base] + [n for n in names if n != base]


def fcitx_layout(layout: str, variant: str) -> str:
    return f"{layout}-{variant}" if variant else layout


# ------------------------------------------------------------ the profile ---

def profile_text(ims: list[str], default_layout: str) -> str:
    rows = [f"[Groups/0]\nName={GROUP}\nDefault Layout={default_layout}\nDefaultIM={ims[0]}\n"]
    rows += [f"[Groups/0/Items/{i}]\nName={n}\nLayout=\n" for i, n in enumerate(ims)]
    rows.append(f"[GroupOrder]\n0={GROUP}\n")
    return "\n".join(rows)


def parse_profile(text: str) -> tuple[list[str], str]:
    """The first group's input methods and default layout; ([], "") without one."""
    items, layout, section = {}, "", ""
    for raw in str(text or "").splitlines():
        line = raw.strip()
        if line.startswith("["):
            section = line.strip("[]")
            continue
        key, _, value = line.partition("=")
        if section == "Groups/0" and key == "Default Layout":
            layout = value
        m = re.fullmatch(r"Groups/0/Items/(\d+)", section)
        if m and key == "Name":
            items[int(m.group(1))] = value
    return [items[i] for i in sorted(items)], layout


# -------------------------------------------------------- fcitx5's INI files --

def merge_ini(text: str, ours: dict[str, dict[str, str]]) -> str:
    """The file with these sections' keys set, and everything else as it was:
    the keys fcitx5 and its config tool keep there stay yours. A section whose
    value is empty is cleared, which is how fcitx5 reads an empty key list."""
    out, section, seen, done = [], "", set(), set()

    def flush(name: str):
        if name in ours and name not in done:
            for k, v in ours[name].items():
                if k not in seen:
                    out.append(f"{k}={v}")
            done.add(name)

    for raw in str(text or "").splitlines():
        line = raw.strip()
        if line.startswith("[") and line.endswith("]"):
            flush(section)
            section, seen = line[1:-1], set()
            out.append(raw)
            continue
        key = line.partition("=")[0] if "=" in line and not line.startswith("#") else ""
        if section in ours and key:
            if key in ours[section]:
                seen.add(key)
                out.append(f"{key}={ours[section][key]}")
            elif not ours[section]:
                continue     # a list being emptied: its old items go
            else:
                # A list's items are numbered: what is beyond ours goes with them.
                if not (key.isdigit() and any(k.isdigit() for k in ours[section])):
                    out.append(raw)
            continue
        out.append(raw)
    flush(section)
    while out and not out[-1].strip():
        out.pop()
    for name, keys in ours.items():
        if name not in done:
            out += ["", f"[{name}]"] + [f"{k}={v}" for k, v in keys.items()]
    return "\n".join(out) + "\n"


def keylist(*keys: str) -> dict[str, str]:
    return {str(i): k for i, k in enumerate(keys)}


def config_sections(niri_hotkey: bool) -> dict[str, dict[str, str]]:
    """fcitx5's global config. One state for the whole session (ShareInputState):
    per-app memory is the shell's, and two memories would fight. Switching
    shows in vitrum's OSD, not in a popup of fcitx5's own. Super+space and
    Ctrl+Space are left to niri and the apps; a lone Shift is not a toggle.

    Alt+Shift: niri's own bind where it can (niri_hotkey), because fcitx5 only
    sees keys while a text field is focused; else fcitx5's hotkey."""
    switch = keylist("Alt+Shift_L", "Shift+Alt_L") if not niri_hotkey else {}
    return {
        "Hotkey": {"EnumerateWithTriggerKeys": "True", "EnumerateSkipFirst": "False"},
        "Hotkey/TriggerKeys": keylist("Zenkaku_Hankaku", "Hangul"),
        "Hotkey/AltTriggerKeys": {},
        "Hotkey/EnumerateForwardKeys": switch,
        "Hotkey/EnumerateBackwardKeys": {},
        "Hotkey/EnumerateGroupForwardKeys": {},
        "Hotkey/EnumerateGroupBackwardKeys": {},
        "Behavior": {"ShareInputState": "All", "ActiveByDefault": "False", "PreeditEnabledByDefault": "True",
                     "ShowInputMethodInformation": "False", "showInputMethodInformationWhenFocusIn": "False",
                     "AllowInputMethodForPassword": "False"},
    }


def classicui_sections(settings: dict) -> dict[str, dict[str, str]]:
    fonts = (settings.get("fonts") or {}) if isinstance(settings, dict) else {}
    font = str(fonts.get("sans") or "Inter")
    return {"": {"Theme": THEME, "DarkTheme": THEME, "UseDarkTheme": "False", "UseAccentColor": "False",
                 "Vertical Candidate List": "False", "Font": f'"{font} 11"', "MenuFont": f'"{font} 10"',
                 "PreferTextIcon": "False"}}


# ------------------------------------------------------------- the theme ----

def _rgb(hex_: str) -> tuple[int, int, int]:
    h = hex_.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def _fx(hex_: str, alpha: float = 1.0) -> str:
    """fcitx5's colour: #rrggbbaa."""
    r, g, b = _rgb(hex_)
    return f"#{r:02x}{g:02x}{b:02x}{round(alpha * 255):02x}"


def panel_svg(roles: dict, dark: bool, radius: int) -> str:
    """The candidate window: a colourless frosted pane with a hairline rim and a
    top light. Dense enough that the text reads over anything (the module's
    note on glass)."""
    s = 64
    fill = roles.get("surface") or roles["bg"]
    rim = "#ffffff" if dark else "#000000"
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{s}" height="{s}" viewBox="0 0 {s} {s}">\n'
            f'  <rect x=".5" y=".5" width="{s - 1}" height="{s - 1}" rx="{radius}" fill="{fill}" fill-opacity="{0.72 if dark else 0.78}"'
            f' stroke="{rim}" stroke-opacity="{0.14 if dark else 0.1}"/>\n'
            f'  <path d="M{radius + 1} 1.5H{s - radius - 1}" stroke="#ffffff" stroke-opacity="{0.22 if dark else 0.7}"/>\n'
            '</svg>\n')


def highlight_svg(roles: dict, dark: bool, radius: int) -> str:
    """The chosen candidate is lit glass: a white frosted fill, a bright rim and
    a top light, with the accent only as a soft glow under it. Never a solid
    accent fill; the text on it stays Colors.text."""
    s = 48
    glow = roles["accent"]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{s}" height="{s}" viewBox="0 0 {s} {s}">\n'
            '  <defs>\n'
            f'    <linearGradient id="g" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="{glow}" stop-opacity="{0.34 if dark else 0.26}"/>'
            f'<stop offset=".6" stop-color="{glow}" stop-opacity="0"/></linearGradient>\n'
            '  </defs>\n'
            f'  <rect x=".5" y=".5" width="{s - 1}" height="{s - 1}" rx="{radius}" fill="#ffffff" fill-opacity="{0.14 if dark else 0.62}"'
            f' stroke="#ffffff" stroke-opacity="{0.34 if dark else 0.9}"/>\n'
            f'  <rect x=".5" y=".5" width="{s - 1}" height="{s - 1}" rx="{radius}" fill="url(#g)"/>\n'
            f'  <path d="M{radius + 1} 1.5H{s - radius - 1}" stroke="#ffffff" stroke-opacity="{0.4 if dark else 0.85}"/>\n'
            '</svg>\n')


def theme_conf(roles: dict, radius: int, button: int) -> str:
    """theme.conf for the pieces above. Their corners stay whole through
    fcitx5's nine-slice scaling with margins a little over the radius."""
    text, dim = roles["text"], roles.get("textDim") or roles["text"]
    pm, hm = radius + 4, button + 3
    def margin(sec: str, l: int, t: int, r: int, b: int) -> str:
        return f"[{sec}]\nLeft={l}\nRight={r}\nTop={t}\nBottom={b}\n\n"
    return ("[Metadata]\nName=vitrum\nVersion=1\nAuthor=vitrum\n"
            "Description=Written by vitrum-theme from the palette. Do not edit.\n\n"
            "[InputPanel]\n"
            f"NormalColor={_fx(text)}\nHighlightCandidateColor={_fx(text)}\n"
            f"HighlightColor={_fx(text)}\nHighlightBackgroundColor={_fx(text, 0.0)}\n"
            f"CandidateLabelColor={_fx(dim)}\nHighlightCandidateLabelColor={_fx(text)}\n"
            f"CandidateCommentColor={_fx(dim)}\nHighlightCandidateCommentColor={_fx(text)}\n"
            "LabelTextSizeFactor=90\nCommentTextSizeFactor=90\n"
            "EnableBlur=True\nFullWidthHighlight=False\nPageButtonAlignment=Bottom\n\n"
            "[InputPanel/Background]\nImage=panel.svg\n\n"
            + margin("InputPanel/Background/Margin", pm, pm, pm, pm)
            + margin("InputPanel/BlurMargin", 0, 0, 0, 0)
            + "[InputPanel/Highlight]\nImage=highlight.svg\n\n"
            + margin("InputPanel/Highlight/Margin", hm, hm, hm, hm)
            + margin("InputPanel/Highlight/HighlightClickMargin", 0, 0, 0, 0)
            + margin("InputPanel/ContentMargin", 8, 7, 8, 7)
            + margin("InputPanel/TextMargin", 8, 5, 8, 5)
            + margin("InputPanel/ShadowMargin", 0, 0, 0, 0)
            + "[Menu]\n"
            f"NormalColor={_fx(text)}\nHighlightCandidateColor={_fx(text)}\nSpacing=2\nEnableBlur=True\n\n"
            "[Menu/Background]\nImage=panel.svg\n\n"
            + margin("Menu/Background/Margin", pm, pm, pm, pm)
            + "[Menu/Highlight]\nImage=highlight.svg\n\n"
            + margin("Menu/Highlight/Margin", hm, hm, hm, hm)
            + margin("Menu/ContentMargin", 6, 6, 6, 6)
            + margin("Menu/TextMargin", 8, 5, 8, 5)).rstrip("\n") + "\n"


def theme_files(roles: dict, dark: bool, settings: dict) -> dict[str, str]:
    from . import RADIUS_SCALE
    scale = RADIUS_SCALE.get(settings.get("density") if isinstance(settings, dict) else None, 1.0)
    radius, button = round(12 * scale), round(9 * scale)   # Tokens.radiusTile, radiusButton
    return {"theme.conf": theme_conf(roles, radius, button),
            "panel.svg": panel_svg(roles, dark, radius),
            "highlight.svg": highlight_svg(roles, dark, button)}


# ------------------------------------------------------------- niri's side ---

def environment_kdl() -> str:
    rows = "".join(f'    {k} "{v}"\n' for k, v in ENVIRONMENT)
    return "environment {\n" + rows + "}\n"


def autostart_override() -> str:
    """fcitx5's package starts it from /etc/xdg/autostart in every session. vitrum-im
    does that here, and nowhere else should have it: on niri's own layouts it would
    take the text fields' keys from under them."""
    return "[Desktop Entry]\nType=Application\nName=Fcitx 5\nHidden=true\n# Written by vitrum: vitrum-im starts it.\n"


def niri_binds_kdl() -> str:
    """Alt+Shift, from niri (fires on release, and only if nothing else was
    pressed): a text field need not have the focus for it to switch, and an
    Alt+Shift+key of some app still works. Allowed at the lock, where a
    password may be in another keymap (vitrum-im then skips the engines)."""
    return ('binds {\n    Alt+Shift allow-when-locked=true {\n        release { spawn "vitrum-im" "next"; }\n'
            '    }\n}\n')


def niri_takes_hotkey(niri: str | None = None, run=subprocess.run) -> bool:
    """Whether this niri has release binds on bare modifiers (after 26.04).
    A config it cannot parse would cost the user the whole desktop."""
    path = niri or shutil.which("niri") or "/usr/local/bin/niri"
    with tempfile.TemporaryDirectory() as tmp:
        cfg = Path(tmp) / "config.kdl"
        cfg.write_text(niri_binds_kdl(), encoding="utf-8")
        try:
            return run([path, "validate", "-c", str(cfg)], capture_output=True, timeout=10).returncode == 0
        except (OSError, subprocess.SubprocessError):
            return False


def strip_group_options(options: str) -> str:
    """xkb's options without its layout switching: with one layout grp:* does
    nothing but turn Alt+Shift's Shift into ISO_Next_Group, which then matches
    no bind and no fcitx5 hotkey."""
    return ",".join(o for o in (x.strip() for x in str(options or "").split(",")) if o and not o.startswith("grp:"))


# ---------------------------------------------------------- electron flags ---

def flags_block() -> str:
    return "\n".join((FLAGS_BEGIN, *ELECTRON_FLAGS, FLAGS_END))


def with_flags(text: str, on: bool = True) -> str:
    """A flags file with vitrum's block in place, or taken out; the rest is yours."""
    pat = re.compile(re.escape(FLAGS_BEGIN) + r".*?" + re.escape(FLAGS_END) + r"\n?", re.S)
    rest = pat.sub("", str(text or ""))
    if not on:
        return rest
    rest = rest.rstrip("\n")
    return (rest + "\n" if rest else "") + flags_block() + "\n"


def sync_flags(home: Path, have=shutil.which, on: bool = True) -> list[Path]:
    """electron-flags.conf always (Arch's wrapper reads it for every Electron),
    the others for the apps that are there. With on=False, the block comes out."""
    written = []
    for name, command in FLAG_FILES.items():
        path = home / name
        if on and command and not have(command) and not path.exists():
            continue
        try:
            old = path.read_text(encoding="utf-8")
        except OSError:
            old = ""
        new = with_flags(old, on)
        if new == old or (not on and not path.exists()):
            continue
        if not on and not new.strip():
            path.unlink(missing_ok=True)
        else:
            _write(path, new)
        written.append(path)
    return written


# --------------------------------------------------------------- the sync ----

def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    tmp.replace(path)


def _keep_original(path: Path, data: Path) -> None:
    """A file of the user's from before vitrum, once."""
    mark = data / "fcitx-managed"
    if path.is_file() and not mark.exists():
        side = path.with_name(path.name + ".pre-vitrum")
        if not side.exists():
            shutil.copy2(path, side)


def _running(run=subprocess.run) -> bool:
    try:
        return run(["fcitx5-remote", "--check"], capture_output=True, timeout=3).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def _dbus(method: str, *args: str, run=subprocess.run) -> bool:
    cmd = ["gdbus", "call", "--session", "--dest", "org.fcitx.Fcitx5", "--object-path", "/controller",
           "--method", f"org.fcitx.Fcitx.Controller1.{method}", *args]
    try:
        return run(cmd, capture_output=True, timeout=5).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def _gvariant_items(ims: list[str]) -> str:
    return "[" + ", ".join(f"('{n}', '')" for n in ims) + "]"


def apply_running(ims: list[str] | None, layout: str, reload_config: bool, reload_theme: bool, run=subprocess.run) -> None:
    """Tell a running fcitx5. It rereads config and addons when asked; the
    profile it only reads at start, so the list goes over D-Bus."""
    if not _running(run):
        return
    if ims:
        _dbus("SetInputMethodGroupInfo", GROUP, layout, _gvariant_items(ims), run=run)
    if reload_config:
        _dbus("ReloadConfig", run=run)
    if reload_theme:
        _dbus("ReloadAddonConfig", "classicui", run=run)


def sync(settings: dict, palette: dict, scheme: str, data: Path, base_xkb: dict | None = None,
         niri_hotkey: bool = False, run=subprocess.run) -> list:
    """vitrum-theme's hook: fcitx5's files from Settings and the palette, only
    with the component on. Returns what was written."""
    if not enabled(data):
        return []
    pairs = entries(settings, base_xkb)
    if not pairs:
        return []
    written = []
    home = config_home() / "fcitx5"
    themes = data_home() / "fcitx5" / "themes" / THEME
    data = Path(data)

    profile = home / "profile"
    ims = input_methods(pairs)
    layout = fcitx_layout(*base_layout(pairs))
    try:
        old = profile.read_text(encoding="utf-8")
    except OSError:
        old = ""
    new_profile = parse_profile(old) != (ims, layout)
    if new_profile:
        _keep_original(profile, data)
        _write(profile, profile_text(ims, layout))
        written.append(profile)

    def merged(path: Path, ours: dict) -> bool:
        try:
            before = path.read_text(encoding="utf-8")
        except OSError:
            before = ""
        after = merge_ini(before, ours)
        if after == before:
            return False
        _keep_original(path, data)
        _write(path, after)
        written.append(path)
        return True

    new_config = merged(home / "config", config_sections(niri_hotkey))
    new_ui = merged(home / "conf" / "classicui.conf", classicui_sections(settings))

    roles = palette.get(scheme) or next(iter(palette.values()))
    new_theme = False
    for name, text in theme_files(roles, scheme == "dark", settings).items():
        path = themes / name
        if not path.is_file() or path.read_text(encoding="utf-8") != text:
            _write(path, text)
            written.append(path)
            new_theme = True

    autostart = config_home() / "autostart" / "org.fcitx.Fcitx5.desktop"
    if not autostart.exists():
        _write(autostart, autostart_override())
        written.append(autostart)

    written += sync_flags(config_home())
    if written:
        (data / "fcitx-managed").touch()
    apply_running(ims if new_profile else None, layout, new_config, new_ui or new_theme, run)
    return written
