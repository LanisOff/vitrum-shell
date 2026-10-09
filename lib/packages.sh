# shellcheck shell=bash
# Reads lib/packages.tsv for the active package backend (PKG_BACKEND).

_PKG_TABLE="$VITRUM_DIR/lib/packages.tsv"

_pkg_col() {
  case "$PKG_BACKEND" in
    portage) echo 2 ;;
    pacman)  echo 3 ;;
    *) die "packages.sh: unknown PKG_BACKEND '$PKG_BACKEND'" ;;
  esac
}

# packages_for <need>... — the names to install for the active backend, one per
# line. A row this distribution does not package is skipped with a note on stderr.
packages_for() {
  local col; col="$(_pkg_col)"
  awk -F'\t' -v col="$col" -v needs=" $* " '
    /^#/ || !NF { next }
    index(needs, " " $4 " ") {
      if ($col == "-") { print "note: " $1 " is not packaged here, skipped" > "/dev/stderr"; next }
      print $col
    }' "$_PKG_TABLE"
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
      /^#/ || !NF || $2 == "-" { next }
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
