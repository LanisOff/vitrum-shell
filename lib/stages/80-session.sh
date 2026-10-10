#!/usr/bin/env bash
# Stage: session — the login entry, the niri config, and what starts with it.
#
# Our niri config lives in ~/.config/vitrum/niri/, not ~/.config/niri/: that
# path belongs to any stock niri on the machine, which would refuse a config
# full of liquid-glass options only our binary understands. The session
# wrapper points NIRI_CONFIG at ours.
#
#   ~/.config/vitrum/niri/config.kdl          generated every run from config/niri/config.kdl.in
#   ~/.config/vitrum/niri/generated/*.kdl     generated: session spawns, binds, and (vitrum-theme) look/effects/animations
#   ~/.config/vitrum/niri/overrides.kdl       yours, never touched, included last
#
# User processes start from niri (spawn-at-startup → vitrum-startup), so their
# lifetime is the compositor's on OpenRC and systemd alike.

VITRUM_SYSROOT="${VITRUM_SYSROOT:-}"
NIRI_DIR="$VITRUM_PREFIX/niri"

stage_session() {
  stage "Session"
  migrate_tahoe_settings
  _session_wrapper
  session_unit_install
  audio_enable_user
  _session_startup_script
  _session_spawns
  _session_portals
  _session_root_helper
  _session_keybinds
  _session_config
  _session_overrides
  _session_validate
  stage_done
}

# --------------------------------------------------------------- wrapper ----

_session_wrapper() {
  step "login entry and session wrapper ($INIT_BACKEND)"
  local exec_line; exec_line="$(session_exec_line)"
  local greeter_vt; greeter_vt="$(_session_greeter_vt)"
  sudo_write "$VITRUM_SYSROOT/usr/local/bin/vitrum-session" 0755 <<EOF
#!/bin/sh
# vitrum session wrapper — environment, then the compositor. Written by the installer.
export XDG_CURRENT_DESKTOP=niri XDG_SESSION_DESKTOP=niri XDG_SESSION_TYPE=wayland
export VITRUM=1
export NIRI_CONFIG="\$HOME/.config/vitrum/niri/config.kdl"
export QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=qt6ct QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export GDK_BACKEND=wayland,x11 MOZ_ENABLE_WAYLAND=1 ELECTRON_OZONE_PLATFORM_HINT=auto SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1
# A display manager does not necessarily start us from a login shell.
case ":\$PATH:" in *":\$HOME/.local/bin:"*) ;; *) PATH="\$HOME/.local/bin:\$PATH" ;; esac
export PATH
if grep -qs '^nvidia ' /proc/modules; then
  export GBM_BACKEND=nvidia-drm __GLX_VENDOR_LIBRARY_NAME=nvidia LIBVA_DRIVER_NAME=nvidia NVD_BACKEND=direct
fi
# Machine-specific exports.
[ -f "\$HOME/.config/vitrum/session.env" ] && . "\$HOME/.config/vitrum/session.env"
$exec_line
rc=\$?
# Back to the login screen's VT. The display manager switches there itself once
# this session has ended, but that switch can get lost while the session is
# still closing: the greeter then starts on an inactive VT and the screen stays
# black. While this session is still active, logind lets it switch. Not when
# started from a console (stdin is that tty): you stay on your console.
if [ ! -t 0 ]; then
  busctl --system call org.freedesktop.login1 /org/freedesktop/login1/seat/seat0 org.freedesktop.login1.Seat SwitchTo u $greeter_vt >/dev/null 2>&1 \\
    || dbus-send --system --dest=org.freedesktop.login1 /org/freedesktop/login1/seat/seat0 org.freedesktop.login1.Seat.SwitchTo uint32:$greeter_vt >/dev/null 2>&1
fi
exit \$rc
EOF
  # niri, by its own name. In /usr/local, beside a distro niri's own entry
  # rather than in its place.
  sudo_write "$VITRUM_SYSROOT/usr/local/share/wayland-sessions/niri.desktop" <<'EOF'
[Desktop Entry]
Name=niri
Comment=niri with liquid glass and the vitrum shell
Exec=/usr/local/bin/vitrum-session
Type=Application
DesktopNames=niri
Keywords=tiling;wayland;niri;vitrum;
EOF
  # What earlier installs called it.
  local old
  for old in "$VITRUM_SYSROOT/usr/share/wayland-sessions/vitrum.desktop" "$VITRUM_SYSROOT/etc/systemd/user/vitrum-niri.service"; do
    [[ -e "$old" ]] && run sudo rm -f "$old"
  done
  if [[ ! -f "$VITRUM_PREFIX/session.env" ]]; then
    write_file "$VITRUM_PREFIX/session.env" <<'EOF'
# Sourced by /usr/local/bin/vitrum-session before the compositor starts.
# Anything exported here reaches every application in the session.
# export XCURSOR_SIZE=24
# export QT_SCALE_FACTOR=1
EOF
  fi
}

# --------------------------------------------------------------- startup ----

# Spawned once by niri. Order matters, so it is a script and not a list of
# spawn-at-startup lines (niri runs those concurrently): the environment has to
# reach D-Bus — and systemd, where there is one — before anything that reads
# it, or Qt loses its platform theme and every icon comes back empty.
_session_startup_script() {
  step "startup script"
  write_file "$HOME/.local/bin/vitrum-startup" <<'EOF'
#!/usr/bin/env bash
# vitrum-startup — spawned once by niri. Written by the vitrum installer.
set -u
vars="WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP NIRI_SOCKET VITRUM QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_WAYLAND_DISABLE_WINDOWDECORATION XCURSOR_THEME XCURSOR_SIZE"

# 1. The environment, for D-Bus activated services and portals.
if [ -d /run/systemd/system ]; then
  # shellcheck disable=SC2086
  systemctl --user import-environment $vars 2>/dev/null || true  # runtime-script: only when systemd runs
  # shellcheck disable=SC2086
  dbus-update-activation-environment --systemd $vars 2>/dev/null || true
else
  # shellcheck disable=SC2086
  dbus-update-activation-environment $vars 2>/dev/null || true
fi

# 1b. Colours and materials for the niri this session runs (a new niri may
#     support more glass than the one the last render saw).
command -v vitrum-theme >/dev/null 2>&1 && (vitrum-theme --quiet --no-color-scheme >/dev/null 2>&1 &)

# 2. The shell, restarted if it crashes — but not forever: five crashes inside
#    a minute means something is wrong that restarting will not fix.
rm -f "${XDG_RUNTIME_DIR:-/tmp}/vitrum-shell.stop"
(
  crashes=0 window_start=$(date +%s)
  while :; do
    "$HOME/.local/bin/vitrum-shell"
    [ -e "${XDG_RUNTIME_DIR:-/tmp}/vitrum-shell.stop" ] && break
    now=$(date +%s)
    if [ $((now - window_start)) -gt 60 ]; then crashes=0; window_start=$now; fi
    crashes=$((crashes + 1))
    [ "$crashes" -ge 5 ] && break
    sleep 1
  done
) &

# 3. If the shell is still not up shortly after, show why in a terminal: a
#    shell that died on a QML error leaves an empty screen and nothing to say so.
(
  sleep 8
  pidf="${XDG_RUNTIME_DIR:-/tmp}/vitrum-shell.pid"
  [ -f "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null && exit 0
  log="${XDG_DATA_HOME:-$HOME/.local/share}/vitrum/shell.log"
  for term in kitty foot alacritty xterm; do
    command -v "$term" >/dev/null 2>&1 || continue
    "$term" -e sh -c 'echo "The vitrum shell did not start. Its last words:"; echo; tail -n 60 "$1" 2>/dev/null || echo "(no log at $1)"; echo; echo "Press Enter to close."; read -r _' _ "$log" &
    break
  done
) &
EOF
  [[ "$DRY_RUN" == "1" ]] || chmod +x "$HOME/.local/bin/vitrum-startup"
}

# Generated every run: what niri spawns. Rewritten whole, so re-running is idempotent.
_session_spawns() {
  step "startup programs"
  local audio; audio="$(audio_bootstrap_line)"
  write_file "$NIRI_DIR/generated/session.kdl" <<EOF
// Generated by the vitrum installer — rewritten on every install. Edit overrides.kdl instead.
${audio}
spawn-at-startup "vitrum-startup"
spawn-at-startup "awww-daemon"
spawn-at-startup "sh" "-c" "wl-paste --type text --watch vitrum-clip store"
spawn-at-startup "sh" "-c" "wl-paste --type image --watch vitrum-clip store image"
EOF
}

# --------------------------------------------------------------- keybinds ---

_session_keybinds() {
  step "keybinds"
  local src="${VITRUM_KEYBINDS_MD:-$VITRUM_DIR/KEYBINDS.md}"
  [[ -f "$src" ]] || die "no KEYBINDS.md at $src"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would generate binds from $(basename "$src")"; return 0; fi
  mkdir -p "$NIRI_DIR/generated"
  python3 "$VITRUM_DIR/lib/keybinds.py" "$src" "$NIRI_DIR/generated/binds.kdl" "$VITRUM_PREFIX/binds.json" \
    || die "KEYBINDS.md could not be parsed"
  # Your changes from Settings (keybinds.changes / own) go back over the fresh keymap.
  local theme="$HOME/.local/bin/vitrum-theme"
  [[ -x "$theme" ]] || theme="$(command -v vitrum-theme || true)"
  [[ -n "$theme" ]] && { "$theme" --quiet --no-color-scheme || warn "vitrum-theme could not re-apply your keybinds"; }
  return 0
}

# The VT the login screen runs on: SDDM's MinimumVT (7 unless set).
_session_greeter_vt() {
  local v=""
  v="$(cat "${VITRUM_SYSROOT:-}"/etc/sddm.conf "${VITRUM_SYSROOT:-}"/etc/sddm.conf.d/*.conf 2>/dev/null \
       | sed -n 's/^[[:space:]]*MinimumVT[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' | tail -n 1)"
  printf '%s' "${v:-7}"
}

# ----------------------------------------------------------------- config ---

_session_config() {
  step "niri config"
  write_file "$NIRI_DIR/config.kdl" < "$VITRUM_DIR/config/niri/config.kdl.in"
  # Files vitrum-theme fills in; present (empty) on a fresh install so the
  # config always resolves.
  local f
  for f in look effects animations input; do
    [[ -e "$NIRI_DIR/generated/$f.kdl" ]] && continue
    printf '// Generated by vitrum-theme.\n' | write_file "$NIRI_DIR/generated/$f.kdl"
  done
  if [[ ! -e "$NIRI_DIR/generated/binds.kdl" ]]; then
    printf '// No binds generated.\n' | write_file "$NIRI_DIR/generated/binds.kdl"
  fi
}

# overrides.kdl: yours. Written once when missing, then never again — and not
# through backup_path, so it is not in the manifest and uninstall leaves it.
_session_overrides() {
  local f="$NIRI_DIR/overrides.kdl"
  [[ -e "$f" ]] && { dim "keeping your overrides.kdl"; return 0; }
  [[ "$DRY_RUN" == "1" ]] && { dim "would write a starter $f"; return 0; }
  mkdir -p "$NIRI_DIR"
  cat > "$f" <<'KDL'
// Yours. vitrum includes this file last and never writes it again, so what
// you put here wins over vitrum's config and survives every update.
// Uncomment and edit; niri reloads as soon as you save.
//
// A bind (it replaces vitrum's bind on the same keys):
// binds {
//     Mod+Shift+B { spawn "firefox"; }
//     Mod+Alt+T hotkey-overlay-title="Terminal in home" { spawn-sh "kitty --directory ~"; }
// }
//
// A window rule:
// window-rule {
//     match app-id="firefox"
//     open-maximized true
// }
//
// Input. Careful: a mouse { } or touchpad { } block here replaces the whole
// one from Settings → Mouse & touchpad (niri does not merge them), and the
// Settings sliders stop having an effect.
// input {
//     keyboard {
//         repeat-delay 300
//         repeat-rate 40
//     }
// }
KDL
}

_session_validate() {
  [[ "$DRY_RUN" == "1" ]] && return 0
  have niri || { warn "niri not installed yet — config not validated"; return 0; }
  if niri validate -c "$NIRI_DIR/config.kdl" >/dev/null 2>&1; then
    ok "niri accepts the config"
  else
    niri validate -c "$NIRI_DIR/config.kdl" 2>&1 | tail -n 15 >&2
    die "niri rejected $NIRI_DIR/config.kdl"
  fi
}

# ---------------------------------------------------------------- portals ---

# xdg-desktop-portal reads <first XDG_CURRENT_DESKTOP>-portals.conf, so
# niri-portals.conf. Without one it falls back to the system portals.conf
# (default=*): backends of other desktops get tried too (hyprland, left from
# an earlier setup), and a starting app's portal call can then wait out a
# D-Bus timeout. GTK covers settings, file choosers and the rest; screen
# casting is vitrum-portal's.

_session_portals() {
  step "portal preferences"
  {
    printf '[preferred]
# Written by the vitrum installer.
default=gtk
'
    # No Secret backend: the portal activates it at start, and a gnome-keyring
    # on another D-Bus (started at login, before the session bus) never
    # answers — 25 s that every Qt app, the shell first, waits out.
    # Screen sharing goes through vitrum's own backend (the shell's picker).
    printf 'org.freedesktop.impl.portal.ScreenCast=vitrum
'
  } | write_file "$XDG_CONFIG_HOME/xdg-desktop-portal/niri-portals.conf"
  _session_screencast
}

# vitrum-portal: the ScreenCast backend xdg-desktop-portal hands screen-share
# requests to. It shows the shell's picker and gets the streams from niri.
# The portal reads backends only from /usr/share, so this part is system-wide.
_session_screencast() {
  step "screen sharing (vitrum-portal)"
  local dir="$VITRUM_SYSROOT/usr/local/libexec/vitrum"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would install vitrum-portal"; return 0; fi
  run sudo mkdir -p "$dir"
  run sudo install -m 755 "$VITRUM_DIR/tools/vitrum-portal" "$dir/vitrum-portal"
  run sudo install -m 644 "$VITRUM_DIR/tools/vitrum_portal.py" "$dir/vitrum_portal.py"
  sudo_write "$VITRUM_SYSROOT/usr/share/xdg-desktop-portal/portals/vitrum.portal" <<'EOF'
[portal]
DBusName=org.freedesktop.impl.portal.desktop.vitrum
Interfaces=org.freedesktop.impl.portal.ScreenCast
EOF
  sudo_write "$VITRUM_SYSROOT/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.vitrum.service" <<'EOF'
[D-BUS Service]
Name=org.freedesktop.impl.portal.desktop.vitrum
Exec=/usr/local/libexec/vitrum/vitrum-portal
EOF
}

# The few root actions the desktop takes (WireGuard, disk health): one helper
# with fixed, checked arguments, which a polkit rule lets this user run from
# their active session without a password. Nothing else gets that. Reading
# emerge's log (the bar's build progress) only needs the portage group.
_session_root_helper() {
  step "root helper for VPN, disk health and the login screen (polkit)"
  local dir="$VITRUM_SYSROOT/usr/local/libexec/vitrum" user="${USER:-$(id -un)}"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would install vitrum-root and its polkit rule"; return 0; fi
  run sudo mkdir -p "$dir"
  run sudo install -m 755 "$VITRUM_DIR/tools/vitrum-root" "$dir/vitrum-root"
  sudo_write "$VITRUM_SYSROOT/etc/polkit-1/rules.d/50-vitrum.rules" <<EOF
// Written by the vitrum installer: $user may run vitrum's root helper (and
// only that) without a password, from a local, active session.
polkit.addRule(function (action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        action.lookup("program") == "/usr/local/libexec/vitrum/vitrum-root" &&
        subject.user == "$user" && subject.local && subject.active) {
        return polkit.Result.YES;
    }
});
EOF
  if getent group portage >/dev/null 2>&1 && ! id -nG "$user" | tr ' ' '\n' | grep -qx portage; then
    run sudo usermod -aG portage "$user" && info "you are in the portage group from the next login (the bar shows emerge's progress)"
  fi
}

# -------------------------------------------------------------- migration ---

# Once: carry over the niri-tahoe settings that still mean something.
migrate_tahoe_settings() {
  local old="$XDG_CONFIG_HOME/niri-tahoe/settings.json" new="$VITRUM_PREFIX/settings.json"
  # "{}" is what the shell stage writes when there were no settings yet.
  [[ -f "$old" ]] || return 0
  [[ ! -f "$new" || "$(tr -d '[:space:]' < "$new")" == "{}" ]] || return 0
  step "carrying settings over from niri-tahoe"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would migrate $old"; return 0; fi
  # A snapshot for reference, not a "saved original": uninstall must not put
  # it back over the niri-tahoe settings as they are by then.
  mkdir -p "$VITRUM_STATE/migrated" "$VITRUM_PREFIX"
  cp -a "$old" "$VITRUM_STATE/migrated/niri-tahoe-settings.json"
  python3 - "$old" "$new" <<'PY' || warn "could not migrate niri-tahoe settings"
import json, sys
old = json.load(open(sys.argv[1], encoding="utf-8"))
keep = {}
for section, keys in {"appearance": ["mode", "autoScheduleLight", "autoScheduleDark"],
                      "weather": None, "dock": ["display", "autohide"]}.items():
    src = old.get(section)
    if not isinstance(src, dict):
        continue
    keep[section] = dict(src) if keys is None else {k: src[k] for k in keys if k in src}
keep["migratedFrom"] = "niri-tahoe"
json.dump(keep, open(sys.argv[2], "w", encoding="utf-8"), indent=2)
PY
}
