# shellcheck shell=bash
# Init backend: OpenRC, with elogind providing the seat and session.

svc_exists() { [[ -x "${VITRUM_ROOTFS:-}/etc/init.d/$1" ]]; }

svc_enable_system() {  # <service> [runlevel, default: default]
  local level="${2:-default}"
  if ! svc_exists "$1"; then dim "no OpenRC service $1 — skipped"; return 0; fi
  run_ok sudo rc-update add "$1" "$level" || warn "could not add $1 to the $level runlevel"
  run_ok sudo rc-service "$1" start >/dev/null 2>&1 || true
}

# Without systemd nobody starts a session bus for us; a display manager on
# OpenRC may or may not have, so only start one when there is none. niri runs
# as a session instance: that is when it publishes its D-Bus interfaces
# (screencast for screen sharing, display config); the systemctl part of its
# environment import just fails quietly here.
session_exec_line() {
  printf '%s\n' 'if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then dbus-run-session /usr/local/bin/niri --session; else /usr/local/bin/niri --session; fi'
}

# Gentoo starts PipeWire per session with gentoo-pipewire-launcher, unless the
# user already runs it as an OpenRC user service.
audio_bootstrap_line() {
  if rc-update --user show 2>/dev/null | grep -q pipewire; then return 0; fi
  if have gentoo-pipewire-launcher; then printf 'spawn-at-startup "gentoo-pipewire-launcher" "restart"\n'; fi
}

# Gentoo's display-manager service starts whatever /etc/conf.d/display-manager names.
svc_enable_display_manager() {  # <dm> [force] — OpenRC has one slot; consent is checked in lib/dm.sh
  local dm="$1" conf="${VITRUM_ROOTFS:-}/etc/conf.d/display-manager" content
  content="$(grep -v '^DISPLAYMANAGER=' "$conf" 2>/dev/null || true)"
  printf '%s\nDISPLAYMANAGER="%s"\n' "$content" "$dm" | sed '/./,$!d' | sudo_write "$conf"
  run_ok sudo rc-update add display-manager default || warn "could not add display-manager to the default runlevel"
}

# A fresh Gentoo often runs dhcpcd, which fights NetworkManager over the
# interfaces: NetworkManager goes into the default runlevel and dhcpcd out of
# it, from the next boot — switching under a running install would cut the
# network mid-build.
svc_use_networkmanager() {
  svc_exists NetworkManager || return 0
  run_ok sudo rc-update add NetworkManager default || { warn "could not add NetworkManager to the default runlevel"; return 0; }
  if rc-update show default 2>/dev/null | grep -qw dhcpcd; then
    run_ok sudo rc-update del dhcpcd default || true
    info "network: NetworkManager from the next boot (dhcpcd left the default runlevel — the two fight over the interfaces)"
  fi
}

# No user units on OpenRC: the session wrapper runs niri directly.
session_unit_install() { :; }

# PipeWire is started per session by audio_bootstrap_line.
audio_enable_user() { :; }

# The display manager OpenRC starts, if display-manager is in the default runlevel.
dm_current() {
  rc-update show default 2>/dev/null | grep -q '\bdisplay-manager\b' || return 0
  local v
  v="$(sed -n 's/^DISPLAYMANAGER="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "${VITRUM_ROOTFS:-}/etc/conf.d/display-manager" 2>/dev/null | tail -1)"
  printf '%s\n' "${v:-xdm}"
}
