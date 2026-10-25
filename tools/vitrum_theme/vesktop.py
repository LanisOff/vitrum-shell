"""The vitrum theme for Vesktop (Discord with Vencord built in).

Vesktop 1.6 / Vencord on Linux (read from their sources, Vesktop v1.6.8 and
Vencord main, and checked on an installed vesktop-bin 1.6.8):
  data dir    $XDG_CONFIG_HOME/vesktop (Electron's userData; VENCORD_USER_DATA_DIR
              overrides it); the Flatpak (dev.vencord.Vesktop) keeps it in
              ~/.var/app/dev.vencord.Vesktop/config/vesktop.
  themes      <data dir>/themes/*.css. Every .css there is listed as a theme
              (its name from the BetterDiscord-style /** @name … */ header);
              an enabled one is loaded as @import "vencord:///themes/<file>?v=<now>".
  enabled     <data dir>/settings/settings.json (Vencord's own settings, written
              by Vencord as JSON.stringify(…, null, 4)), the list enabledThemes
              of file names. Vencord reads this file once at start and writes
              it whole whenever one of its settings changes: an edit made while
              Vesktop runs shows after a restart, and a watcher keeps it until
              then (see watch()).
  hot reload  the themes folder is watched (fs.watch): any write there makes
              Vencord import the enabled themes again with a new ?v=, so new
              colours show at once in a running Vesktop.
  window      Vesktop's window has the app id "vesktop" (StartupWMClass too).

No transparency: Vencord's `transparent` setting is left as the user has it.
The window's background is vitrum's solid bg; Discord's panels are glass
layers over it (fixed alphas, hairline rims, lit glass for "on").

The theme is one file, assets/vesktop/vitrum.theme.css. Its colours sit in a
generated block between BEGIN and END that apply() rewrites; the rest of the
file is the shipped theme. One file because Vencord would list a separate
colours file as a second theme, and would not re-import it on a change (the
?v= cache-buster is only on the theme's own URL).

apply() is what vitrum-theme runs (gated by sync()) and what
`vitrum-vesktop-theme apply` runs.
"""
from __future__ import annotations

import colorsys
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

THEME_FILE = "vitrum.theme.css"
BEGIN = "/* vitrum:colours begin (vitrum-theme rewrites this block; edit outside it) */"
END = "/* vitrum:colours end */"
COMPONENT = "vesktop_theme"
FLATPAK_ID = "dev.vencord.Vesktop"
# The Vesktop client's processes: the launcher (/usr/bin/vesktop, /opt/Vesktop/vesktop),
# Electron running its app.asar, the Flatpak. Not a bare "vesktop" anywhere in the
# command line, which would also find this helper and its watcher.
PGREP_PATTERN = r"(^|[ /])vesktop( |$)|vesktop/app\.asar|dev\.vencord\.Vesktop"


class VesktopThemeError(Exception):
    """A failure with a short message for people (the helper prints it)."""


# ---------------------------------------------------------------- paths -----

def _home() -> Path:
    return Path(os.environ.get("HOME") or Path.home())


def config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME") or _home() / ".config")


def data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME") or _home() / ".local" / "share")


def cache_home() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME") or _home() / ".cache") / "vitrum"


def vesktop_dir() -> Path:
    """Vesktop's data dir: the native one, else the Flatpak's, else where the
    native one will be."""
    env = os.environ.get("VENCORD_USER_DATA_DIR")
    if env:
        return Path(env)
    native = config_home() / "vesktop"
    for p in (native, _home() / ".var" / "app" / FLATPAK_ID / "config" / "vesktop"):
        if p.is_dir():
            return p
    return native


def themes_dir() -> Path:
    return vesktop_dir() / "themes"


def theme_file() -> Path:
    return themes_dir() / THEME_FILE


def settings_file() -> Path:
    """Vencord's settings (not Vesktop's own settings.json beside it)."""
    return vesktop_dir() / "settings" / "settings.json"


def state_file() -> Path:
    return data_home() / "vitrum" / "vesktop-theme.json"


def theme_source() -> Path | None:
    """The theme as shipped: beside the repo's tools, or where the installer
    put it (~/.local/share/vitrum/vesktop/vitrum.theme.css)."""
    env = os.environ.get("VITRUM_VESKTOP_THEME_SRC")
    here = Path(__file__).resolve().parent
    for p in ([Path(env)] if env else []) + [here.parents[1] / "assets" / "vesktop" / THEME_FILE,
                                             data_home() / "vitrum" / "vesktop" / THEME_FILE]:
        if p.is_file():
            return p
    return None


# --------------------------------------------------------------- status -----

def app_found(which=None) -> bool:
    """Vesktop is installed: its launcher, a package's files, the Flatpak, or a
    data dir it has made (it has run here)."""
    if (which or shutil.which)("vesktop"):
        return True
    env = os.environ.get("VITRUM_VESKTOP_PREFIXES")       # the system places, for tests
    if env is not None:
        system = [Path(p) for p in env.split(":") if p]
    else:
        system = [Path("/usr/lib/vesktop"), Path("/opt/Vesktop"), Path("/opt/vesktop"),
                  Path("/var/lib/flatpak/app") / FLATPAK_ID]
    places = system + [data_home() / "flatpak" / "app" / FLATPAK_ID, vesktop_dir() / "settings"]
    return any(p.exists() for p in places)


def read_settings(path: Path | None = None) -> dict | None:
    """Vencord's settings, {} when there is none yet, None when unreadable."""
    path = path or settings_file()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def enabled_themes(path: Path | None = None) -> list:
    cfg = read_settings(path) or {}
    v = cfg.get("enabledThemes")
    return [t for t in v if isinstance(t, str)] if isinstance(v, list) else []


def vesktop_pid(run=subprocess.run) -> int | None:
    """The Vesktop client's main process (the oldest that matches), or None."""
    try:
        r = run(["pgrep", "-u", str(os.getuid()), "-o", "-f", PGREP_PATTERN],
                capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    try:
        return int((r.stdout or "").split()[0])
    except (IndexError, ValueError):
        return None


def vesktop_running(run=subprocess.run) -> bool:
    return vesktop_pid(run) is not None


def installed() -> bool:
    return theme_file().is_file()


def status(run=subprocess.run) -> dict:
    inst = installed()
    return {"vesktop": app_found(), "installed": inst, "active": inst and THEME_FILE in enabled_themes(),
            "running": vesktop_running(run), "themeDir": str(themes_dir())}


# --------------------------------------------------------------- colour -----

def theme_flag(settings: dict, key: str) -> bool:
    t = ((settings.get("vesktop") or {}).get("theme") or {}) if isinstance(settings, dict) else {}
    return t.get(key, True) is not False if isinstance(t, dict) else True


# Discord paints with its own theme's colours wherever the theme does not reach
# (hundreds of rules), and its light theme cannot be switched from here (it is
# an account setting), so the theme always uses the palette's dark scheme on
# every Discord theme class. The wallpaper's hue, the accent pair and the
# danger/warning/success roles still follow vitrum.
ROLE_VARS = (("bg", "bg"), ("surface", "surface"), ("surface-high", "surfaceHigh"),
             ("surface-highest", "surfaceHighest"), ("outline", "outline"), ("text", "text"),
             ("text-dim", "textDim"), ("accent", "accent"), ("accent2", "accent2"), ("danger", "danger"),
             ("warning", "warning"), ("success", "success"))
FALLBACK = {"surfaceHighest": "surfaceHigh", "outline": "surfaceHigh", "warning": "#fdd663", "success": "#81c995"}
GLOW_CAP = 0.62


def _rgb(hex_: str) -> tuple:
    h = hex_.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _triplet(hex_: str) -> str:
    return ", ".join(str(c) for c in _rgb(hex_))


def _cap_lightness(hex_: str, cap: float) -> str:
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in _rgb(hex_)))
    return "#" + "".join(f"{round(c * 255):02x}" for c in colorsys.hls_to_rgb(h, min(l, cap), s))


def _roles(palette: dict) -> dict:
    """The dark scheme's roles, with accent2 (computed if the palette predates
    it) and the roles an old palette may lack."""
    from . import accent2
    roles = dict(palette.get("dark") or next(iter(palette.values())))
    if not roles.get("accent2"):
        roles["accent2"] = accent2(roles["accent"], -100.0, True)
    for role, fb in FALLBACK.items():
        if not roles.get(role):
            roles[role] = roles.get(fb) or fb
    return roles


def colours_block(roles: dict, note: str = "") -> str:
    """The generated block: the palette roles as --vt-* (hex and "r, g, b") and
    the glow colour, between BEGIN and END."""
    lines = [f"  --vt-{var}: {roles[role]};" for var, role in ROLE_VARS]
    lines += [f"  --vt-{var}-rgb: {_triplet(roles[role])};" for var, role in ROLE_VARS]
    # The glow under lit glass and an on switch's track: the accent, kept from
    # going pastel so "on" still reads on a dark pane.
    lines.append(f"  --vt-glow-rgb: {_triplet(_cap_lightness(roles['accent'], GLOW_CAP))};")
    head = f"/* palette: {note} */\n" if note else ""
    return f"{BEGIN}\n{head}:root {{\n" + "\n".join(lines) + f"\n}}\n{END}"


_BLOCK = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)


def read_block(text: str) -> str | None:
    m = _BLOCK.search(text)
    return m.group(0) if m else None


def with_block(text: str, block: str) -> str:
    """The theme with its generated block replaced; nothing else changes."""
    if not _BLOCK.search(text):
        raise VesktopThemeError(f"{theme_file()} has no vitrum colour block; run: vitrum-vesktop-theme reinstall")
    return _BLOCK.sub(lambda _m: block, text, count=1)


# ---------------------------------------------------------------- write -----

def _write(path: Path, text: str) -> bool:
    """Atomically, only when it changed; the file's mode is kept. The temporary
    name does not end in .css, so Vencord never lists it as a theme."""
    path = Path(path)
    try:
        if path.read_text(encoding="utf-8") == text:
            return False
        mode = path.stat().st_mode & 0o777
    except OSError:
        mode = None
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name("." + path.name + ".vitrum-tmp")
    tmp.write_text(text, encoding="utf-8")
    if mode is not None:
        os.chmod(tmp, mode)
    tmp.replace(path)
    return True


def set_enabled(enabled: bool, path: Path | None = None) -> bool:
    """Put vitrum's theme in Vencord's enabledThemes, or take it out. Only that
    key changes; every other one stays as Vencord wrote it, in its order.
    → whether the file changed."""
    path = path or settings_file()
    cfg = read_settings(path)
    if cfg is None:
        raise VesktopThemeError(f"{path} is not valid JSON; fix it, or delete it and Vesktop recreates it")
    if not enabled and not path.is_file():
        return False
    raw = cfg.get("enabledThemes")
    themes = list(raw) if isinstance(raw, list) else []
    if enabled and THEME_FILE not in themes:
        themes.append(THEME_FILE)
    elif not enabled:
        themes = [t for t in themes if t != THEME_FILE]
    if raw == themes:
        return False
    cfg["enabledThemes"] = themes
    return _write(path, json.dumps(cfg, indent=4, ensure_ascii=False))


def _state() -> dict:
    try:
        s = json.loads(state_file().read_text())
        return s if isinstance(s, dict) else {}
    except (OSError, ValueError):
        return {}


def _save_state(state: dict) -> None:
    _write(state_file(), json.dumps(state, indent=1) + "\n")


def apply(settings: dict, palette: dict, *, sync_colours: bool | None = None, enforce: bool = True,
          note: str = "", run=subprocess.run, spawn=None) -> list:
    """Rewrite the installed theme's colour block and set enabledThemes from
    vesktop.theme.enabled. → what changed.

    sync_colours=False keeps the colours already in the theme; by default it
    follows vesktop.theme.sync. enforce=False (vitrum-theme's runs) changes enabledThemes only when
    vesktop.theme.enabled changed since the last run, so a theme switched off
    in Vencord's own settings stays off."""
    tf = theme_file()
    if not tf.is_file():
        raise VesktopThemeError(f"the vitrum theme is not installed in {themes_dir()}; run: vitrum-vesktop-theme install")
    changed = []
    if sync_colours is None:
        sync_colours = theme_flag(settings, "sync")
    if sync_colours:
        text = tf.read_text(encoding="utf-8")
        if _write(tf, with_block(text, colours_block(_roles(palette), note or "current"))):
            changed.append(str(tf))
    state = _state()
    enabled = theme_flag(settings, "enabled")
    did = False
    if enforce or state.get("enabled") != enabled or state.get("pending"):
        did = set_enabled(enabled)
        if did:
            changed.append(str(settings_file()))
    running = vesktop_running(run)
    # Vencord keeps its settings in memory and writes them whole when one
    # changes, which would undo our edit made while Vesktop runs: a watcher
    # puts it back until the next Vesktop has read the file.
    state["pending"] = bool(running and (did or state.get("pending")))
    state["enabled"] = enabled
    _save_state(state)
    if state["pending"]:
        (spawn or spawn_watch)()
    return changed


def needs_restart(run=subprocess.run) -> bool:
    """A change to enabledThemes waits for Vesktop's next start."""
    return bool(_state().get("pending")) and vesktop_running(run)


def watch(run=subprocess.run, sleep=None, timeout: float = 12 * 3600, step: float = 0.5) -> str:
    """Keep enabledThemes as vitrum's settings want it while Vesktop runs:
    whenever Vencord writes its own copy back, write ours again. Ends when
    Vesktop is gone with the file right, when a new Vesktop has started (it
    read the file), or after timeout. → why it ended."""
    import time
    sleep = sleep or time.sleep
    first = vesktop_pid(run)
    waited = 0.0
    why = "timeout"
    while waited < timeout:
        want = _state().get("enabled")
        if not isinstance(want, bool) or not installed():
            return "gone"
        if (THEME_FILE in enabled_themes()) != want:
            try:
                set_enabled(want)
            except VesktopThemeError:
                return "settings"
            continue
        pid = vesktop_pid(run)
        if pid is None:
            why = "quit"
            break
        if first is not None and pid != first:
            why = "restarted"
            break
        first = first if first is not None else pid
        sleep(step)
        waited += step
    if why != "timeout":
        state = _state()
        state["pending"] = False
        _save_state(state)
    return why


def spawn_watch() -> None:
    """Start one watcher in the background (a second one is not started)."""
    import fcntl
    lock = cache_home() / "vesktop-watch.lock"
    try:
        lock.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(lock, os.O_RDWR | os.O_CREAT, 0o600)
    except OSError:
        return
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        os.close(fd)
        return          # one is running
    os.close(fd)        # the child takes the lock itself
    env = dict(os.environ, PYTHONPATH=str(Path(__file__).resolve().parents[1]))
    try:
        subprocess.Popen([sys.executable, "-m", "vitrum_theme.vesktop", "watch"], env=env,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    except OSError:
        pass


def _watch_main() -> int:
    import fcntl
    lock = cache_home() / "vesktop-watch.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(lock, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 0
    watch()
    return 0


def sync(settings: dict, palette: dict, data: Path, note: str = "") -> list:
    """vitrum-theme's hook: apply, but only where the installer (or an install
    from Settings) recorded the vesktop_theme component (components.json beside
    palette.json) and the theme is installed. With vesktop.theme.sync off the
    colours stay as they were."""
    try:
        comps = json.loads((Path(data) / "components.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        comps = {}
    if not (isinstance(comps, dict) and comps.get(COMPONENT) is True) or not installed():
        return []
    try:
        return apply(settings, palette, sync_colours=theme_flag(settings, "sync"), enforce=False, note=note)
    except (VesktopThemeError, OSError) as e:
        print(f"vitrum-theme: warning: Vesktop theme: {e}", file=sys.stderr)
        return []


def record_component(on: bool = True) -> None:
    """Mark the vesktop_theme part in components.json, as the installer would
    (an install from Settings turns the colour sync on too). Only into the
    installer's own file: one made here would lack its version and read as an
    old install on the next update."""
    path = data_home() / "vitrum" / "components.json"
    try:
        comps = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return
    if not isinstance(comps, dict) or comps.get(COMPONENT) is on:
        return
    comps[COMPONENT] = on
    _write(path, json.dumps(comps, indent=2, ensure_ascii=False) + "\n")


# ----------------------------------------------------- the theme's file -----

def install_theme(replace: bool = False, src: Path | None = None) -> Path:
    """Copy the shipped theme into Vesktop's themes folder. Without replace,
    the colours already there are kept (apply rewrites them anyway when sync
    is on); replace takes the shipped file whole."""
    if not app_found():
        raise VesktopThemeError("Vesktop is not installed: install it first (Arch: vesktop-bin from the AUR; "
                                f"anywhere: flatpak install flathub {FLATPAK_ID}), then run this again")
    src = src or theme_source()
    if src is None:
        raise VesktopThemeError("the vitrum Vesktop theme's file is missing (~/.local/share/vitrum/vesktop/"
                                f"{THEME_FILE}); run the vitrum installer again")
    text = Path(src).read_text(encoding="utf-8")
    if read_block(text) is None:
        raise VesktopThemeError(f"{src} has no vitrum colour block")
    dest = theme_file()
    if not replace and dest.is_file():
        old = read_block(dest.read_text(encoding="utf-8"))
        if old:
            text = with_block(text, old)
    _write(dest, text)
    return dest


def remove_theme() -> bool:
    """Take the theme out of enabledThemes and delete it. Vesktop and every
    other Vencord setting stay as they are. → whether a file was deleted."""
    set_enabled(False)
    try:
        state_file().unlink()
    except OSError:
        pass
    dest = theme_file()
    if dest.exists():
        dest.unlink()
        return True
    return False


if __name__ == "__main__" and sys.argv[1:] == ["watch"]:
    sys.exit(_watch_main())
