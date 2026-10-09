# shellcheck shell=bash
# Init backend: systemd.

svc_exists() { systemctl list-unit-files "$1.service" 2>/dev/null | grep -q "^$1.service"; }

svc_use_networkmanager() { svc_enable_system NetworkManager; }

svc_enable_system() {
  if ! svc_exists "$1"; then dim "no systemd unit $1 — skipped"; return 0; fi
  run_ok sudo systemctl enable --now "$1.service" || warn "could not enable $1"
}

# Like upstream niri-session: hand the environment to systemd --user, then
# run the compositor as a user unit so graphical-session.target is reached and
# portals that require it start.
session_exec_line() {
  cat <<'EOF'
if systemctl --user -q is-active niri.service; then
  echo "a niri session is already running" >&2; exit 1
fi
systemctl --user reset-failed niri.service 2>/dev/null
systemctl --user import-environment XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE VITRUM NIRI_CONFIG PATH \
  QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_WAYLAND_DISABLE_WINDOWDECORATION GDK_BACKEND MOZ_ENABLE_WAYLAND \
  ELECTRON_OZONE_PLATFORM_HINT SDL_VIDEODRIVER _JAVA_AWT_WM_NONREPARENTING \
  GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME LIBVA_DRIVER_NAME NVD_BACKEND 2>/dev/null
systemctl --user --wait start niri.service
EOF
}

session_unit_install() {
  sudo_write "${VITRUM_SYSROOT:-}/etc/systemd/user/niri.service" <<'EOF'
[Unit]
Description=niri (liquid glass), with the vitrum shell
BindsTo=graphical-session.target
Before=graphical-session.target
Wants=graphical-session-pre.target
After=graphical-session-pre.target

[Service]
Slice=session.slice
Type=notify
ExecStart=/usr/local/bin/niri --session
EOF
}

# PipeWire is socket-activated by systemd --user — once its units are enabled,
# which Arch does by default and Gentoo does not.
audio_bootstrap_line() { :; }

audio_enable_user() {
  local units=(pipewire.socket pipewire-pulse.socket wireplumber.service) u off=0
  for u in "${units[@]}"; do systemctl --user -q is-enabled "$u" 2>/dev/null || off=1; done
  [[ $off == 1 ]] || return 0
  run_ok systemctl --user enable --now "${units[@]}" || warn "could not enable the PipeWire user units"
}

# svc_enable_display_manager <dm> [force] — force replaces the current
# display-manager.service alias; only with the user's consent (lib/dm.sh).
svc_enable_display_manager() {
  if [[ "${2:-}" == force ]]; then run_ok sudo systemctl enable --force "$1.service" || warn "could not enable $1"
  else run_ok sudo systemctl enable "$1.service" || warn "could not enable $1"; fi
}

dm_current() {
  local link
  link="$(readlink "${VITRUM_ROOTFS:-}/etc/systemd/system/display-manager.service" 2>/dev/null)" || return 0
  link="${link##*/}"; printf '%s\n' "${link%.service}"
}
