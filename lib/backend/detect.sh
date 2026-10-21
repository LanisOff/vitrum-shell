# shellcheck shell=bash
# Chooses the package and init backends. Sourced by install.sh after common.sh.
#
# Two independent axes — what installs packages, and what runs services. The
# supported pairs are the ones that exist in the wild and that we can test:
# Gentoo with OpenRC, Gentoo with systemd, Arch with systemd, Fedora with
# systemd, and Void with runit.
#
# VITRUM_ROOTFS (default empty, i.e. /) lets tests point detection at a fake root.

# _os_release_ids — ID and every word of ID_LIKE from os-release, one per line.
# awk rather than sed: the tests also run on macOS, whose sed has no \|.
_os_release_ids() {
  awk -F= '$1 == "ID" || $1 == "ID_LIKE" { gsub(/"/, "", $2); n = split($2, w, " "); for (i = 1; i <= n; i++) print w[i] }' \
    "${VITRUM_ROOTFS:-}/etc/os-release" 2>/dev/null
}
_os_is() { _os_release_ids | grep -qx "$1"; }

# Is this package tool there? The tests (VITRUM_TEST=1, see lib/common.sh)
# name the one folder to look in, VITRUM_DETECT_PATH (their stubs): on the
# machine running them, the real pacman or emerge in /usr/bin must not decide
# which distribution a test pretends to be.
_detect_tool() {
  if [[ "${VITRUM_TEST:-}" == 1 && -n "${VITRUM_DETECT_PATH:-}" ]]; then [[ -x "$VITRUM_DETECT_PATH/$1" ]]
  else have "$1"; fi
}

# dnf alone is not Fedora (openSUSE and Mageia can have it too), so the
# os-release check comes with it; xbps exists only on Void.
detect_pkg_backend() {
  if _detect_tool emerge; then echo portage
  elif _detect_tool pacman; then echo pacman
  elif _detect_tool dnf && _os_is fedora; then echo dnf
  elif _detect_tool xbps-install; then echo xbps
  else echo none; fi
}

# runit leaves /run/runit behind once it has booted, and is PID 1. Its exe
# link is root's to read, its comm is anyone's. A container runs neither
# systemd nor runit as PID 1, so the distribution decides there: Fedora has
# only systemd and Void only runit, which is what an installed system of
# either boots.
detect_init_backend() {
  local r="${VITRUM_ROOTFS:-}" pid1=""
  pid1="$(readlink "$r/proc/1/exe" 2>/dev/null || cat "$r/proc/1/comm" 2>/dev/null || true)"
  if [[ -d "$r/run/systemd/system" ]]; then echo systemd
  elif [[ -d "$r/run/openrc" ]]; then echo openrc
  elif [[ -d "$r/run/runit" || "${pid1##*/}" == runit ]]; then echo runit
  elif _os_is void; then echo runit
  elif _os_is fedora; then echo systemd
  else echo none; fi
}

load_backends() {
  PKG_BACKEND="$(detect_pkg_backend)"
  INIT_BACKEND="$(detect_init_backend)"
  case "$PKG_BACKEND+$INIT_BACKEND" in
    portage+openrc|portage+systemd|pacman+systemd|dnf+systemd|xbps+runit) ;;
    *) die 'unsupported system: packages=%s init=%s (supported: Gentoo with OpenRC or systemd, Arch with systemd, Fedora with systemd, Void with runit)' "$PKG_BACKEND" "$INIT_BACKEND" ;;
  esac
  # shellcheck source=/dev/null
  source "$VITRUM_DIR/lib/backend/pkg-$PKG_BACKEND.sh"
  # shellcheck source=/dev/null
  source "$VITRUM_DIR/lib/backend/init-$INIT_BACKEND.sh"
  export PKG_BACKEND INIT_BACKEND
}
