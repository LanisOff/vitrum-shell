"""The vitrum theme for Steam, through Millennium (steambrew.app).

Millennium 3.6 on Linux (read from its source, v3.6.2, and checked on an
installed copy):
  themes      $HOME/.steam/steam/millennium/themes/<name>/skin.json
              (platform::get_steam_path() is $HOME/.steam/steam, a link to
              ~/.local/share/Steam on most installs)
  config      $XDG_CONFIG_HOME/millennium/config.json, the active theme in
              themes.activeTheme ("default" is Steam's own look). Millennium
              reads it once when Steam starts and writes it back when its
              settings change and when Steam quits.
  libraries   /usr/lib/millennium (the AUR package and the release tarball),
              loaded through two links Steam picks up as libXtst.so.6 in
              <steam>/ubuntu12_32 and <steam>/ubuntu12_64.
  files       served to Steam's windows from the theme folder as
              https://millennium.host/v1/themes/<name>/<file> when a window
              loads, so new colours show in a window opened after the write
              (live.js also re-reads colors.css every few seconds).

The theme lives in assets/steam/vitrum. Most of Steam's own class names are
hashes that change with Steam updates; steam.vcss names them by the readable
keys Steam's webpack bundles map them from (@{Signature/Key}), and render_vcss
looks the hashes up in the bundles on disk, steamui/*.js. A rule whose names
cannot be found is left out, never written half-resolved.

apply() is what vitrum-theme runs (gated by sync()) and what
`vitrum-steam-theme apply` runs; install_millennium() is the one place that
installs Millennium, for the installer and the helper.
"""
from __future__ import annotations

import colorsys
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

THEME = "vitrum"
# Files the apply step writes into the installed theme (kept by `install`,
# replaced by `reinstall`).
GENERATED = ("colors.css", "steam.css", ".vitrum-state.json")

# The official release for distributions without a package (Arch uses the
# AUR's millennium, maintained by Millennium's authors). Pinned like
# lib/assets.tsv: a new release means a new URL and checksum here.
RELEASE = {
    "version": "3.6.2",
    "url": "https://github.com/SteamClientHomebrew/Millennium/releases/download/v3.6.2/"
           "millennium-v3.6.2-linux-x86_64.tar.gz",
    "sha256": "95bda40184dd6437da1668060ec5961c762f3c1e59923f53380e43d4e720f359",
}
LIB_FILES = ("libmillennium_x86.so", "libmillennium_hhx64.so", "libmillennium_bootstrap_x86.so",
             "libmillennium_bootstrap_hhx64.so", "libmillennium_luavm_x86", "libmillennium_pvs64")
EXECUTABLE = ("libmillennium_luavm_x86", "libmillennium_pvs64")


class SteamThemeError(Exception):
    """A failure with a short message for people (the helper prints it)."""


# ---------------------------------------------------------------- paths -----

def _home() -> Path:
    return Path(os.environ.get("HOME") or Path.home())


def millennium_lib() -> Path:
    return Path(os.environ.get("VITRUM_MILLENNIUM_LIB") or "/usr/lib/millennium")


def steam_dir() -> Path:
    """Where Millennium looks: $HOME/.steam/steam (resolved). A Steam with no
    ~/.steam link yet is in ~/.local/share/Steam."""
    home = _home()
    for p in (home / ".steam" / "steam", home / ".local" / "share" / "Steam"):
        if p.is_dir():
            return p.resolve()
    return home / ".steam" / "steam"


def themes_dir() -> Path:
    return steam_dir() / "millennium" / "themes"


def theme_dir() -> Path:
    return themes_dir() / THEME


def config_file() -> Path:
    cfg = Path(os.environ.get("XDG_CONFIG_HOME") or _home() / ".config")
    return cfg / "millennium" / "config.json"


def data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME") or _home() / ".local" / "share")


def cache_home() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME") or _home() / ".cache") / "vitrum"


def theme_source() -> Path | None:
    """The theme as shipped: beside the repo's tools, or where the installer
    put it (~/.local/share/vitrum/steam/vitrum)."""
    env = os.environ.get("VITRUM_STEAM_THEME_SRC")
    here = Path(__file__).resolve().parent
    for p in ([Path(env)] if env else []) + [here.parents[1] / "assets" / "steam" / THEME,
                                             data_home() / "vitrum" / "steam" / THEME]:
        if (p / "skin.json").is_file():
            return p
    return None


# --------------------------------------------------------------- status -----

def _hook_links(steam: Path) -> dict:
    lib = millennium_lib()
    return {steam / "ubuntu12_32" / "libXtst.so.6": lib / "libmillennium_bootstrap_x86.so",
            steam / "ubuntu12_64" / "libXtst.so.6": lib / "libmillennium_bootstrap_hhx64.so"}


def libraries_present() -> bool:
    lib = millennium_lib()
    return all((lib / f).is_file() for f in ("libmillennium_x86.so", "libmillennium_bootstrap_x86.so",
                                             "libmillennium_bootstrap_hhx64.so"))


def hooked(steam: Path | None = None) -> bool:
    """Steam loads Millennium: both libXtst.so.6 links point into it."""
    steam = steam or steam_dir()
    for link, target in _hook_links(steam).items():
        try:
            if not link.is_symlink() or Path(os.readlink(link)) != target:
                return False
        except OSError:
            return False
    return True


def millennium_found() -> bool:
    return libraries_present() and hooked()


def read_config(path: Path | None = None) -> dict | None:
    """Millennium's config, {} when there is none yet, None when unreadable."""
    path = path or config_file()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def active_theme(path: Path | None = None) -> str:
    cfg = read_config(path) or {}
    themes = cfg.get("themes") if isinstance(cfg.get("themes"), dict) else {}
    v = themes.get("activeTheme")
    return v if isinstance(v, str) and v else "default"


def steam_pid(run=subprocess.run) -> int | None:
    """The Steam client's process (ubuntu12_32/steam; not the steam.sh wrapper,
    which outlives a restart), oldest first."""
    try:
        r = run(["pgrep", "-u", str(os.getuid()), "-o", "-f", "ubuntu12_32/steam( |$)"],
                capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    try:
        return int((r.stdout or "").split()[0])
    except (IndexError, ValueError):
        return None


def steam_running(run=subprocess.run) -> bool:
    return steam_pid(run) is not None


def installed() -> bool:
    return (theme_dir() / "skin.json").is_file()


def status(run=subprocess.run) -> dict:
    return {"millennium": millennium_found(), "installed": installed(),
            "active": installed() and active_theme() == THEME,
            "steamRunning": steam_running(run), "themeDir": str(theme_dir())}


# --------------------------------------------------------------- colour -----

def _rgb(hex_: str) -> tuple:
    h = hex_.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _triplet(hex_: str) -> str:
    return ", ".join(str(c) for c in _rgb(hex_))


def _cap_lightness(hex_: str, cap: float) -> str:
    r, g, b = (c / 255 for c in _rgb(hex_))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb(h, min(l, cap), s)
    return "#" + "".join(f"{round(c * 255):02x}" for c in (r, g, b))


def theme_flag(settings: dict, key: str) -> bool:
    t = ((settings.get("steam") or {}).get("theme") or {}) if isinstance(settings, dict) else {}
    return t.get(key, True) is not False


# Steam's own stylesheets paint light text everywhere, so the theme always
# uses the palette's dark scheme: a light Steam would leave hundreds of
# light-on-light leftovers. The accent pair still follows vitrum.
ROLE_VARS = (("bg", "bg"), ("surface", "surface"), ("surface-high", "surfaceHigh"),
             ("surface-highest", "surfaceHighest"), ("text", "text"), ("text-dim", "textDim"),
             ("accent", "accent"), ("accent2", "accent2"), ("danger", "danger"))


def colors_css(roles: dict, note: str = "") -> str:
    """colors.css: the palette roles as --vt-* (hex and "r, g, b"), the radii
    and the font. Steam's windows are opaque: the window is the palette's bg,
    the glass layers on it have fixed alphas (base.css), and no wallpaper
    shows through."""
    # Colours kept from an older run (sync off) may predate surfaceHighest.
    roles = {"surfaceHighest": roles["surfaceHigh"], **roles}
    lines = []
    for var, role in ROLE_VARS:
        lines.append(f"  --vt-{var}: {roles[role]};")
    for var, role in ROLE_VARS:
        lines.append(f"  --vt-{var}-rgb: {_triplet(roles[role])};")
    # The glow under lit glass and an on switch's track: the accent, kept from
    # going pastel so "on" still reads on a dark pane.
    lines.append(f"  --vt-glow-rgb: {_triplet(_cap_lightness(roles['accent'], 0.66))};")
    lines += ["  --vt-radius-tile: 12px;", "  --vt-radius-button: 9px;", "  --vt-radius-panel: 20px;"]
    lines.append('  --vt-font: "Inter", "Inter Variable", "Noto Sans", sans-serif;')
    head = "/* Generated by vitrum-theme (steam.theme in vitrum's settings). Do not edit: it is rewritten. */\n"
    if note:
        head += f"/* palette: {note} */\n"
    return head + ":root {\n" + "\n".join(lines) + "\n}\n"


def dark_roles(palette: dict) -> dict:
    """The dark scheme's roles, with accent2 (computed if the palette predates it)."""
    from . import accent2 as _accent2
    roles = dict(palette.get("dark") or next(iter(palette.values())))
    if not roles.get("accent2"):
        roles["accent2"] = _accent2(roles["accent"], -100.0, True)
    return roles


# ---------------------------------------------------- Steam's class names -----

_CLASS_OBJ = re.compile(r'\{((?:(?:[A-Za-z_$][\w$]*|"[^"\\]+"):"[^"\\]*",?){2,})\}')
_CLASS_PAIR = re.compile(r'"?([A-Za-z_$][\w$-]*)"?:"([^"\\]*)"')
_CLASS_VALUE = re.compile(r"^-?[A-Za-z0-9_][\w-]{4,}$")


def parse_class_maps(text: str) -> list:
    """The CSS-module objects in a webpack bundle: {readableKey: "hashedClass"}."""
    out = []
    for m in _CLASS_OBJ.finditer(text):
        d = dict(_CLASS_PAIR.findall(m.group(1)))
        vals = [v for v in d.values() if _CLASS_VALUE.match(v) and not v.isdigit() and not v.endswith("px")]
        if len(vals) >= max(2, len(d) // 2):
            out.append(d)
    return out


def class_maps(steamui: Path, cache: Path | None = None) -> list:
    """Every class map in steamui/*.js, cached per bundle set."""
    files = sorted(Path(steamui).glob("*.js"))
    if not files:
        return []
    key = hashlib.sha1("|".join(f"{f.name}:{f.stat().st_size}:{int(f.stat().st_mtime)}" for f in files)
                       .encode()).hexdigest()
    store = (cache or cache_home()) / "steam-classes.json"
    try:
        saved = json.loads(store.read_text())
        if saved.get("key") == key:
            return saved["maps"]
    except (OSError, ValueError, KeyError, AttributeError):
        pass
    maps = []
    for f in files:
        try:
            maps += parse_class_maps(f.read_text(encoding="utf-8", errors="replace"))
        except OSError:
            continue
    try:
        store.parent.mkdir(parents=True, exist_ok=True)
        store.write_text(json.dumps({"key": key, "maps": maps}))
    except OSError:
        pass
    return maps


_TOKEN = re.compile(r"@\{([\w-]+)/([\w-]+)\}")
_MARK = re.compile(r"\x00([\w-]+)/([\w-]+)\x00")   # a token while the rules are split at braces


def _ident(name: str) -> str:
    """A class name as a CSS identifier (a leading digit is escaped)."""
    name = re.sub(r"([^\w-])", r"\\\1", name)
    if name[:1].isdigit():
        return "\\3%s %s" % (name[0], name[1:])
    if name[:2] == "--" or (name[:1] == "-" and name[1:2].isdigit()):
        return "\\" + name
    return name


def resolve(maps: list, sig: str, key: str) -> list:
    return sorted({d[key] for d in maps if sig in d and key in d and d[key]})


def _split_top(s: str, sep: str = ",") -> list:
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == sep and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    out.append(cur)
    return out


def _sub_selector(sel: str, maps: list, missing: set) -> str | None:
    bad = False

    def one(m):
        nonlocal bad
        names = resolve(maps, m.group(1), m.group(2))
        if not names:
            missing.add(f"@{{{m.group(1)}/{m.group(2)}}}")
            bad = True
            return ""
        if len(names) == 1:
            return "." + _ident(names[0])
        return ":is(" + ",".join("." + _ident(n) for n in names) + ")"
    out = _MARK.sub(one, sel)
    return None if bad else out


def render_vcss(text: str, maps: list, missing: set | None = None) -> str:
    """steam.vcss → CSS: @{Signature/Key} becomes the class Steam's bundles map
    Key to, in the module that also has Signature. A selector naming a class
    that is not there is dropped; a rule left with none is dropped whole."""
    missing = set() if missing is None else missing
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = _TOKEN.sub(lambda m: f"\x00{m.group(1)}/{m.group(2)}\x00", text)
    out, i, n = [], 0, len(text)
    while i < n:
        j = text.find("{", i)
        if j < 0:
            break
        prelude = text[i:j].strip()
        depth, k = 1, j + 1
        while k < n and depth:
            depth += {"{": 1, "}": -1}.get(text[k], 0)
            k += 1
        body = text[j + 1:k - 1]
        i = k
        if prelude.startswith("@"):
            inner = render_vcss(body, maps, missing) if "{" in body else body.strip()
            if inner.strip():
                out.append(f"{prelude} {{\n{inner}\n}}")
            continue
        sels = [s for s in (_sub_selector(s.strip(), maps, missing) for s in _split_top(prelude)) if s]
        if sels:
            decls = "\n".join("  " + d.strip() + ";" for d in body.split(";") if d.strip())
            out.append(",\n".join(sels) + " {\n" + decls + "\n}")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- write -----

def _write(path: Path, data, binary: bool = False) -> bool:
    path = Path(path)
    try:
        old = path.read_bytes() if binary else path.read_text(encoding="utf-8")
        if old == data:
            return False
    except OSError:
        pass
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".vitrum-tmp")
    if binary:
        tmp.write_bytes(data)
    else:
        tmp.write_text(data, encoding="utf-8")
    tmp.replace(path)
    return True


def set_active(enabled: bool, path: Path | None = None) -> bool:
    """themes.activeTheme: vitrum when enabled; when not, back to Steam's own
    look, but only if vitrum is the one active (another theme is left as is).
    → whether the file changed. Every other key stays as Millennium wrote it."""
    path = path or config_file()
    cfg = read_config(path)
    if cfg is None:
        raise SteamThemeError(f"{path} is not valid JSON; fix or delete it, Millennium recreates it")
    themes = cfg.get("themes") if isinstance(cfg.get("themes"), dict) else {}
    current = themes.get("activeTheme") or "default"
    want = THEME if enabled else ("default" if current == THEME else current)
    if current == want and "themes" in cfg:
        return False
    cfg["themes"] = {**themes, "activeTheme": want}
    return _write(path, json.dumps(cfg, indent=2) + "\n")


def _state(tdir: Path) -> dict:
    try:
        s = json.loads((tdir / ".vitrum-state.json").read_text())
        return s if isinstance(s, dict) else {}
    except (OSError, ValueError):
        return {}


def apply(settings: dict, palette: dict, *, sync_colours: bool = True, enforce: bool = True,
          note: str = "", run=subprocess.run, spawn=None) -> list:
    """Write the installed theme's colors.css and steam.css, and set
    Millennium's active theme from steam.theme.enabled. → what changed.

    sync_colours=False keeps the colours of the last run (steam.theme.sync
    off). enforce=False (vitrum-theme's
    runs) changes the active theme only when steam.theme.enabled changed since
    the last run, so a theme picked in Millennium's own settings stays."""
    tdir = theme_dir()
    if not (tdir / "skin.json").is_file():
        raise SteamThemeError(f"the vitrum theme is not installed in {tdir}; run: vitrum-steam-theme install")
    state = _state(tdir)
    changed = []
    roles = state.get("roles") if not sync_colours and isinstance(state.get("roles"), dict) else None
    if roles is None:
        roles = dark_roles(palette)
        note = note or "current"
    else:
        note = "kept (steam.theme.sync is off)"
    if _write(tdir / "colors.css", colors_css(roles, note)):
        changed.append(str(tdir / "colors.css"))
    # The blurred wallpaper an earlier version wrote: nothing reads it now.
    if (tdir / "wall.jpg").exists():
        (tdir / "wall.jpg").unlink()
        changed.append(str(tdir / "wall.jpg"))
    for old in ("wallUrl", "wallStamp"):
        state.pop(old, None)
    # Steam's hashed class names, from the bundles of the Steam on disk.
    vcss = tdir / "steam.vcss"
    if vcss.is_file():
        missing: set = set()
        css = render_vcss(vcss.read_text(encoding="utf-8"), class_maps(steam_dir() / "steamui"), missing)
        head = "/* Generated by vitrum-theme from steam.vcss for the Steam on disk. Do not edit. */\n"
        if missing:
            head += "/* not in this Steam: " + " ".join(sorted(missing)) + " */\n"
        if _write(tdir / "steam.css", head + css):
            changed.append(str(tdir / "steam.css"))
    enabled = theme_flag(settings, "enabled")
    did = False
    if enforce or state.get("enabled") != enabled or state.get("pending"):
        did = set_active(enabled)
        if did:
            changed.append(str(config_file()))
    running = steam_running(run)
    # Millennium keeps its config in memory and writes it back when Steam
    # quits, which would undo a change made while Steam runs: a watcher puts
    # it back until the next Steam has read it, and the next run checks again.
    state["pending"] = bool(running and (did or state.get("pending")))
    state.update({"roles": roles, "enabled": enabled})
    _write(tdir / ".vitrum-state.json", json.dumps(state, indent=1) + "\n")
    if state["pending"]:
        (spawn or spawn_watch)()
    return changed


def _wanted_enabled() -> bool | None:
    v = _state(theme_dir()).get("enabled")
    return v if isinstance(v, bool) else None


def watch(run=subprocess.run, sleep=None, timeout: float = 12 * 3600, step: float = 0.25) -> str:
    """Keep themes.activeTheme as vitrum's settings want it while Steam runs:
    whenever Millennium writes its own copy back (Steam quitting), write ours
    again. Ends when Steam is gone with the file right, when a new Steam client
    has started (it read the file), or after timeout. → why it ended."""
    import time
    sleep = sleep or time.sleep
    first = steam_pid(run)
    waited = 0.0
    while waited < timeout:
        want = _wanted_enabled()
        if want is None or not installed():
            return "gone"
        theme = active_theme()
        right = (theme == THEME) if want else (theme != THEME)
        if not right:
            try:
                set_active(want)
            except SteamThemeError:
                return "config"
            continue
        pid = steam_pid(run)
        if pid is None:
            return "quit"
        if first is not None and pid != first:
            return "restarted"
        first = first if first is not None else pid
        sleep(step)
        waited += step
    return "timeout"


def spawn_watch() -> None:
    """Start one watcher in the background (a second one is not started)."""
    import fcntl
    lock = cache_home() / "steam-watch.lock"
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
        subprocess.Popen([sys.executable, "-m", "vitrum_theme.steam", "watch"], env=env,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    except OSError:
        pass


def _watch_main() -> int:
    import fcntl
    lock = cache_home() / "steam-watch.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(lock, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 0
    watch()
    return 0


def sync(settings: dict, palette: dict, data: Path, note: str = "") -> list:
    """vitrum-theme's hook: apply, but only where the installer put the
    steam_theme component (components.json beside palette.json) and the theme
    is installed. With steam.theme.sync off the colours stay as they were."""
    try:
        comps = json.loads((Path(data) / "components.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        comps = {}
    if not (isinstance(comps, dict) and comps.get("steam_theme") is True) or not installed():
        return []
    try:
        return apply(settings, palette, sync_colours=theme_flag(settings, "sync"), enforce=False, note=note)
    except (SteamThemeError, OSError) as e:
        print(f"vitrum-theme: warning: Steam theme: {e}", file=sys.stderr)
        return []


def record_component(on: bool = True) -> None:
    """Mark the steam_theme part in components.json, as the installer would:
    an install from Settings must turn the colour sync on too (sync() only
    follows the palette where the part is recorded)."""
    path = data_home() / "vitrum" / "components.json"
    # Only into the installer's own file: one made here would lack its
    # version and read as an old install on the next update.
    try:
        comps = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return
    if not isinstance(comps, dict):
        return
    if comps.get("steam_theme") is on:
        return
    comps["steam_theme"] = on
    _write(path, json.dumps(comps, indent=2, ensure_ascii=False) + "\n")


# ----------------------------------------------------- the theme's files -----

def install_theme(replace: bool = False, src: Path | None = None) -> Path:
    """Copy the shipped theme into Millennium's themes folder. replace drops
    the folder first (generated files too); otherwise they are kept."""
    src = src or theme_source()
    if src is None:
        raise SteamThemeError("the vitrum Steam theme's files are missing (~/.local/share/vitrum/steam/vitrum); "
                              "run the vitrum installer again")
    dest = theme_dir()
    if replace and dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True, exist_ok=True)
    for f in sorted(Path(src).iterdir()):
        if f.is_file() and not f.name.startswith("."):
            if f.name in GENERATED and (dest / f.name).exists():
                continue
            shutil.copy2(f, dest / f.name)
    return dest


def remove_theme() -> bool:
    """Deactivate (if active) and delete the theme. Millennium stays."""
    if active_theme() == THEME:
        set_active(False)
    dest = theme_dir()
    if dest.exists():
        shutil.rmtree(dest)
        return True
    return False


# ------------------------------------------------------------ Millennium -----

def link_hooks(steam: Path | None = None, extra: bool = False) -> None:
    """The links Steam loads Millennium through (what the AUR package's
    post-install and the official script make), for this user."""
    steam = steam or steam_dir()
    links = dict(_hook_links(steam))
    if extra:   # the official script also links the 64-bit library itself
        links[steam / "ubuntu12_64" / "libmillennium_hhx64.so"] = millennium_lib() / "libmillennium_hhx64.so"
    for link, target in links.items():
        link.parent.mkdir(parents=True, exist_ok=True)
        if link.is_symlink() or link.exists():
            link.unlink()
        link.symlink_to(target)


def _distro_has_pacman(which=shutil.which) -> bool:
    return bool(which("pacman"))


def _aur_helper(which=shutil.which) -> str | None:
    for h in ("paru", "yay"):
        if which(h):
            return h
    return None


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _safe_members(tar: tarfile.TarFile) -> list:
    """Only ./usr/lib/millennium/<file> and its parent folders, nothing else."""
    files = []
    for m in tar.getmembers():
        name = m.name[2:] if m.name.startswith("./") else m.name
        name = name.rstrip("/")
        if name in ("", ".", "usr", "usr/lib", "usr/lib/millennium") and m.isdir():
            continue
        parts = name.split("/")
        if (len(parts) != 4 or parts[:3] != ["usr", "lib", "millennium"] or not m.isfile()
                or parts[3] not in LIB_FILES):
            raise SteamThemeError(f"unexpected file in the Millennium download: {m.name}")
        files.append(m)
    return files


def _root_cmd(interactive: bool, run, which) -> list:
    """sudo, or sudo -n when there is no terminal to ask for a password in."""
    if not which("sudo"):
        raise SteamThemeError("installing Millennium needs sudo")
    if interactive:
        return ["sudo"]
    if run(["sudo", "-n", "true"], capture_output=True).returncode == 0:
        return ["sudo", "-n"]
    raise SteamThemeError("installing Millennium needs your password: run `vitrum-steam-theme install` in a terminal")


def install_millennium(reinstall: bool = False, *, interactive: bool | None = None, yes: bool = False,
                       run=subprocess.run, which=shutil.which, release: dict = RELEASE,
                       workdir: Path | None = None, say=lambda *a: None) -> str:
    """Install Millennium if it is missing (or again, with reinstall); → how.

    Arch and its family (pacman): the AUR package `millennium`, built with
    paru or yay in a terminal (it asks for the password and to review the
    PKGBUILD; yes passes --noconfirm). Everything else: the official release
    tarball, pinned in RELEASE and checked against its SHA-256 before
    anything is unpacked, copied to /usr/lib/millennium with sudo. Then this
    user's links. Raises SteamThemeError with what to do when it cannot."""
    if interactive is None:
        interactive = sys.stdin.isatty()
    if not reinstall and libraries_present():
        if not hooked():
            link_hooks()
            return "linked"
        return "present"
    if platform.system() != "Linux" or platform.machine() not in ("x86_64", "AMD64"):
        raise SteamThemeError("Millennium runs on x86_64 Linux only")
    if _distro_has_pacman(which):
        helper = _aur_helper(which)
        if helper is None:
            raise SteamThemeError("Millennium comes from the AUR: install paru or yay, then run "
                                  "`vitrum-steam-theme install` in a terminal")
        if not interactive:
            raise SteamThemeError("Millennium is built from the AUR in a terminal: run "
                                  "`vitrum-steam-theme install` there (it asks for your password)")
        cmd = [helper, "-S"] + ([] if reinstall else ["--needed"]) + (["--noconfirm"] if yes else []) + ["millennium"]
        say("installing Millennium from the AUR: " + " ".join(cmd))
        if run(cmd).returncode != 0:
            raise SteamThemeError(f"{helper} could not install millennium")
        if not libraries_present():
            raise SteamThemeError(f"millennium is installed but {millennium_lib()} is missing its libraries")
        link_hooks()
        return "aur"
    if not which("curl"):
        raise SteamThemeError("installing Millennium needs curl")
    root = _root_cmd(interactive, run, which)
    with tempfile.TemporaryDirectory(dir=workdir) as tmp:
        tar_path = Path(tmp) / "millennium.tar.gz"
        say(f"downloading Millennium {release['version']}")
        r = run(["curl", "-fL", "--retry", "2", "-o", str(tar_path), release["url"]], capture_output=not interactive)
        if r.returncode != 0 or not tar_path.is_file():
            raise SteamThemeError("could not download Millennium (no network?)")
        got = _sha256(tar_path)
        if got != release["sha256"]:
            raise SteamThemeError(f"the Millennium download does not match its checksum (got {got}); nothing installed")
        out = Path(tmp) / "files"
        out.mkdir()
        with tarfile.open(tar_path) as tar:
            members = _safe_members(tar)
            for m in members:
                f = tar.extractfile(m)
                (out / Path(m.name).name).write_bytes(f.read())
        lib = millennium_lib()
        if run(root + ["install", "-d", "-m", "755", str(lib)]).returncode != 0:
            raise SteamThemeError(f"could not create {lib}")
        for name in sorted(p.name for p in out.iterdir()):
            mode = "755" if name in EXECUTABLE or name.endswith(".so") else "644"
            if run(root + ["install", "-m", mode, str(out / name), str(lib / name)]).returncode != 0:
                raise SteamThemeError(f"could not install {lib / name}")
    link_hooks(extra=True)
    return "release"


if __name__ == "__main__" and sys.argv[1:] == ["watch"]:
    sys.exit(_watch_main())
