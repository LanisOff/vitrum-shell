# shellcheck shell=bash
# Chooses the package and init backends. Sourced by install.sh after common.sh.
#
# Two independent axes — what installs packages, and what runs services. The
# supported pairs are the ones that exist in the wild and that we can test:
# Gentoo with OpenRC, Gentoo with systemd, Arch with systemd.
#
# VITRUM_ROOTFS (default empty, i.e. /) lets tests point detection at a fake root.

detect_pkg_backend() {
  if have emerge; then echo portage
  elif have pacman; then echo pacman
  else echo none; fi
}

detect_init_backend() {
  local r="${VITRUM_ROOTFS:-}"
  if [[ -d "$r/run/systemd/system" ]]; then echo systemd
  elif [[ -d "$r/run/openrc" ]]; then echo openrc
  else echo none; fi
}

load_backends() {
  PKG_BACKEND="$(detect_pkg_backend)"
  INIT_BACKEND="$(detect_init_backend)"
  case "$PKG_BACKEND+$INIT_BACKEND" in
    portage+openrc|portage+systemd|pacman+systemd) ;;
    *) die "unsupported system: packages=$PKG_BACKEND init=$INIT_BACKEND (supported: Gentoo with OpenRC or systemd, Arch with systemd)" ;;
  esac
  # shellcheck source=/dev/null
  source "$VITRUM_DIR/lib/backend/pkg-$PKG_BACKEND.sh"
  # shellcheck source=/dev/null
  source "$VITRUM_DIR/lib/backend/init-$INIT_BACKEND.sh"
  export PKG_BACKEND INIT_BACKEND
}
