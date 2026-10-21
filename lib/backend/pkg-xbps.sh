# shellcheck shell=bash
# Package backend: Void xbps. Stages never call xbps themselves.
#
# Everything vitrum needs is in Void's main repository; nonfree is enabled
# only for an NVIDIA GPU (the driver lives there). What Void does not package
# at all (adw-gtk3, JetBrains Mono, its Nerd Font, the noise filter) is "-" in
# the table and comes from lib/assets.tsv instead — never the 7 GB
# nerd-fonts-ttf, which is every Nerd font there is.

# "name@cmd" also counts as installed when cmd exists; "a|b" when either is.
pkg_installed() {
  local spec="$1" alt
  if [[ "$spec" == *@* ]]; then have "${spec##*@}" && return 0; spec="${spec%@*}"; fi
  IFS='|' read -ra alts <<<"$spec"
  for alt in "${alts[@]}"; do xbps-query "$alt" >/dev/null 2>&1 && return 0; done
  return 1
}

# -R looks in the repositories as well as the installed packages.
pkg_available() { local a="${1%@*}"; xbps-query -R "${a%%|*}" >/dev/null 2>&1; }

# The NVIDIA driver and several packages are built for glibc only.
_xbps_check_libc() {
  local arch; arch="$(xbps-uhelper arch 2>/dev/null)" || return 0
  [[ "$arch" == *-musl ]] && die 'Void on musl (%s) is not supported: vitrum needs the glibc flavour (the NVIDIA driver and several of its packages are glibc-only)' "$arch"
  return 0
}

# Is a newer xbps in the repositories? xbps refuses to install anything until
# it has updated itself.
_xbps_self_update_due() {
  xbps-install -un 2>/dev/null | awk '$1 ~ /^xbps-[0-9]/ { found = 1 } END { exit !found }'
}

# -S syncs the repository index; -y accepts a repository's signing key on the
# first sync, which would otherwise be a question on the terminal.
pkg_prepare() {
  _xbps_check_libc
  step "syncing the repositories"
  run sudo xbps-install -Sy
  if [[ "$DRY_RUN" != "1" ]] && _xbps_self_update_due; then
    step "updating xbps first (it installs nothing until it is current)"
    run sudo xbps-install -uy xbps
  fi
  if _package_needs | grep -qx nvidia && ! xbps-query void-repo-nonfree >/dev/null 2>&1; then
    step "enabling Void's nonfree repository (the NVIDIA driver is there)"
    run sudo xbps-install -y void-repo-nonfree
    run sudo xbps-install -Sy
  fi
  return 0
}

# xbps-install answers 17 (EEXIST) when everything asked for is already there.
pkg_install() {
  [[ $# -eq 0 ]] && return 0
  local p names=() rc=0
  for p in "$@"; do p="${p%@*}"; names+=("${p%%|*}"); done
  run_ok sudo xbps-install -y "${names[@]}" || rc=$?
  case "$rc" in
    0|17) return 0 ;;
    *) die 'not installed: %s — see the xbps-install output above (it stopped with status %s)' "${names[*]}" "$rc" ;;
  esac
}

pkg_apply_use() { :; }

pkg_write_portage_files() { :; }
