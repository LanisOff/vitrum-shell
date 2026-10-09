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
  _shell_restart
  stage_done
}

# Steam, started with MANGOHUD=1 so its games carry the HUD (hidden until game
# mode or Mod+Shift+F). A `steam` of vitrum's own in ~/.local/bin, ahead of the
# real one on PATH; one of yours there is left alone.
_shell_steam_hud() {
  [[ "${WANT_EXTRAS:-1}" == 1 ]] || return 0
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
exec $real "\$@"
EOF
  [[ "$DRY_RUN" == "1" ]] || chmod +x "$f"
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
  warn "$stray exists — Quickshell will ignore named configs while it is there; move it aside if you do not rely on it"
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
  printf '%s\n' "$out" | while IFS= read -r line; do err "$line"; done
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
  # the phone, through KDE Connect
  install_file "$VITRUM_DIR/tools/vitrum-phone" "$HOME/.local/bin/vitrum-phone" 0755
  # calendar events (local, CalDAV, Google)
  install_file "$VITRUM_DIR/tools/vitrum-calendar" "$HOME/.local/bin/vitrum-calendar" 0755
  # the clipboard history (text kept for good, images up to clipboard.images)
  install_file "$VITRUM_DIR/tools/vitrum-clip" "$HOME/.local/bin/vitrum-clip" 0755
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
