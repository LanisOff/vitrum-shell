# shellcheck shell=bash
# Reads lib/packages.tsv for the active package backend (PKG_BACKEND).

_PKG_TABLE="$VITRUM_DIR/lib/packages.tsv"

_pkg_col() {
  case "$PKG_BACKEND" in
    portage) echo 2 ;;
    pacman)  echo 3 ;;
    dnf)     echo 8 ;;
    xbps)    echo 9 ;;
    *) die "packages.sh: unknown PKG_BACKEND '%s'" "$PKG_BACKEND" ;;
  esac
}

# The groups of lib/packages.tsv this run needs, one per line. Shared by the
# packages stage and the start-of-run check (lib/prereqs.sh); the registry in
# lib/components.sh knows which part wants which group.
_package_needs() { components_needs; }

# pkg_unavailable <pkg>... — those the package databases do not offer, one per
# line (without any @-suffix). Needs pkg_available from the backend.
pkg_unavailable() {
  local p
  for p in "$@"; do pkg_available "${p%@*}" || printf '%s\n' "${p%@*}"; done
}

# pkg_unavailable_message <name>... — what to tell the user about them, in the
# language of the stage messages.
pkg_unavailable_message() {
  if [[ "$PKG_BACKEND" == portage ]]; then
    # shellcheck disable=SC2016  # $r belongs to the command the user copies
    L 'not available: %s — enable the overlays vitrum uses and sync them: sudo eselect repository enable guru gentoo-zh hyproverlay && for r in guru gentoo-zh hyproverlay; do sudo emaint sync -r $r; done' "$*"
  elif [[ "$PKG_BACKEND" == dnf ]]; then
    L 'not available in your repositories: %s — refresh them (sudo dnf makecache) and check that the COPR and RPM Fusion repositories vitrum enabled are reachable' "$*"
  elif [[ "$PKG_BACKEND" == xbps ]]; then
    L 'not available in your repositories: %s — sync them (sudo xbps-install -S) and check your mirror' "$*"
  else
    L 'not available in your repositories: %s — refresh the package databases and check your mirrors' "$*"
  fi
}

# packages_for <need>... — the names to install for the active backend, one per
# line. A row this distribution does not package is skipped with a note on stderr.
packages_for() {
  local col; col="$(_pkg_col)"
  # "." is not needed here: silent. "-" is not packaged: noted, unless
  # lib/assets.tsv fetches it from upstream instead (its last column).
  local stand_ins
  stand_ins=" $(awk -F'\t' '!/^#/ && NF && $6 != "" && $6 != "-" { printf "%s ", $6 }' "${VITRUM_ASSETS_TABLE:-$VITRUM_DIR/lib/assets.tsv}" 2>/dev/null) "
  awk -F'\t' -v col="$col" -v needs=" $* " -v stand="$stand_ins" '
    /^#/ || !NF { next }
    index(needs, " " $4 " ") {
      if ($col == ".") next
      if ($col == "-") {
        if (!index(stand, " " $1 " ")) print "note: " $1 " is not packaged here, skipped" > "/dev/stderr"
        next
      }
      print $col
    }' "$_PKG_TABLE"
}

# packages_named <logical>... — those rows' names for the active backend, one
# per line, whatever their need; a row this distribution does not package is
# left out.
packages_named() {
  local col; col="$(_pkg_col)"
  awk -F'\t' -v col="$col" -v names=" $* " '
    /^#/ || !NF { next }
    index(names, " " $1 " ") && $col != "-" && $col != "." { print $col }' "$_PKG_TABLE"
}

# packages_unpackaged <need>... — the logical names of the selected rows this
# distribution does not package ("-" in its column), one per line. Some of
# them lib/assets.tsv fetches from upstream instead.
packages_unpackaged() {
  local col; col="$(_pkg_col)"
  awk -F'\t' -v col="$col" -v needs=" $* " '
    /^#/ || !NF { next }
    index(needs, " " $4 " ") && $col == "-" { print $1 }' "$_PKG_TABLE"
}

# Heavy C++ builds that come in as dependencies; with no swap they are OOM-killed at full -j.
_HALF_JOBS_DEPS=(net-libs/webkit-gtk dev-qt/qtwebengine llvm-core/clang llvm-core/llvm dev-lang/rust)

# USE the dependencies need on a profile that is not a desktop one
# (default/linux/amd64/23.0 has no opengl, wayland, alsa…). Left to autounmask,
# emerge turns them on one package at a time and writes contradictions — qtbase
# opengl, then qtbase -opengl for a Qt module that wants opengl= — so they are
# set up front. Every Qt module needs qtbase's opengl/vulkan/icu, hence the
# whole category. KDE Connect's clipboard goes through kguiaddons, which without
# wayland only sees the clipboard while it has a focused window — never.
_USE_DEPS=(
  "dev-qt/* opengl vulkan wayland X qml icu"
  "dev-qt/qtbase libproxy"
  "kde-frameworks/* qml X wayland"
  "x11-libs/gtk+ wayland"
  "gui-libs/gtk wayland"
  "media-libs/libcanberra alsa"
  "net-misc/networkmanager wifi bluetooth policykit nftables"
  "net-dns/avahi mdnsresponder-compat"
  "dev-cpp/cpptrace unwind"
  "sys-libs/zlib minizip"
)

# packages_portage_column keywords|use|env — the content of the matching
# /etc/portage file for the Gentoo atoms in the table.
packages_portage_column() {
  local which="$1" d
  {
    awk -F'\t' -v w="$which" '
      /^#/ || !NF || $2 == "-" || $2 == "." { next }
      w == "keywords" && $5 != "-" { print $2 " " $5 }
      w == "use"      && $6 != "-" { print $2 " " $6 }
      w == "env"      && $7 == "half" { print $2 " vitrum-half-jobs.conf" }' "$_PKG_TABLE"
    if [[ "$which" == env ]]; then
      for d in "${_HALF_JOBS_DEPS[@]}"; do printf '%s vitrum-half-jobs.conf\n' "$d"; done
    fi
    if [[ "$which" == use ]]; then
      for d in "${_USE_DEPS[@]}"; do printf '%s\n' "$d"; done
    fi
  } | sort -u
}
