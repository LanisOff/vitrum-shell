#!/usr/bin/env bash
# Stage: packages — everything the desktop needs at runtime, plus build deps.
#
# The list lives in lib/packages.tsv; this stage only decides which optional
# groups apply and hands the missing names to the package backend.

_package_needs() {
  local needs=(required)
  if lspci 2>/dev/null | grep -qiE '(VGA|3D).*NVIDIA'; then needs+=(nvidia); fi
  [[ "${WANT_SDDM:-1}" == 1 ]] && needs+=(sddm)
  [[ "${WANT_PLYMOUTH:-0}" == 1 ]] && needs+=(plymouth)
  [[ "${WANT_LIVE_WALLPAPER:-1}" == 1 ]] && needs+=(live-wallpaper)
  [[ "${WANT_TMUX:-0}" == 1 ]] && needs+=(tmux)
  [[ "${WANT_NVIM:-0}" == 1 ]] && needs+=(nvim)
  [[ "${WANT_EXTRAS:-1}" == 1 ]] && needs+=(extras)
  [[ "${WANT_PHONE:-0}" == 1 ]] && needs+=(phone)
  printf '%s\n' "${needs[@]}"
}

stage_packages() {
  stage "Packages"

  step "preparing the package manager ($PKG_BACKEND)"
  pkg_prepare

  local needs=() todo=() p
  mapfile -t needs < <(_package_needs)
  while IFS= read -r p; do
    pkg_installed "$p" || todo+=("$p")
  done < <(packages_for "${needs[@]}")

  # Everything must be installable before anything is: one unavailable atom
  # fails the whole emerge transaction with a message about something else.
  local unavailable=()
  for p in "${todo[@]}"; do pkg_available "${p%@*}" || unavailable+=("${p%@*}"); done
  if [[ ${#unavailable[@]} -gt 0 ]]; then
    if [[ "$PKG_BACKEND" == portage ]]; then
      die "not available: ${unavailable[*]} — enable the overlays vitrum uses and sync them: sudo eselect repository enable guru gentoo-zh hyproverlay && for r in guru gentoo-zh hyproverlay; do sudo emaint sync -r \$r; done"
    fi
    die "not available in your repositories: ${unavailable[*]} — refresh the package databases and check your mirrors"
  fi

  # Installed packages first: what gets built next links against them, and a
  # Qt module built before vitrum's USE (qtdeclarative without opengl) breaks
  # the link of quickshell and libplasma.
  pkg_apply_use

  if [[ ${#todo[@]} -eq 0 ]]; then
    ok "every package is already installed"
  else
    step "installing ${#todo[@]} packages: ${todo[*]}"
    [[ "$PKG_BACKEND" == portage ]] && info "Gentoo builds from source — this can take a long time."
    pkg_install "${todo[@]}"
    ok "packages installed"
  fi

  step "system services ($INIT_BACKEND)"
  local svc
  # systemd always runs these; on OpenRC nothing starts them, and without them
  # SDDM has no system bus and niri no seat (elogind early, as Gentoo advises).
  if [[ "$INIT_BACKEND" == openrc ]]; then
    svc_enable_system elogind boot
    svc_enable_system dbus
  fi
  for svc in bluetooth power-profiles-daemon; do svc_enable_system "$svc"; done
  # The shell's network panel talks to NetworkManager.
  svc_use_networkmanager

  # Input devices plugged in since boot were seen by udev before libinput and
  # elogind brought their rules, and libinput passes over them: on a fresh
  # system the login screen took the mouse and not the keyboard. Replay them.
  if have udevadm; then
    run_ok sudo udevadm trigger --action=change --subsystem-match=input || true
  fi

  stage_done
}
