# vitrum

A glass desktop for [niri](https://github.com/YaLTeR/niri).

vitrum is the whole thing you see after logging in: a bar made of floating
islands, a dock, Spotlight-style search, a control centre, notifications,
desktop widgets, a lock screen and a settings app — all on real refracting
glass. It runs on a patched niri (liquid glass, shaped blur) with a
[Quickshell](https://quickshell.org) shell on top, and its colours come from
your wallpaper.

It started as my own setup and grew into something that installs cleanly on
a fresh machine. It is still young: expect rough edges, and please open an
issue when you hit one.

Default wallpapers are from [Wallhaven]https://wallhaven.cc/

## What you get

- **Glass everywhere** — the bar, panels, dock and menus refract what is
  behind them. Pick solid, frosted or glass per surface if your GPU prefers.
- **Colours from the wallpaper** — kitty, GTK, Qt/KDE apps, tmux and Neovim
  follow the same palette, light or dark by sunrise and sunset.
- **Live wallpapers** — videos as wallpaper, paused while windows cover them.
- **A real settings app** — no config files needed for everyday changes.
- **The small things** — clipboard history, screenshots and recording,
  synced lyrics in the player, game mode, hot corners, a polkit prompt and a
  login screen that look like the rest.

## Install

Gentoo (OpenRC or systemd) and Arch (systemd) are supported. NVIDIA works.

```sh
git clone https://github.com/LanisOff/vitrum-shell
cd vitrum-shell
./install.sh
```

The installer asks a few questions once (login screen, boot splash, video
wallpapers, extras like game mode), builds niri, sets everything up and
remembers your answers. Useful flags:

```sh
./install.sh --dry-run   # show what it would do, change nothing
./install.sh --doctor    # check an existing install
./install.sh --yes       # no questions, reuse earlier answers
```

On Gentoo the first run takes a while — niri and a few Qt pieces are built
from source.

## Keep it up to date

```sh
vitrum update      # pull and reinstall only what changed
vitrum rollback    # undo the last update (your configs are snapshotted first)
vitrum doctor      # find out what is broken and how to fix it
```

The bar shows a small island when the repository is a few commits ahead of
you; click it to see what is new.

## Using it

Everything is reachable from the keyboard — `Mod+/` shows every shortcut,
and [KEYBINDS.md](KEYBINDS.md) has the full list. Settings live in the
Settings app (or `~/.config/vitrum/settings.json` if you prefer text).

## Removing it

```sh
./uninstall.sh
```

It removes what the installer added and restores every file it backed up.
Your settings stay unless you add `--purge`, and packages are left installed —
you may depend on them by now.

## License

[GPL-3.0](LICENSE)
