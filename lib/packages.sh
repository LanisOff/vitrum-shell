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

# The groups of lib/packages.tsv this run needs, one per line. Shared by the
# packages stage and the start-of-run check (lib/prereqs.sh).
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

# pkg_unavailable <pkg>... — those the package databases do not offer, one per
# line (without any @-suffix). Needs pkg_available from the backend.
pkg_unavailable() {
  local p
  for p in "$@"; do pkg_available "${p%@*}" || printf '%s\n' "${p%@*}"; done
}

# pkg_unavailable_message <name>... — what to tell the user about them.
pkg_unavailable_message() {
  if [[ "$PKG_BACKEND" == portage ]]; then
    printf 'not available: %s — enable the overlays vitrum uses and sync them: sudo eselect repository enable guru gentoo-zh hyproverlay && for r in guru gentoo-zh hyproverlay; do sudo emaint sync -r $r; done' "$*"
  else
    printf 'not available in your repositories: %s — refresh the package databases and check your mirrors' "$*"
  fi
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
