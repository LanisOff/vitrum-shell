#!/usr/bin/env bash
# Stage: shell — the Quickshell desktop, its launcher and its IPC wrapper.
#
# The shell is started by vitrum-startup (session stage), which restarts it if
# it crashes; vitrum-shell is the one command that runs it, by hand or from there.

QS_ROOT="$XDG_CONFIG_HOME/quickshell"
QS_SHELL="$QS_ROOT/vitrum"

stage_shell() {
  stage "Shell"
  have qs || have quickshell || warn "quickshell is not on PATH yet — installing the files anyway"

  _shell_check_default_config
  _shell_check_qml

  step "installing $QS_SHELL"
  install_tree "$VITRUM_DIR/shell" "$QS_SHELL"
  _shell_settings
  _shell_theme_tool
  _shell_launchers
  _shell_remove_tahoe_leftovers
  _shell_steam_hud
  _shell_steam_theme
  _shell_vesktop_theme
  _shell_example_widget
  _shell_restart
  stage_done
}

# Steam, started with MANGOHUD=1 so its games carry the HUD (hidden until game
# mode or Mod+Shift+F), and with SDL left to pick its own video driver. A
# `steam` of vitrum's own in ~/.local/bin, ahead of the real one on PATH; one
# of yours there is left alone.
_shell_steam_hud() {
  [[ "${WANT_GAMES:-1}" == 1 ]] || return 0
  local real="" p f="$HOME/.local/bin/steam"
  for p in /usr/bin/steam /usr/games/bin/steam /usr/local/bin/steam; do [[ -x "$p" ]] && { real="$p"; break; }; done
  [[ -n "$real" ]] || return 0
  if [[ -e "$f" ]] && ! grep -q "vitrum" "$f" 2>/dev/null; then
    dim "$f is yours: MangoHud is not added to Steam (add MANGOHUD=1 to it)"; return 0
  fi
  step "Steam with MangoHud for its games"
  write_file "$f" <<EOF
#!/bin/sh
# Written by vitrum: Steam's games get MangoHud (hidden until game mode or Mod+Shift+F).
export MANGOHUD=1
# The session asks SDL for Wayland; Steam and the SDL its runtime and games
# bundle pick their own (a forced one crashed the older ones).
unset SDL_VIDEODRIVER
exec $real "\$@"
EOF
  [[ "$DRY_RUN" == "1" ]] || chmod +x "$f"
}

# The Steam theme (steam_theme, which needs games): vitrum-steam-theme install
# puts Millennium in where Steam has none (an existing one, from the AUR or
# upstream's script, is left as it is), copies the theme and applies it. Each
# run does the same, so an update brings new theme files. No Steam yet is no
# failure: the theme goes in with vitrum-steam-theme install once it is there.
_shell_steam_theme() {
  component_active steam_theme || return 0
  step "Steam theme (Millennium)"
  if [[ ! -d "$HOME/.steam/steam/ubuntu12_32" && ! -d "$XDG_DATA_HOME/Steam/ubuntu12_32" ]]; then
    if [[ -d "$HOME/.var/app/com.valvesoftware.Steam" ]]; then
      info "Steam is the Flatpak here, which Millennium does not support — Steam keeps its own look"
    else
      info "Steam is not installed, or has not been started once yet — the theme goes in later with: vitrum-steam-theme install"
    fi
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then dim "would run: vitrum-steam-theme install --yes"; return 0; fi
  local helper="$HOME/.local/bin/vitrum-steam-theme" rc=0
  if [[ ! -x "$helper" ]]; then warn '%s is missing — the Steam theme is not installed' "$helper"; return 0; fi
  # In the installer's terminal: an AUR build or sudo shows its own output.
  "$helper" install --yes || rc=$?
  case "$rc" in
    0) ok "Steam theme installed — Steam shows it from its next start" ;;
    2) info "the Steam theme needs your terminal (the AUR, or sudo's password) — run: vitrum-steam-theme install" ;;
    *) warn 'the Steam theme could not be installed (the reason is above) — Steam keeps its own look; vitrum-steam-theme install tries again' ;;
  esac
  return 0
}

# The Vesktop theme (vesktop_theme): vitrum-vesktop-theme install copies the
# theme into the Vesktop that is there, native or the Flatpak, switches it on
# in Vencord and applies it. Each run does the same, so an update brings new
# theme files. vitrum installs no Vesktop: none yet is no failure, the theme
# goes in later with vitrum-vesktop-theme install.
_shell_vesktop_theme() {
  component_active vesktop_theme || return 0
  step "Vesktop theme"
  if ! vesktop_present; then
    info "Vesktop is not installed — the theme goes in later with: vitrum-vesktop-theme install"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then dim "would run: vitrum-vesktop-theme install --yes"; return 0; fi
  local helper="$HOME/.local/bin/vitrum-vesktop-theme" rc=0
  if [[ ! -x "$helper" ]]; then warn '%s is missing — the Vesktop theme is not installed' "$helper"; return 0; fi
  "$helper" install --yes || rc=$?
  case "$rc" in
    0) ok "Vesktop theme installed — Vesktop shows it from its next start" ;;
    2) info "the Vesktop theme needs your terminal — run: vitrum-vesktop-theme install" ;;
    *) warn 'the Vesktop theme could not be installed (the reason is above) — Vesktop keeps its own look; vitrum-vesktop-theme install tries again' ;;
  esac
  return 0
}

# Your own QML widgets live in ~/.config/vitrum/widgets; an example goes in
# the first time, as something to copy. Once the folder exists it is yours.
_shell_example_widget() {
  local d="$XDG_CONFIG_HOME/vitrum/widgets"
  [[ -e "$d" ]] && return 0
  step "an example widget in $d"
  [[ "$DRY_RUN" == "1" ]] && return 0
  mkdir -p "$d" && cp -r "$VITRUM_DIR/config/widgets/example-uptime" "$d/"
}

# The shell does not reload itself when its files change (a reload under the
# lock screen kills it), so a running one is restarted here — unless the screen
# is locked: then it picks the new code up at the next restart or login.
_shell_restart() {
  local runtime="${XDG_RUNTIME_DIR:-/tmp}" pid
  pid="$(cat "$runtime/vitrum-shell.pid" 2>/dev/null)" || return 0
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null || return 0
  if ls "$runtime"/vitrum-locked-* >/dev/null 2>&1; then
    info "the screen is locked — the shell picks up the new code after the next login"
    return 0
  fi
  step "restarting the running shell"
  [[ "$DRY_RUN" == "1" ]] && return 0
  kill "$pid" 2>/dev/null || true
}

# One file can make every named Quickshell config unreachable: while
# ~/.config/quickshell/shell.qml exists, Quickshell treats it as the single
# default config and ignores every subdirectory — ours included. The launcher
# passes a full path, so it cannot cost you the desktop, but `qs -c vitrum`
# by hand would not work.
_shell_check_default_config() {
  local stray="$QS_ROOT/shell.qml"
  [[ -e "$stray" ]] || return 0
  warn '%s exists — Quickshell will ignore named configs while it is there; move it aside if you do not rely on it' "$stray"
}

# Refuse to install a shell that cannot load: everything visible lives in one
# Quickshell process, so one broken import is an empty screen after the next login.
_shell_check_qml() {
  [[ -f "$VITRUM_DIR/lib/check-qml.py" ]] || return 0
  have python3 || return 0
  step "checking the QML"
  local out
  # The apps are checked with the shell: they share its code and break with it.
  local roots=("$VITRUM_DIR/shell") a
  for a in settings disks about; do [[ -d "$VITRUM_DIR/apps/$a" ]] && roots+=("$VITRUM_DIR/apps/$a"); done
  if out="$(python3 "$VITRUM_DIR/lib/check-qml.py" "${roots[@]}" 2>&1)"; then
    dim "    ${out##*$'\n'}"
    return 0
  fi
  printf '%s\n' "$out" | while IFS= read -r line; do err '%s' "$line"; done
  die "the QML will not load — fix the above, or run with --skip shell to install the rest"
}

# Your settings file: created empty once (defaults live in the shell), never overwritten.
_shell_settings() {
  local f="$XDG_CONFIG_HOME/vitrum/settings.json"
  [[ -e "$f" ]] && return 0
  step "settings: $f"
  [[ "$DRY_RUN" == "1" ]] && return 0
  mkdir -p "$(dirname "$f")" && printf '{}' > "$f"
}

# vitrum-theme: the package goes next to the other vitrum state, the command to
# ~/.local/bin; run once so the palette and niri's generated config exist.
_shell_theme_tool() {
  step "vitrum-theme"
  install_tree "$VITRUM_DIR/tools/vitrum_theme" "$XDG_DATA_HOME/vitrum/lib/vitrum_theme"
  install_file "$VITRUM_DIR/tools/vitrum-theme" "$HOME/.local/bin/vitrum-theme" 0755
  # vitrum update / snapshot / rollback / doctor
  install_file "$VITRUM_DIR/tools/vitrum" "$HOME/.local/bin/vitrum" 0755
  # window pictures for the screen-share picker
  install_file "$VITRUM_DIR/tools/vitrum-thumbs" "$HOME/.local/bin/vitrum-thumbs" 0755
  # the launcher's Games tab
  install_file "$VITRUM_DIR/tools/vitrum-steam" "$HOME/.local/bin/vitrum-steam" 0755
  # the Steam theme (Millennium), for the installer and Settings, with the
  # theme's files it installs from
  install_file "$VITRUM_DIR/tools/vitrum-steam-theme" "$HOME/.local/bin/vitrum-steam-theme" 0755
  install_tree "$VITRUM_DIR/assets/steam/vitrum" "$XDG_DATA_HOME/vitrum/steam/vitrum"
  # the Vesktop theme, the same way: its helper and the theme it installs from
  install_file "$VITRUM_DIR/tools/vitrum-vesktop-theme" "$HOME/.local/bin/vitrum-vesktop-theme" 0755
  install_tree "$VITRUM_DIR/assets/vesktop" "$XDG_DATA_HOME/vitrum/vesktop"
  # the phone, through KDE Connect
  install_file "$VITRUM_DIR/tools/vitrum-phone" "$HOME/.local/bin/vitrum-phone" 0755
  # the clipboard history (text kept for good, images up to clipboard.images)
  install_file "$VITRUM_DIR/tools/vitrum-clip" "$HOME/.local/bin/vitrum-clip" 0755
  # default apps and the session's autostart (Settings → Applications, vitrum-startup)
  install_file "$VITRUM_DIR/tools/vitrum-apps" "$HOME/.local/bin/vitrum-apps" 0755
  # Bluetooth pairing: BlueZ's questions, answered through the shell's dialogs
  install_file "$VITRUM_DIR/tools/vitrum-bt-agent" "$HOME/.local/bin/vitrum-bt-agent" 0755
  # Settings → Network: hidden and Enterprise Wi-Fi, addressing, VPN profiles (NetworkManager)
  install_file "$VITRUM_DIR/tools/vitrum-net" "$HOME/.local/bin/vitrum-net" 0755
  if [[ "$DRY_RUN" != "1" ]]; then
    VITRUM_DATA="$QS_SHELL/data" "$HOME/.local/bin/vitrum-theme" --quiet || warn "vitrum-theme failed — the shell falls back to its built-in palette"
  fi
}

_shell_launchers() {
  step "launcher and IPC wrapper"
  local qsbin="qs"; have qs || qsbin="quickshell"

  write_file "$HOME/.local/bin/vitrum-shell" <<EOF
#!/usr/bin/env bash
# vitrum-shell — runs the Quickshell desktop. Written by the vitrum installer.
#   vitrum-shell            run it (vitrum-startup does this, and restarts it on a crash)
#   vitrum-shell --restart  stop the running one; vitrum-startup brings it back with new code
#   vitrum-shell --stop     stop it for good this session
set -u
runtime="\${XDG_RUNTIME_DIR:-/tmp}"
pidf="\$runtime/vitrum-shell.pid"
stop() { [ -f "\$pidf" ] && kill "\$(cat "\$pidf")" 2>/dev/null; }
case "\${1:-}" in
  --restart) stop; exit 0 ;;
  --stop)    : > "\$runtime/vitrum-shell.stop"; stop; exit 0 ;;
esac
log="\${XDG_DATA_HOME:-\$HOME/.local/share}/vitrum/shell.log"
mkdir -p "\$(dirname "\$log")"
# Keep the log to the last run or two.
[ -f "\$log" ] && [ "\$(wc -c <"\$log")" -gt 1000000 ] && : > "\$log"
echo "── vitrum-shell \$(date '+%F %T') ──" >> "\$log"
# exec keeps this PID: the file names the shell process itself.
echo \$\$ > "\$pidf"
# By name first; by full path if a stray ~/.config/quickshell/shell.qml hides named configs.
if [ -e "\${XDG_CONFIG_HOME:-\$HOME/.config}/quickshell/shell.qml" ]; then
  exec $qsbin -p "\${XDG_CONFIG_HOME:-\$HOME/.config}/quickshell/vitrum/shell.qml" >> "\$log" 2>&1
fi
exec $qsbin -c vitrum >> "\$log" 2>&1
EOF

  write_file "$HOME/.local/bin/vitrum-ipc" <<EOF
#!/usr/bin/env bash
# vitrum-ipc — keybinds call the shell through this: vitrum-ipc launcher toggle
$qsbin -c vitrum ipc call "\$@" 2>/dev/null && exit 0
exec $qsbin -p "\${XDG_CONFIG_HOME:-\$HOME/.config}/quickshell/vitrum/shell.qml" ipc call "\$@"
EOF
  if [[ "$DRY_RUN" != "1" ]]; then chmod +x "$HOME/.local/bin/vitrum-shell" "$HOME/.local/bin/vitrum-ipc"; fi
}

# The niri-tahoe launchers and its systemd unit would start a second shell.
_shell_remove_tahoe_leftovers() {
  local f
  for f in "$HOME/.local/bin/niri-tahoe-shell" "$HOME/.local/bin/niri-tahoe-startup" \
           "$HOME/.local/bin/niri-tahoe-ipc" "$XDG_DATA_HOME/systemd/user/niri-tahoe-shell.service"; do
    [[ -e "$f" ]] || continue
    backup_path "$f"
    run rm -f "$f"
  done
}
