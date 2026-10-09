# Keybinds

This file is the actual keymap, not just a description of it. `lib/keybinds.py`
reads the tables below and turns them into
`~/.config/vitrum/niri/generated/binds.kdl`, which niri includes. Change a row,
run `./install.sh --only session`, done.

The right column has to be something the desktop knows how to do. If it isn't,
the installer tells you which row it didn't understand instead of quietly
skipping it. `Mod` is the Super key, and key names are written the way niri
writes them.

`Super+/` shows all of this on screen.

---

## Desktop

| Key | Action |
|-----|--------|
| `Mod+Space` | Launcher |
| `Mod+Tab` | Overview |
| `Alt+Tab` | Window switcher (next) |
| `Alt+Shift+Tab` | Window switcher (previous) |
| `Mod+Alt+C` | Control Centre |
| `Mod+N` | Notification Centre |
| `Mod+Ctrl+N` | Do not disturb |
| `Mod+Shift+Delete` | Clear notifications |
| `Mod+V` | Clipboard history |
| `Mod+Ctrl+Space` | Emoji picker |
| `Mod+Alt+D` | Show or hide the Dock |
| `Mod+Alt+W` | Edit desktop widgets |
| `Mod+Escape` | Power menu |
| `Mod+Slash` | All keybinds |
| `Mod+Period` | All keybinds |
| `Mod+Shift+F` | Game HUD (MangoHud) |
| `Mod+Shift+G` | Game mode |
| `Mod+Shift+P` | Colour picker |
| `Mod+Alt+L` | Lock screen |

---

## Appearance

| Key | Action |
|-----|--------|
| `Mod+Comma` | Settings |
| `Mod+Alt+A` | Toggle light and dark |
| `Mod+Shift+W` | Cycle the material |
| `Mod+Alt+B` | Wallpaper picker |
| `Mod+Alt+Shift+B` | Next wallpaper |

---

## Screenshots

| Key | Action |
|-----|--------|
| `Print` | Capture |
| `Mod+Shift+S` | Region screenshot |
| `Mod+Shift+X` | Region OCR |
| `Mod+Print` | Screenshot (niri native) |
| `Ctrl+Print` | Screenshot current screen |
| `Alt+Print` | Screenshot current window |

---

## Window Management

| Key | Action |
|-----|--------|
| `Mod+Q` | Close window |
| `Mod+D` | Maximize column (keeps gaps) |
| `Mod+F` | Toggle fullscreen |
| `Mod+A` | Toggle floating / tiling |
| `Mod+Shift+V` | Switch focus between floating and tiling layers |

### Focus

| Key | Action |
|-----|--------|
| `Mod+Left/H` | Focus column left |
| `Mod+Right/L` | Focus column right |
| `Mod+Up/K` | Focus window up |
| `Mod+Down/J` | Focus window down |
| `Mod+Home` | Focus first column |
| `Mod+End` | Focus last column |

### Move

| Key | Action |
|-----|--------|
| `Mod+Shift+Left/H` | Move column left |
| `Mod+Shift+Right/L` | Move column right |
| `Mod+Shift+Up/K` | Move window up |
| `Mod+Shift+Down/J` | Move window down |
| `Mod+Ctrl+Home` | Move column to first |
| `Mod+Ctrl+End` | Move column to last |

---

## Column Layout

niri arranges windows in an infinite horizontal strip. These control column
sizing and stacking.

| Key | Action |
|-----|--------|
| `Mod+R` | Cycle preset column widths (⅓ → ½ → ⅔) |
| `Mod+Shift+R` | Cycle preset window heights |
| `Mod+Ctrl+R` | Reset window height |
| `Mod+C` | Center focused column |
| `Mod+Minus` | Shrink column width 10% |
| `Mod+Equal` | Grow column width 10% |
| `Mod+Shift+Minus` | Shrink window height 10% |
| `Mod+Shift+Equal` | Grow window height 10% |
| `Mod+[` | Consume/expel window left (stack or unstack) |
| `Mod+]` | Consume/expel window right (stack or unstack) |

---

## Multi-Monitor

| Key | Action |
|-----|--------|
| `Mod+Ctrl+Left` | Focus monitor left |
| `Mod+Ctrl+Right` | Focus monitor right |
| `Mod+Ctrl+Up` | Focus monitor up |
| `Mod+Ctrl+Down` | Focus monitor down |
| `Mod+Ctrl+Shift+Left` | Move column to monitor left |
| `Mod+Ctrl+Shift+Right` | Move column to monitor right |
| `Mod+Ctrl+Shift+Up` | Move column to monitor up |
| `Mod+Ctrl+Shift+Down` | Move column to monitor down |

---

## Workspaces

| Key | Action |
|-----|--------|
| `Mod+1-9` | Focus workspace 1–9 |
| `Mod+Ctrl+1-9` | Move column to workspace 1–9 |
| `Mod+Page_Down` | Focus workspace down |
| `Mod+Page_Up` | Focus workspace up |
| `Mod+Ctrl+Page_Down` | Move column to workspace down |
| `Mod+Ctrl+Page_Up` | Move column to workspace up |
| `Mod+WheelDown` | Focus workspace down (mouse) |
| `Mod+WheelUp` | Focus workspace up (mouse) |

---

## Applications

| Key | Action |
|-----|--------|
| `Mod+T` / `Mod+Return` | Terminal |
| `Mod+E` | Finder |
| `Mod+W` | Browser |

Everything else opens from Spotlight, Launchpad or the Dock. Binding a key to
each of the three system applications would be noise; they are one `Mod+Space`
and three letters away.

---

## Session & System

| Key | Action |
|-----|--------|
| `Mod+Alt+L` | Lock screen |
| `Mod+Shift+Q` | Power menu |
| `Mod+Shift+E` | Quit niri |
| `Mod+Shift+O` | Power off monitors |
| `Mod+Escape` | Toggle keyboard shortcuts inhibit |

---

## Media & Hardware Keys

Volume, brightness and playback all go through the shell rather than straight to
the hardware, so that the on-screen display appears. They keep working while the
screen is locked.

| Key | Action |
|-----|--------|
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioMicMute` | Toggle mic mute |
| `XF86AudioPlay/Pause` | Play/pause |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |
| `XF86MonBrightnessUp` | Brightness up |
| `XF86MonBrightnessDown` | Brightness down |
| `Mod+Alt+Space` | Play/pause (keyboard) |
| `Mod+Alt+N` | Next track (keyboard) |
| `Mod+Alt+P` | Previous track (keyboard) |
| `Mod+Shift+M` | Toggle mute (keyboard) |

---

## Changing them

Edit the tables above and run:

```bash
./install.sh --only session
```

For your own binds that should survive updates, use
`~/.config/vitrum/niri/overrides.kdl`. It's included last and the installer
never touches it:

```kdl
// ~/.config/vitrum/niri/overrides.kdl
binds {
    Mod+P hotkey-overlay-title="Session menu" { spawn "vitrum-ipc" "session" "toggle"; }
}
```

Binds from that file show up in the `Super+/` sheet right away (under "Your
binds", or in place of the bind they replace). `hotkey-overlay-title` is what
the sheet calls it; without one it uses the action.

`Mod+Shift+/` is niri's own hotkey overlay.

niri picks up config changes by itself. If it ever doesn't:

```bash
niri msg action load-config-file
```
