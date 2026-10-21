<p align="center">
  <img src="assets/vitrum-mark.svg" width="96" alt="vitrum">
</p>

<h1 align="center">vitrum</h1>

<p align="center">
  A glass desktop for <a href="https://github.com/YaLTeR/niri">niri</a>.
</p>

<p align="center">
  <a href="https://github.com/LanisOff/vitrum-shell/stargazers"><img src="https://img.shields.io/github/stars/LanisOff/vitrum-shell?style=flat-square&color=8b7cf6" alt="Stars"></a>
  <a href="https://github.com/LanisOff/vitrum-shell/commits/main"><img src="https://img.shields.io/github/last-commit/LanisOff/vitrum-shell?style=flat-square&color=8b7cf6" alt="Last commit"></a>
  <a href="https://github.com/LanisOff/vitrum-shell/commits/main"><img src="https://img.shields.io/github/commit-activity/m/LanisOff/vitrum-shell?style=flat-square&color=8b7cf6" alt="Commit activity"></a>
  <a href="https://github.com/LanisOff/vitrum-shell/issues"><img src="https://img.shields.io/github/issues/LanisOff/vitrum-shell?style=flat-square&color=8b7cf6" alt="Issues"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/LanisOff/vitrum-shell?style=flat-square&color=8b7cf6" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/YaLTeR/niri"><img src="https://img.shields.io/badge/compositor-niri%2026.04-4f6fd6?style=flat-square" alt="niri 26.04"></a>
  <a href="https://quickshell.org"><img src="https://img.shields.io/badge/shell-Quickshell-4f6fd6?style=flat-square" alt="Quickshell"></a>
  <img src="https://img.shields.io/badge/Arch-systemd-1793d1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch">
  <img src="https://img.shields.io/badge/Gentoo-OpenRC%20%7C%20systemd-54487a?style=flat-square&logo=gentoo&logoColor=white" alt="Gentoo">
  <img src="https://img.shields.io/badge/Fedora-systemd-51a2da?style=flat-square&logo=fedora&logoColor=white" alt="Fedora">
  <img src="https://img.shields.io/badge/Void-runit-478061?style=flat-square&logo=voidlinux&logoColor=white" alt="Void">
  <img src="https://img.shields.io/badge/NVIDIA-works-76b900?style=flat-square&logo=nvidia&logoColor=white" alt="NVIDIA works">
</p>

<p align="center">
  <img src="assets/screenshots/desktop.jpg" alt="The vitrum desktop: glass clock, weather, system monitor and player widgets">
</p>

vitrum is the whole thing you see after logging in: a bar made of floating
islands, a dock, Spotlight-style search, a control centre, notifications,
desktop widgets, a lock screen and a settings app, all on real refracting
glass. It runs on a patched niri (liquid glass, shaped blur) with a
[Quickshell](https://quickshell.org) shell on top, and its colours come from
your wallpaper.

It started as my own setup and grew into something that installs cleanly on
a fresh machine. It is still young: expect rough edges, and please
[open an issue](https://github.com/LanisOff/vitrum-shell/issues) when you hit one.

<p align="center">
  <a href="#screenshots">Screenshots</a> ·
  <a href="#what-you-get">What you get</a> ·
  <a href="#install">Install</a> ·
  <a href="#keep-it-up-to-date">Updating</a> ·
  <a href="#using-it">Using it</a> ·
  <a href="#removing-it">Removing it</a>
</p>

## Screenshots

Every picture below is the shell as it is in the repository, taken in a
nested niri session.

### One desktop, many faces

The palette follows the wallpaper, light or dark, and the widgets are yours
to arrange: right-click a widget, or press `Mod+Alt+W`, to open the editor.

<table>
  <tr>
    <td width="50%"><img src="assets/screenshots/desktop-moon.jpg" alt="Dark scheme on a moon wallpaper: glass clock, world clocks, sun, analog clock and a quote"></td>
    <td width="50%"><img src="assets/screenshots/desktop-train.jpg" alt="Light scheme on a train wallpaper: to-do list, notes, shortcuts, calendar, timer and countdown"></td>
  </tr>
  <tr>
    <td align="center"><sub>Dark, minimal: glass clock, world clocks, sun, analog clock, quote</sub></td>
    <td align="center"><sub>Light, for the day: to-do, notes, shortcuts, calendar, timer, countdown</sub></td>
  </tr>
</table>

### Control centre and notifications

<table>
  <tr>
    <td width="50%"><img src="assets/screenshots/control.jpg" alt="The control centre: network, Bluetooth, VPN, do not disturb, appearance, power mode, game mode, volume and the player"></td>
    <td width="50%"><img src="assets/screenshots/notifications.jpg" alt="The notification centre, grouped by app"></td>
  </tr>
  <tr>
    <td align="center"><sub>Quick toggles, volume and the player, one click from the bar</sub></td>
    <td align="center"><sub>Notifications, grouped by app</sub></td>
  </tr>
</table>

### Lock screen

<p align="center">
  <img src="assets/screenshots/lock.jpg" alt="The lock screen: a glass clock over the blurred wallpaper, the password field and the player with synced lyrics">
  <br><sub>The wallpaper, blurred; the clock in glass; the player and its lyrics stay at hand</sub>
</p>

### Windows and settings

<p align="center">
  <img src="assets/screenshots/windows.jpg" alt="Two kitty windows, fastfetch and btop, themed from the wallpaper">
  <br><sub>kitty and the terminal tools take the same palette as the shell</sub>
</p>

<p align="center">
  <img src="assets/screenshots/settings.jpg" width="80%" alt="The Settings app, Appearance page">
  <br><sub>A settings app for everyday changes, no config files needed</sub>
</p>

## What you get

| | |
|---|---|
| **Glass everywhere** | The bar, panels, dock and menus refract what is behind them. Pick solid, frosted or glass per surface if your GPU prefers. |
| **Colours from the wallpaper** | kitty, GTK, Qt/KDE apps, tmux and Neovim follow the same palette, light or dark by sunrise and sunset. |
| **Desktop widgets** | 26 of them, from clocks, weather and a calendar to system graphs, a player, notes and a to-do list, plus your own in QML or as a script. Placed and sized in an editor on the desktop itself. |
| **Live wallpapers** | Videos as wallpaper, paused while windows cover them. |
| **Game mode** | Turns on by itself when a game goes fullscreen: the shell gets out of the way, notifications wait, gamemode and MangoHud do their part. |
| **A real settings app** | No config files needed for everyday changes. |
| **The small things** | Clipboard history, screenshots and recording, synced lyrics in the player, hot corners, a polkit prompt and a login screen that look like the rest. |

## Install

Supported: Arch (systemd), CachyOS and other Arch-based systems included;
Gentoo (OpenRC or systemd); Fedora 43 or newer (tested on 44), with
systemd; and Void, the glibc flavour, with runit and elogind. NVIDIA works.
Notes on [Fedora and Void](#fedora-and-void) are below.

The one-liner needs bash, curl and sudo. A minimal Void can lack all
three: there, first run `xbps-install -Sy bash curl sudo` as root, then
add your user to the `wheel` group (`usermod -aG wheel <you>`, with the
`%wheel` line enabled in `visudo`) or set up sudo another way.

```sh
curl -fsSL https://raw.githubusercontent.com/LanisOff/vitrum-shell/main/get.sh | bash
```

The line installs git if it is missing, clones vitrum next to your data
(`~/.local/share/vitrum-src`) and starts the installer. Run again, it pulls
that clone first, unless it has local changes: then it says so and installs
from it as it is. Or by hand:

```sh
git clone https://github.com/LanisOff/vitrum-shell
cd vitrum-shell
./install.sh
```

### What the installer asks

1. **The language** of the installer: English or Russian. Your system's is
   picked already. This is the language of the screens; the stages' own
   messages, which also go to the log, follow the system locale instead:
   Russian on a `ru_*` locale, English otherwise.
2. **What to install**, on one screen. Tick or untick with space, pick an
   option with the arrows, `a` toggles a whole group. The line at the bottom
   explains the part under the cursor.
   - **Desktop**: the login screen, the boot splash, video wallpapers, your
     phone (KDE Connect).
   - **Tools**: tmux with its plugins, game mode and its HUD, the microphone
     filter, VPN, sensors and mixer, command-line tools (eza, bat, fzf,
     zoxide, delta), the Dolphin file manager, text recognition on
     screenshots.
   - **Extras**: the author's own setup, off unless you tick it: Neovim
     with the author's config, the author's tmux keys (`Ctrl+a`, `|` and
     `-` splits) and tmux starting with every terminal. Without them tmux
     keeps its own keys.
3. **A confirmation**: what will be installed and what will not, about how
   long it takes, and the few questions that matter on your machine
   (making fish your login shell, replacing another login screen, going on
   with little disk space).

Then it works on its own: one line per stage with the time it took, the
running stage showing its last lines of output, and a bar with the time
left. If a stage fails, you choose: retry it, skip it, read its log or
quit and carry on later with `./install.sh --from <stage>`. At the end you
get what was installed, anything that went wrong and what to do about it,
and a few first shortcuts. The full log is kept in
`~/.local/share/vitrum/`.

A stage that was skipped or failed can be run later: on its own with
`./install.sh --only <stage>`, or with every stage after it with
`./install.sh --from <stage>` (the final screen says which). Until a run
goes through completely, `vitrum update` counts the update as unfinished
and runs the installer again.

On the first login a short tour shows the bar, the dock, search, the
control centre, widgets and Settings.

Useful flags, which also pass through the one-liner with `bash -s --`:

```sh
./install.sh --dry-run   # show what it would do, change nothing
./install.sh --update    # update: ask only about parts new or still unticked
./install.sh --choose    # the choice screen again, with your choices
./install.sh --fresh     # the first-run screens again; everything is redone
./install.sh --doctor    # check an existing install
./install.sh --yes       # no screens: earlier answers, defaults for new parts
./install.sh --help      # every flag, one per part (--with-games, --no-ocr...)
```

```sh
curl -fsSL https://raw.githubusercontent.com/LanisOff/vitrum-shell/main/get.sh | bash -s -- --dry-run
```

Without a terminal (a pipe, `ssh -T`) the installer prints line by line
and takes the defaults, as `--yes` does. On Gentoo the first run takes a
while: niri and a few Qt pieces are built from source.

### Fedora and Void

**Fedora** does not package everything vitrum needs, so the installer
enables third-party repositories, says which on screen, and enables only
those the parts you chose need:

- **RPM Fusion free**, always: Fedora's own `ffmpeg-free` cannot decode
  H.264 or HEVC, so it is replaced with RPM Fusion's `ffmpeg`. **RPM Fusion
  nonfree** is enabled only on a machine with an NVIDIA GPU.
- **COPR repositories**: `errornointernet/quickshell` (the shell),
  `avengemedia/danklinux` (matugen), `mineiro/hyprland` (satty, awww),
  `brycensranch/gpu-screen-recorder-git` (screen recording) and
  `atim/starship` (the prompt) for every install; `sdegler/hyprland`
  (mpvpaper) for video wallpapers, `dejan/lazygit` for the author's Neovim
  and `uriesk/noise-suppression-for-voice` for the microphone filter.

On a Workstation install `tuned-ppd` is replaced with
`power-profiles-daemon`, which the shell's power modes use. Fedora 43 or
newer is needed (tested on 44): older releases have no builds left in those
COPRs.

**Void** needs the glibc flavour (musl is refused) and elogind, which the
installer installs and enables: it gives the session its seat, and the
password-free root helper relies on it. Packages come from the main
repository only, plus nonfree with an NVIDIA GPU. Services are runit
links in `/var/service`. A link starts its service at once, so the two
that must not change under a running system wait for the next boot: the
login screen (SDDM), and NetworkManager taking over from dhcpcd and the
other network services it would fight. `/etc/rc.local` makes those
switches once and then removes its lines. If SDDM replaced another login
screen, `./uninstall.sh` puts that one back the same way, and before the
reboot it simply cancels the switch.

## Keep it up to date

```sh
vitrum update           # pull and reinstall only what changed
vitrum update --choose  # the same, with the choice screen to change your parts
vitrum rollback         # undo the last update (your configs are snapshotted first)
vitrum doctor           # find out what is broken and how to fix it
```

An update keeps your choices and asks nothing, unless the new version
brings a part to choose or a part is still unticked: then the choice screen
comes up with just those. The parts you left unticked are offered again on
every update; Esc on that screen keeps your choices and goes on. Unticking
a part later removes nothing: its packages and configs stay, and vitrum
simply stops managing it. `vitrum update --choose` shows the whole choice
screen, also when there is nothing new to pull. `vitrum update` also puts
back packages and fonts that went missing.

A run with `--only`, `--from` or `--skip` (`./install.sh --only shell`
after editing the QML is the author's daily one) asks nothing: it is about
those stages, not about the choices.

The bar shows a small island when the repository is a few commits ahead of
you; click it to see what is new.

## Using it

Everything is reachable from the keyboard: `Mod+/` shows every shortcut,
and [KEYBINDS.md](KEYBINDS.md) has the full list. Settings live in the
Settings app (or `~/.config/vitrum/settings.json` if you prefer text).

## Removing it

```sh
./uninstall.sh
```

It removes what the installer added and restores every file it backed up.
Packages are left installed: you may depend on them by now. Your settings
(`~/.config/vitrum`) and the installer's state directory
(`~/.local/share/vitrum`: your choices, config snapshots and logs) stay,
and so does the one-liner's clone in `~/.local/share/vitrum-src`, which is
yours to delete. `--purge` removes the settings and the state directory,
not the clone. Installing again afterwards is a first install, with the
language screen and the tour.

On Void, uninstalling before the reboot cancels a queued switch to the
login screen, but NetworkManager stays in charge of the network: the
installer's switch to it is not undone, on Void or anywhere else.

## Star history

<a href="https://star-history.com/#LanisOff/vitrum-shell&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=LanisOff/vitrum-shell&type=Date&theme=dark">
    <img src="https://api.star-history.com/svg?repos=LanisOff/vitrum-shell&type=Date" alt="Star history" width="100%">
  </picture>
</a>

## Credits

- [niri](https://github.com/YaLTeR/niri) by YaLTeR, the compositor underneath.
- [Niri-glass](https://github.com/YeFaDa/Niri-glass) by YeFaDa, the liquid glass it is patched with.
- [Quickshell](https://quickshell.org), which the shell is written in.
- Default wallpapers are from [Wallhaven](https://wallhaven.cc/).

## License

[GPL-3.0](LICENSE)
