#!/usr/bin/env bash
# Stage: preflight — refuse to start on a system we would break.
#
# The package and init backends are already chosen (load_backends in
# install.sh), so an unsupported system never gets this far. Nothing here asks:
# the questions it used to ask (go on with little disk space, go on at all)
# are the confirmation screen's, answered before any stage runs, and
# preflight_facts gives that screen what it needs to know.

# Free space in $HOME in MB, 0 when df cannot say.
_preflight_free_mb() {
  local mb
  mb="$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')" || mb=""
  [[ "$mb" =~ ^[0-9]+$ ]] || mb=0
  printf '%s\n' "$mb"
}

# preflight_facts — what the screens need to know before anything runs:
# FACT_FREE_MB (as the disk check below), FACT_DM (the login screen in use,
# empty for none or SDDM), FACT_SHELL and FACT_FISH_IS_SHELL, and
# FACT_NIRI_BUILD (1 when the niri stage will build).
# shellcheck disable=SC2034  # read by the confirmation screen
preflight_facts() {
  FACT_FREE_MB="$(_preflight_free_mb)"
  FACT_DM=""
  if declare -F dm_current >/dev/null; then
    FACT_DM="$(dm_current 2>/dev/null)" || FACT_DM=""
    [[ "$FACT_DM" == sddm ]] && FACT_DM=""
  fi
  FACT_SHELL="${SHELL:-}"
  FACT_FISH_IS_SHELL=0
  [[ "${FACT_SHELL##*/}" == fish ]] && FACT_FISH_IS_SHELL=1
  # shellcheck source=lib/stages/30-niri.sh
  declare -F niri_needs_build >/dev/null || source "$VITRUM_DIR/lib/stages/30-niri.sh"
  FACT_NIRI_BUILD=0
  niri_needs_build && FACT_NIRI_BUILD=1
  return 0
}

stage_preflight() {
  stage "Preflight"

  [[ "$(uname -s)" == "Linux" ]] || die "vitrum runs on Linux"
  [[ $EUID -ne 0 ]] || die "run as your normal user, not root (sudo is used per command)"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    info "distribution: ${PRETTY_NAME:-unknown} — packages: $PKG_BACKEND, init: $INIT_BACKEND"
  fi

  if [[ -n "${VITRUM_LOCALE_MISSING:-}" ]]; then
    warn 'locale %s is not generated (this run borrows %s; perl and other programs keep warning about it) — uncomment it in /etc/locale.gen and run: sudo locale-gen' \
      "$VITRUM_LOCALE_MISSING" "${LC_ALL:-C}"
  fi

  step "checking sudo"
  sudo_keepalive

  if [[ "$PKG_BACKEND" == portage ]] && ! portage_desktop_profile; then
    warn 'Gentoo profile %s is not a desktop one — vitrum adds the USE a desktop needs (%s) for every package; a desktop profile does that and more: sudo eselect profile set default/linux/amd64/23.0/desktop' \
      "$(portage_profile | sed 's#.*/profiles/##')" "$VITRUM_BASE_USE"
  fi

  step "checking disk space"
  local free_mb
  free_mb="$(_preflight_free_mb)"
  if [[ "$free_mb" -lt 6000 ]]; then
    # shellcheck disable=SC2016  # $HOME is shown as it is, not expanded
    warn 'only %sMB free in $HOME — the niri build alone wants about 5GB' "$free_mb"
  else
    ok "${free_mb}MB free"
  fi

  step "checking graphics"
  if lspci 2>/dev/null | grep -qiE '(VGA|3D).*NVIDIA'; then
    local modeset; modeset="$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo unknown)"
    if [[ "$modeset" == "Y" ]]; then
      ok "NVIDIA with nvidia-drm.modeset=1"
    else
      warn "NVIDIA GPU, but nvidia-drm modeset is '%s' — add nvidia-drm.modeset=1 to the kernel command line or the glass has no GBM path" "$modeset"
    fi
  fi
  if [[ -r /proc/cpuinfo ]] && grep -qi 'hypervisor' /proc/cpuinfo; then
    warn "running inside a VM — the glass shader may be slow or unavailable"
  fi

  info "backup directory: $BACKUP_DIR"
  stage_done
}
