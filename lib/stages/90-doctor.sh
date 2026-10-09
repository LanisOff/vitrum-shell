#!/usr/bin/env bash
# Stage: doctor — check an install without changing anything.
#
# Failures are things the desktop needs to start; warnings degrade looks, not
# function. Exit status: non-zero when anything failed.

VITRUM_SYSROOT="${VITRUM_SYSROOT:-}"

_DOC_FAIL=0
_DOC_WARN=0

_chk() {  # _chk <label> ok|warn|fail [detail]
  case "$2" in
    ok)   printf '  %s%s%s %s\n' "$C_GREEN" "$G_OK" "$C_RESET" "$1" ;;
    warn) _DOC_WARN=$((_DOC_WARN + 1)); printf '  %s!%s %s%s\n' "$C_YELLOW" "$C_RESET" "$1" "${3:+ — $3}" ;;
    fail) _DOC_FAIL=$((_DOC_FAIL + 1)); printf '  %s%s%s %s%s\n' "$C_RED" "$G_ERR" "$C_RESET" "$1" "${3:+ — $3}" ;;
  esac
}
_chk_path() {  # _chk_path <path> <label> [fail|warn]
  if [[ -e "$1" ]]; then _chk "$2" ok; else _chk "$2" "${3:-fail}" "missing: $1"; fi
}

stage_doctor() {
  stage "Doctor"
  _DOC_FAIL=0 _DOC_WARN=0

  _chk "system: packages $PKG_BACKEND, init $INIT_BACKEND" ok

  local bin="${VITRUM_NIRI_BIN:-/usr/local/bin/niri}"
  if [[ -x "$bin" ]]; then
    _chk "niri: $("$bin" --version 2>/dev/null | head -1)" ok
    # shellcheck source=/dev/null
    [[ -n "${NIRI_REV:-}" ]] || source "$VITRUM_DIR/lib/stages/30-niri.sh"
    if [[ "$(cat "$VITRUM_STATE/niri.rev" 2>/dev/null)" == "$(niri_stamp)" ]]; then
      _chk "compositor built from the pinned niri, glass and patches" ok
    else
      _chk "compositor revision" warn "built from other revisions — ./install.sh --only niri"
    fi
  else
    _chk "niri" fail "not installed — ./install.sh --only niri"
  fi

  _chk_path "$VITRUM_SYSROOT/usr/local/bin/vitrum-session" "session wrapper"
  _chk_path "$VITRUM_SYSROOT/usr/local/share/wayland-sessions/niri.desktop" "login entry"
  _chk_path "$VITRUM_PREFIX/niri/config.kdl" "niri config"
  if [[ -x "$bin" && -e "$VITRUM_PREFIX/niri/config.kdl" ]]; then
    if "$bin" validate -c "$VITRUM_PREFIX/niri/config.kdl" >/dev/null 2>&1; then _chk "niri accepts the config" ok
    else _chk "niri config" fail "rejected — run: niri validate -c $VITRUM_PREFIX/niri/config.kdl"; fi
  fi
  _chk_path "$HOME/.local/bin/vitrum-startup" "startup script"
  _chk_path "$HOME/.local/bin/vitrum-shell" "shell launcher"
  _chk_path "$XDG_CONFIG_HOME/quickshell/vitrum/shell.qml" "shell files"
  if have qs || have quickshell; then _chk "quickshell" ok; else _chk "quickshell" fail "not on PATH"; fi

  local fonts; fonts="$(fc-list 2>/dev/null)"
  local f
  for f in "Inter" "JetBrains Mono" "Material Symbols Rounded"; do
    if grep -q "$f" <<<"$fonts"; then _chk "font: $f" ok; else _chk "font: $f" warn "not found by fontconfig"; fi
  done
  _chk_path "$HOME/.local/share/icons/Bibata-Modern-Classic" "cursor: Bibata Modern Classic" warn

  _doctor_session
  _doctor_kernel

  local missing=() p
  while IFS= read -r p; do pkg_installed "$p" || missing+=("${p%@*}"); done < <(packages_for required 2>/dev/null)
  if [[ ${#missing[@]} -eq 0 ]]; then _chk "every required package is installed" ok
  else _chk "${#missing[@]} required packages missing" fail "${missing[*]}"; fi

  printf '\n'
  if (( _DOC_FAIL > 0 )); then
    err "$_DOC_FAIL problem(s), $_DOC_WARN warning(s)"
    return 1
  fi
  ok "healthy ($_DOC_WARN warning(s))"
  stage_done
}

# Kernel options: warnings, each naming what it costs. Without a readable config
# (no CONFIG_IKCONFIG_PROC, no /boot/config-*) the check says so and moves on.
_doctor_kernel() {
  # shellcheck source=/dev/null
  declare -F kernel_missing >/dev/null || source "$VITRUM_DIR/lib/kernel.sh"
  local config missing line
  if ! config="$(kernel_config 2>/dev/null)" || [[ -z "$config" ]]; then
    _chk "kernel options" warn "no config to read (CONFIG_IKCONFIG_PROC or /boot/config-$(uname -r)) — not checked"
    return 0
  fi
  missing="$(kernel_missing "$config")"
  if [[ -z "$missing" ]]; then _chk "kernel: every option the desktop uses is there" ok; return 0; fi
  while IFS= read -r line; do
    _chk "kernel: CONFIG_${line%%|*} is off" warn "${line#*|}"
  done <<<"$missing"
}

# What the running session gets wrong: screen sharing (portal + niri's D-Bus
# interfaces), sound, the NVIDIA driver, glass. Only checked from inside a
# session; from a tty there is nothing running to ask.
_doctor_session() {
  local sysroot="$VITRUM_SYSROOT"
  _chk_path "$sysroot/usr/share/xdg-desktop-portal/portals/vitrum.portal" "screen-share portal backend" warn
  local conf="$XDG_CONFIG_HOME/xdg-desktop-portal/niri-portals.conf"
  [[ -f "$conf" ]] || conf="$XDG_CONFIG_HOME/xdg-desktop-portal/portals.conf"
  if grep -qs 'ScreenCast=vitrum' "$conf"; then _chk "portals: screen sharing goes to vitrum" ok
  else _chk "portals: screen sharing" warn "not routed to vitrum in $conf — ./install.sh --only session"; fi

  if [[ -z "${WAYLAND_DISPLAY:-}" || -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    _chk "session checks" warn "not inside a graphical session — run vitrum doctor from a terminal in the desktop"
    return 0
  fi
  _doc_name() { busctl --user status "$1" >/dev/null 2>&1 || dbus-send --session --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetNameOwner "string:$1" >/dev/null 2>&1; }
  if _doc_name org.gnome.Mutter.ScreenCast; then _chk "niri's screen-cast interface (niri --session)" ok
  else _chk "niri's screen-cast interface" fail "absent: niri was not started with --session — log out and pick the niri session"; fi
  if pgrep -u "$(id -u)" -x xdg-desktop-portal >/dev/null 2>&1 || _doc_name org.freedesktop.portal.Desktop; then _chk "xdg-desktop-portal" ok
  else _chk "xdg-desktop-portal" warn "not running (it starts on first use)"; fi
  local p
  for p in pipewire wireplumber; do
    if pgrep -u "$(id -u)" -x "$p" >/dev/null 2>&1; then _chk "$p" ok; else _chk "$p" fail "not running — no sound and no screen sharing"; fi
  done
  if [[ -e /sys/module/nvidia ]]; then
    # The parameters are root-only on some kernels: then the kernel command
    # line and modprobe.d tell what was asked for.
    local ms fb asked
    ms="$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || true)"
    fb="$(cat /sys/module/nvidia_drm/parameters/fbdev 2>/dev/null || true)"
    asked="$(cat /proc/cmdline 2>/dev/null || true) $(cat /etc/modprobe.d/*.conf 2>/dev/null | grep -E '^options nvidia[-_]drm' || true)"
    if [[ "$ms" == "Y" ]] || { [[ -z "$ms" ]] && grep -qE 'nvidia[-_]drm[. ].*modeset=1|nvidia-drm\.modeset=1|nvidia_drm\.modeset=1' <<<"$asked"; }; then
      _chk "NVIDIA: kernel modesetting" ok
    elif [[ -z "$ms" ]]; then
      _chk "NVIDIA: kernel modesetting" warn "could not tell (root-only) — make sure nvidia_drm.modeset=1 is set"
    else
      _chk "NVIDIA: kernel modesetting" fail "nvidia_drm.modeset=1 is not set — add it to the kernel command line"
    fi
    if [[ "$fb" == "N" ]]; then _chk "NVIDIA: fbdev" warn "nvidia_drm.fbdev=1 avoids a black console after the session"
    else _chk "NVIDIA: fbdev" ok; fi
  fi
  local caps="${XDG_DATA_HOME:-$HOME/.local/share}/vitrum/niri-caps.json"
  if grep -qs '"shapedGlass": true' "$caps"; then _chk "shaped glass (islands and panels as one drop)" ok
  else _chk "shaped glass" warn "the running niri lacks it — log out and in after an update, or ./install.sh --only niri"; fi
}
