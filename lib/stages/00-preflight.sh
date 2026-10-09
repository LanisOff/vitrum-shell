#!/usr/bin/env bash
# Stage: preflight — refuse to start on a system we would break.
#
# The package and init backends are already chosen (load_backends in
# install.sh), so an unsupported system never gets this far.

stage_preflight() {
  stage "Preflight"

  [[ "$(uname -s)" == "Linux" ]] || die "vitrum runs on Linux"
  [[ $EUID -ne 0 ]] || die "run as your normal user, not root (sudo is used per command)"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    info "distribution: ${PRETTY_NAME:-unknown} — packages: $PKG_BACKEND, init: $INIT_BACKEND"
  fi

  step "checking sudo"
  sudo_keepalive

  if [[ "$PKG_BACKEND" == portage ]] && ! portage_desktop_profile; then
    warn "Gentoo profile $(portage_profile | sed 's#.*/profiles/##') is not a desktop one — vitrum adds the USE a desktop needs ($VITRUM_BASE_USE) for every package; a desktop profile does that and more: sudo eselect profile set default/linux/amd64/23.0/desktop"
  fi

  step "checking disk space"
  local free_mb
  free_mb=$(df -Pm "$HOME" | awk 'NR==2 {print $4}')
  if [[ "${free_mb:-0}" -lt 6000 ]]; then
    warn "only ${free_mb}MB free in \$HOME — the niri build alone wants about 5GB"
    confirm "continue anyway?" n || die "aborted"
  else
    ok "${free_mb}MB free"
  fi

  step "checking graphics"
  if lspci 2>/dev/null | grep -qiE '(VGA|3D).*NVIDIA'; then
    local modeset; modeset="$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo unknown)"
    if [[ "$modeset" == "Y" ]]; then
      ok "NVIDIA with nvidia-drm.modeset=1"
    else
      warn "NVIDIA GPU, but nvidia-drm modeset is '$modeset' — add nvidia-drm.modeset=1 to the kernel command line or the glass has no GBM path"
    fi
  fi
  if [[ -r /proc/cpuinfo ]] && grep -qi 'hypervisor' /proc/cpuinfo; then
    warn "running inside a VM — the glass shader may be slow or unavailable"
  fi

  info "backup directory: $BACKUP_DIR"
  cat <<EOF

  This installer will:
    - install packages with $PKG_BACKEND (missing ones only)$(
      [[ "$PKG_BACKEND" == portage ]] && printf '\n    - enable the guru, gentoo-zh and hyproverlay overlays if they are not enabled yet')
    - build niri with liquid glass from source (a few minutes to half an hour)
    - replace your GTK / Qt / kitty configuration (backed up first)
    - add a "vitrum" login session; other sessions stay as they are

EOF
  confirm "proceed?" y || die "aborted"
  stage_done
}
