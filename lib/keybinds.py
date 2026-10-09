#!/usr/bin/env python3
"""
Turn keybinds.md into a niri `binds { }` block.

The markdown is the source of truth. It is written for humans -- two-column
tables of `| `Key` | Plain english action |` -- so this reads that shape rather
than demanding a machine format:

  * key cells may hold alternatives (`Mod+Left/H`, `` `Mod+T` / `Mod+Return` ``)
    and ranges (`Mod+1-9`), both of which expand into several binds
  * action cells are matched against a phrase table, longest phrase first
  * anything that does not match is reported, not silently dropped

Usage:  keybinds.py <keybinds.md> <out.kdl> <out.json>
"""

from __future__ import annotations

import json
import re
import sys

# --------------------------------------------------------------- key names ---

# niri speaks xkb keysym names. The markdown speaks keyboard.
KEY_ALIASES = {
    "super": "Mod",
    "mod": "Mod",
    "cmd": "Mod",
    "command": "Mod",
    "ctrl": "Ctrl",
    "control": "Ctrl",
    "alt": "Alt",
    "option": "Alt",
    "opt": "Alt",
    "shift": "Shift",
    "[": "BracketLeft",
    "]": "BracketRight",
    ",": "Comma",
    ".": "Period",
    "/": "Slash",
    "\\": "Backslash",
    ";": "Semicolon",
    "'": "Apostrophe",
    "`": "Grave",
    "-": "Minus",
    "=": "Equal",
    "minus": "Minus",
    "equal": "Equal",
    "plus": "Equal",
    "return": "Return",
    "enter": "Return",
    "esc": "Escape",
    "escape": "Escape",
    "space": "Space",
    "tab": "Tab",
    "print": "Print",
    "printscreen": "Print",
    "pageup": "Page_Up",
    "page_up": "Page_Up",
    "pagedown": "Page_Down",
    "page_down": "Page_Down",
    "home": "Home",
    "end": "End",
    "left": "Left",
    "right": "Right",
    "up": "Up",
    "down": "Down",
    "wheelup": "WheelScrollUp",
    "wheeldown": "WheelScrollDown",
    "wheelscrollup": "WheelScrollUp",
    "wheelscrolldown": "WheelScrollDown",
    "wheelleft": "WheelScrollLeft",
    "wheelright": "WheelScrollRight",
}

MODIFIERS = ("Mod", "Ctrl", "Alt", "Shift")


def norm_key(token: str) -> str:
    t = token.strip()
    if not t:
        return ""
    low = t.lower()
    if low in KEY_ALIASES:
        return KEY_ALIASES[low]
    if t.startswith("XF86"):
        return t
    if len(t) == 1:
        return t.upper() if t.isalpha() else KEY_ALIASES.get(t, t)
    # F1..F12, Page_Up, already-correct keysyms
    return t[0].upper() + t[1:]


def parse_combo(cell: str):
    """Return a list of (combo, index_or_None) from one key cell."""
    # Alternatives written outside the combo:  `Mod+T` / `Mod+Return`
    chunks = [c for c in re.split(r"`\s*/\s*`", cell.strip().strip("`")) if c]
    out = []
    for chunk in chunks:
        chunk = chunk.strip().strip("`").strip()
        if not chunk:
            continue

        parts = chunk.split("+")
        mods = [norm_key(p) for p in parts[:-1]]
        tail = parts[-1].strip()

        # Range: Mod+1-9
        m = re.fullmatch(r"(\d)\s*[-–]\s*(\d)", tail)
        if m:
            lo, hi = int(m.group(1)), int(m.group(2))
            for n in range(lo, hi + 1):
                out.append(("+".join(mods + [str(n)]), n))
            continue

        # Alternatives inside the combo: Mod+Left/H, XF86AudioPlay/Pause
        if "/" in tail and tail != "/":
            alts = [a for a in tail.split("/") if a]
            for a in alts:
                a = a.strip()
                # XF86AudioPlay/Pause -> XF86AudioPlay, XF86AudioPause
                if alts[0].startswith("XF86") and not a.startswith("XF86"):
                    prefix = re.match(r"(XF86[A-Za-z]*?)(?=[A-Z][a-z]*$)", alts[0])
                    a = (prefix.group(1) if prefix else "XF86") + a
                out.append(("+".join(mods + [norm_key(a)]), None))
            continue

        out.append(("+".join(mods + [norm_key(tail)]), None))
    return out


# ------------------------------------------------------------- the actions ---
#
# Each entry maps a normalised phrase to what niri should do. A value is either
#   ("niri", "<action ...>")     a raw niri action
#   ("spawn", "<shell command>") run through sh -c
#   ("shell", "<ipc target ...>") talk to the running Quickshell desktop
# `{n}` in the value is replaced by the number a range expansion produced.

A = {
    # --- shell surfaces ---
    "launcher":                              ("shell", "launcher toggle"),
    "app launcher":                          ("shell", "launcher toggle"),
    "overview":                              ("niri", "toggle-overview"),
    "window switcher next":                  ("shell", "switcher next"),
    "window switcher previous":              ("shell", "switcher prev"),
    "clipboard history":                     ("shell", "launcher clipboard"),
    "emoji picker":                          ("shell", "launcher emoji"),
    "keybind cheatsheet":                    ("shell", "keybinds toggle"),
    "all keybinds":                          ("shell", "keybinds toggle"),
    "game hud (mangohud)":                   ("shell", "games hud"),
    "game mode":                             ("shell", "games toggle"),
    "colour picker":                         ("shell", "picker start"),
    "settings":                              ("spawn", "vitrum-settings"),
    "about this computer":                   ("spawn", "vitrum-about"),
    "disk utility":                          ("spawn", "vitrum-disks"),
    "lock screen":                           ("shell", "lock lock"),
    "toggle light dark":                     ("shell", "scheme toggle"),
    "cycle the material":                    ("shell", "materials cycle"),
    "do not disturb":                        ("shell", "notifications dnd"),
    "clear notifications":                   ("shell", "notifications clear"),
    "power menu":                            ("shell", "power toggle"),
    "control centre":                        ("shell", "panel open control"),
    "control center":                        ("shell", "panel open control"),
    "notification centre":                   ("shell", "centre toggle"),
    "notification center":                   ("shell", "centre toggle"),
    "show or hide the dock":                 ("shell", "dock toggle"),
    "edit desktop widgets":                  ("shell", "widgets edit"),
    "next wallpaper":                        ("shell", "wallpaper next"),
    "wallpaper picker":                      ("shell", "wallpaper picker"),

    # --- capture ---
    "capture":                               ("shell", "capture open"),
    "region screenshot":                     ("shell", "capture region"),
    "region ocr":                            ("shell", "capture ocr"),
    "screenshot niri native":                ("niri", "screenshot"),
    "screenshot current screen":             ("niri", "screenshot-screen"),
    "screenshot current window":             ("niri", "screenshot-window"),

    # --- windows ---
    "close window":                          ("niri", "close-window"),
    "maximize column keeps gaps":            ("niri", "maximize-column"),
    "maximize column":                       ("niri", "maximize-column"),
    "toggle fullscreen":                     ("niri", "fullscreen-window"),
    "toggle floating tiling":                ("niri", "toggle-window-floating"),
    "switch focus between floating and tiling layers":
                                             ("niri", "switch-focus-between-floating-and-tiling"),
    "focus column left":                     ("niri", "focus-column-left"),
    "focus column right":                    ("niri", "focus-column-right"),
    "focus window up":                       ("niri", "focus-window-up"),
    "focus window down":                     ("niri", "focus-window-down"),
    "focus first column":                    ("niri", "focus-column-first"),
    "focus last column":                     ("niri", "focus-column-last"),
    "move column left":                      ("niri", "move-column-left"),
    "move column right":                     ("niri", "move-column-right"),
    "move window up":                        ("niri", "move-window-up"),
    "move window down":                      ("niri", "move-window-down"),
    "move column to first":                  ("niri", "move-column-to-first"),
    "move column to last":                   ("niri", "move-column-to-last"),

    # --- column layout ---
    "cycle preset column widths":            ("niri", "switch-preset-column-width"),
    "cycle preset window heights":           ("niri", "switch-preset-window-height"),
    "reset window height":                   ("niri", "reset-window-height"),
    "center focused column":                 ("niri", "center-column"),
    "shrink column width 10":                ("niri", 'set-column-width "-10%"'),
    "grow column width 10":                  ("niri", 'set-column-width "+10%"'),
    "shrink window height 10":               ("niri", 'set-window-height "-10%"'),
    "grow window height 10":                 ("niri", 'set-window-height "+10%"'),
    "consume expel window left stack or unstack":
                                             ("niri", "consume-or-expel-window-left"),
    "consume expel window right stack or unstack":
                                             ("niri", "consume-or-expel-window-right"),

    # --- monitors ---
    "focus monitor left":                    ("niri", "focus-monitor-left"),
    "focus monitor right":                   ("niri", "focus-monitor-right"),
    "focus monitor up":                      ("niri", "focus-monitor-up"),
    "focus monitor down":                    ("niri", "focus-monitor-down"),
    "move column to monitor left":           ("niri", "move-column-to-monitor-left"),
    "move column to monitor right":          ("niri", "move-column-to-monitor-right"),
    "move column to monitor up":             ("niri", "move-column-to-monitor-up"),
    "move column to monitor down":           ("niri", "move-column-to-monitor-down"),

    # --- workspaces ---
    "focus workspace 1 9":                   ("niri", "focus-workspace {n}"),
    "move column to workspace 1 9":          ("niri", "move-column-to-workspace {n}"),
    "focus workspace down":                  ("niri", "focus-workspace-down"),
    "focus workspace up":                    ("niri", "focus-workspace-up"),
    "move column to workspace down":         ("niri", "move-column-to-workspace-down"),
    "move column to workspace up":           ("niri", "move-column-to-workspace-up"),
    "focus workspace down mouse":            ("niri", "focus-workspace-down"),
    "focus workspace up mouse":              ("niri", "focus-workspace-up"),

    # --- apps ---
    "terminal":                              ("spawn", "kitty"),
    "file manager nautilus":                 ("spawn", "nemo"),
    "file manager":                          ("spawn", "nemo"),
    "finder":                                ("spawn", "nemo"),
    "browser":                               ("spawn", "xdg-open https://duckduckgo.com"),

    # --- session ---
    "quit niri":                             ("niri", "quit"),
    "power off monitors":                    ("niri", "power-off-monitors"),
    "toggle keyboard shortcuts inhibit":     ("niri", "toggle-keyboard-shortcuts-inhibit"),

    # --- media, routed through the shell so the OSD appears ---
    "volume up":                             ("shell", "osd volume up"),
    "volume down":                           ("shell", "osd volume down"),
    "toggle mute":                           ("shell", "osd mute"),
    "toggle mic mute":                       ("shell", "osd mic"),
    "toggle mute keyboard":                  ("shell", "osd mute"),
    "play pause":                            ("shell", "media play"),
    "play pause keyboard":                   ("shell", "media play"),
    "next track":                            ("shell", "media next"),
    "next track keyboard":                   ("shell", "media next"),
    "previous track":                        ("shell", "media prev"),
    "previous track keyboard":               ("shell", "media prev"),
    "brightness up":                         ("shell", "osd brightness up"),
    "brightness down":                       ("shell", "osd brightness down"),
}

# Binds that must keep working while the screen is locked or a client grabs
# the keyboard.
ALLOW_INHIBITING = {"quit", "power-off-monitors", "toggle-keyboard-shortcuts-inhibit"}
ALLOW_WHEN_LOCKED = {
    "audio volume-up", "audio volume-down", "audio mute", "audio mic-mute",
    "brightness up", "brightness down",
    "media play-pause", "media next", "media prev",
}
REPEATING = {
    "audio volume-up", "audio volume-down", "brightness up", "brightness down",
    "focus-column-left", "focus-column-right", "focus-window-up", "focus-window-down",
    "set-column-width", "set-window-height",
}


def normalise_phrase(text: str) -> str:
    """Reduce an action cell to comparable words.

    Parenthesised text is kept, not dropped: "(next)" in "Window switcher
    (next)" is the only thing distinguishing it from "(previous)".
    """
    t = text.strip()
    t = re.sub(r"[`*_()]", " ", t)
    t = re.sub(r"[^\w\s]", " ", t)          # punctuation, arrows, %, /, —
    t = re.sub(r"\b(the|a|an|to|of|and|or)\b", " ", t, flags=re.I)
    t = re.sub(r"\s+", " ", t).strip().lower()
    return t


# The table above is written for readability; match against normalised keys so
# "Move column to first" and "move column first" are the same lookup.
A_NORM = {normalise_phrase(k): v for k, v in A.items()}


def lookup(phrase: str):
    key = normalise_phrase(phrase)
    if key in A_NORM:
        return A_NORM[key]
    # The markdown carries extra words the table does not ("⌘ Cycle preset
    # column widths ⅓ → ½ → ⅔"). Accept the longest table entry that the
    # phrase starts with; only then fall back to the other direction.
    best = None
    for k in A_NORM:
        if key.startswith(k) and (best is None or len(k) > len(best)):
            best = k
    if best is None:
        for k in A_NORM:
            if k.startswith(key) and (best is None or len(k) < len(best)):
                best = k
    return A_NORM[best] if best else None


# ------------------------------------------------------------------- emit ----

def kdl_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def emit(combo: str, kind: str, value: str, title: str) -> str:
    opts = [f'hotkey-overlay-title="{kdl_escape(title)}"']
    if any(value.startswith(r) or r in value for r in REPEATING):
        opts.append("repeat=true")
    else:
        opts.append("repeat=false")
    if value in ALLOW_WHEN_LOCKED:
        opts.append("allow-when-locked=true")
    if value.split()[0] in ALLOW_INHIBITING:
        opts.append("allow-inhibiting=false")

    if kind == "niri":
        body = value + ";"
    elif kind == "spawn":
        body = 'spawn "sh" "-c" "%s";' % kdl_escape(value)
    else:  # shell
        args = " ".join('"%s"' % a for a in value.split())
        body = f'spawn "vitrum-ipc" {args};'

    return "    %s %s { %s }" % (combo, " ".join(opts), body)


ROW = re.compile(r"^\|(?P<key>[^|]+)\|(?P<action>[^|]+)\|(?P<rest>.*)$")


def main() -> int:
    src, out_kdl, out_json = sys.argv[1], sys.argv[2], sys.argv[3]
    text = open(src, encoding="utf-8").read()

    lines: list[str] = []
    catalogue: list[dict] = []
    seen: set[str] = set()
    unmatched: list[str] = []
    section = "General"

    for raw in text.splitlines():
        line = raw.rstrip()

        if line.startswith("#"):
            section = line.lstrip("#").strip()
            continue

        m = ROW.match(line)
        if not m:
            continue

        key_cell = m.group("key").strip()
        act_cell = m.group("action").strip()

        # Table headers and separator rows.
        if not key_cell or set(key_cell) <= set("-: "):
            continue
        if key_cell.lower() in ("key", "keys") or act_cell.lower() == "action":
            continue
        # Commented out by the user.
        if key_cell.startswith("!"):
            continue
        # The vocabulary table at the top of the file describes syntax, not binds.
        if "`" not in key_cell and "+" not in key_cell and not key_cell.startswith("XF86"):
            continue

        resolved = lookup(act_cell)
        if resolved is None:
            unmatched.append(f"{key_cell}  ->  {act_cell}")
            continue
        kind, template = resolved

        for combo, n in parse_combo(key_cell):
            if not combo or combo in seen:
                continue
            value = template.replace("{n}", str(n)) if n is not None else template
            if "{n}" in value:
                continue
            seen.add(combo)
            title = re.sub(r"\s+", " ", act_cell).strip()
            lines.append(emit(combo, kind, value, title))
            catalogue.append(
                {"section": section, "keys": combo, "action": value,
                 "kind": kind, "title": title}
            )

    header = (
        "// Generated from keybinds.md by lib/keybinds.py. Do not edit.\n"
        "// Change keybinds.md and run: ./install.sh --only session\n"
        "binds {\n"
        "    Mod+Shift+Slash { show-hotkey-overlay; }\n"
    )
    with open(out_kdl, "w", encoding="utf-8") as f:
        f.write(header + "\n".join(lines) + "\n}\n")

    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(catalogue, f, indent=2)

    print(f"keybinds: {len(catalogue)} binds from {len(set(c['section'] for c in catalogue))} sections")
    if unmatched:
        print(f"keybinds: {len(unmatched)} rows had no known action and were skipped:")
        for u in unmatched:
            print(f"    {u}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
