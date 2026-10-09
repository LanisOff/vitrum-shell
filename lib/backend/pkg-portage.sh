# shellcheck shell=bash
# Package backend: Gentoo portage.
#
# Every package-manager action of the installer goes through these four
# functions; stages never call emerge themselves.

# A table entry may list alternatives, "a|b": installed if any is, and the
# first one is what gets installed (e.g. dev-lang/rust-bin|dev-lang/rust).
# A trailing "@cmd" also counts the entry as installed when that command
# exists — for toolchains present on the system without a package record.
pkg_installed() {
  local alt spec="$1"
  if [[ "$spec" == *@* ]]; then have "${spec##*@}" && return 0; spec="${spec%@*}"; fi
  IFS='|' read -ra alts <<<"$spec"
  for alt in "${alts[@]}"; do
    compgen -G "${VITRUM_ROOTFS:-}/var/db/pkg/${alt%%::*}-[0-9]*" >/dev/null && return 0
  done
  return 1
}

# Portage reads ROOT as the filesystem to install into. Nothing of ours sets it,
# but one inherited from the caller's environment would send packages elsewhere,
# so every portage command runs without it.
# Is there an ebuild for it in an enabled repository? Keywords are ignored
# (ACCEPT_KEYWORDS="**"): the ones vitrum needs are written before installing,
# and are not written at all in a dry run. package.mask still applies.
pkg_available() {
  local a="${1%@*}"; a="${a%%|*}"
  [[ -n "$(env -u ROOT ACCEPT_KEYWORDS='**' portageq best_visible / "$a" 2>/dev/null)" ]]
}

# --noreplace: never rebuild what is already there; autounmask writes any
# keyword/USE change portage asks for straight into /etc/portage (CONFIG_PROTECT
# would otherwise park it in a ._cfg file and stop).
_emerge() {
  run_ok sudo env -u ROOT CONFIG_PROTECT_MASK=/etc/portage emerge --ask=n --noreplace --keep-going --quiet-build=y \
    --autounmask=y --autounmask-write=y --autounmask-continue=y --autounmask-keep-masks=y "$@"
}

# One transaction first. If it fails, --keep-going is not enough: after a
# failure portage recomputes the rest, and on a real system that can stop on
# unrelated dependencies, leaving everything queued after the failure unbuilt.
# So whatever is still missing is tried once more on its own, and only what
# really cannot be installed is reported.
pkg_install() {
  [[ $# -eq 0 ]] && return 0
  local atoms=() a
  for a in "$@"; do a="${a%@*}"; atoms+=("${a%%|*}"); done
  _emerge "${atoms[@]}" && return 0
  [[ "$DRY_RUN" == "1" ]] && return 0
  warn "the batch did not finish — installing what is still missing one by one"
  local failed=()
  for a in "${atoms[@]}"; do
    pkg_installed "$a" && continue
    _emerge "$a" || failed+=("$a")
  done
  [[ ${#failed[@]} -eq 0 ]] && return 0
  die "not installed: ${failed[*]} — see the emerge output above (a download failure means no network or a dead mirror)"
}

# The overlays the Gentoo atoms in lib/packages.tsv come from (quickshell,
# matugen, awww, mpvpaper, … are not in the gentoo repository).
VITRUM_OVERLAYS=(guru gentoo-zh hyproverlay)

_portage_repos() { env -u ROOT portageq get_repos / 2>/dev/null | tr ' ' '\n'; }

# An overlay is synced when its directory has something in it; one that is in
# repos.conf but was never synced (a sync that failed) has no directory at all.
_portage_repo_synced() {
  local path; path="$(env -u ROOT portageq get_repo_path / "$1" 2>/dev/null)"
  [[ -n "$path" && -n "$(ls -A "${VITRUM_ROOTFS:-}$path" 2>/dev/null)" ]]
}

# Enable whichever of them is not in repos.conf, then sync every one that has
# not been synced. eselect-repository writes the repos.conf entry; the overlays
# are git repositories, so git syncs them. One emaint per overlay: emaint sync
# keeps only the last of several -r.
pkg_enable_overlays() {
  local repos r disabled=() unsynced=()
  repos="$(_portage_repos)"
  for r in "${VITRUM_OVERLAYS[@]}"; do
    if ! grep -qxF "$r" <<<"$repos"; then disabled+=("$r"); unsynced+=("$r")
    elif ! _portage_repo_synced "$r"; then unsynced+=("$r"); fi
  done
  [[ ${#unsynced[@]} -eq 0 ]] && return 0
  step "enabling the overlays vitrum's packages come from: ${unsynced[*]}"
  local tools=()
  [[ ${#disabled[@]} -gt 0 ]] && ! pkg_installed app-eselect/eselect-repository && tools+=(app-eselect/eselect-repository)
  pkg_installed "dev-vcs/git@git" || tools+=(dev-vcs/git)
  [[ ${#tools[@]} -gt 0 ]] && pkg_install "${tools[@]}"
  [[ ${#disabled[@]} -gt 0 ]] && run sudo eselect repository enable "${disabled[@]}"
  for r in "${unsynced[@]}"; do run sudo env -u ROOT emaint sync -r "$r"; done
  ok "overlays enabled: ${unsynced[*]}"
}

pkg_prepare() { pkg_enable_overlays; pkg_write_portage_files; }

# A USE flag vitrum asks for on a package that is already installed does
# nothing until that package is rebuilt (--noreplace skips it). Rebuild those —
# and only those — whose installed USE lacks one of our flags.
pkg_apply_use() {
  local atom flags f dir dirs pkg iuse todo=()
  while read -r atom flags; do
    [[ -n "$atom" && -n "$flags" ]] || continue
    # The base set (*/*) is for what gets built from now on; rebuilding every
    # installed package for it is emerge -uDN @world's job, not the installer's.
    [[ "$atom" == "*/*" ]] && continue
    # "category/*" covers every installed package of the category.
    mapfile -t dirs < <(compgen -G "${VITRUM_ROOTFS:-}/var/db/pkg/$atom-[0-9]*")
    [[ "$atom" == */\* ]] || dirs=("${dirs[@]:0:1}")
    for dir in "${dirs[@]}"; do
      pkg="${dir%/*}"; pkg="${pkg##*/}/$(sed -E 's/-[0-9][^-]*(-r[0-9]+)?$//' <<<"${dir##*/}")"
      # The package's flags without their +/- defaults, one per line.
      iuse="$(tr ' ' '\n' < "$dir/IUSE" 2>/dev/null | sed 's/^[+-]//')"
      for f in $flags; do
        [[ "$f" == -* ]] && continue
        grep -qxF -- "$f" <<<"$iuse" || continue                        # not a flag of this version
        tr ' ' '\n' < "$dir/USE" 2>/dev/null | grep -qxF -- "$f" || { todo+=("$pkg"); break; }
      done
    done
  done < <(packages_portage_column use)
  [[ ${#todo[@]} -eq 0 ]] && return 0
  step "rebuilding with vitrum's USE flags: ${todo[*]}"
  _emerge --oneshot --changed-use "${todo[@]}" || warn "could not rebuild ${todo[*]} with vitrum's USE flags — see the emerge output above"
}

# /etc/portage/package.{accept_keywords,use,env} may be directories or plain
# files; both layouts are common.
#   directory: our lines in 50-vitrum (rewritten whole each run), plus an empty
#              zz-vitrum-autounmask that sorts last — emerge's autounmask writes
#              dependency changes there, and we never rewrite it.
#   file:      our lines in a "# vitrum begin/end" block, the rest untouched.
_portage_put() {  # _portage_put <package.kind> ; content on stdin
  local base="${VITRUM_ROOTFS:-}/etc/portage/$1" content
  content="$(cat)"
  if [[ -f "$base" ]]; then
    local rest
    rest="$(awk '/^# vitrum begin/{skip=1} !skip{print} /^# vitrum end/{skip=0}' "$base")"
    printf '%s\n# vitrum begin — written by the vitrum installer\n%s\n# vitrum end\n' "$rest" "$content" | sudo_write "$base"
  else
    # Early vitrum builds called the file "vitrum", which sorts after zz-*.
    if [[ -f "$base/vitrum" ]]; then run sudo rm -f "$base/vitrum"; fi
    printf '%s\n' "$content" | sudo_write "$base/50-vitrum"
    if [[ ! -e "$base/zz-vitrum-autounmask" ]]; then
      printf '# emerge --autounmask-write puts dependency changes here (vitrum never rewrites this file)\n' \
        | sudo_write "$base/zz-vitrum-autounmask"
    fi
  fi
}

# A desktop profile (…/desktop, …/desktop/plasma…) turns on what a desktop
# needs; the plain one does not, and then every graphics, sound and toolkit
# package came out without Wayland, OpenGL or ALSA, one surprise at a time.
# Unknown (no profile link) counts as desktop: nothing is added on a guess.
VITRUM_BASE_USE="X wayland opengl vulkan alsa dbus udev"
portage_profile() { readlink -f "${VITRUM_ROOTFS:-}/etc/portage/make.profile" 2>/dev/null; }
portage_desktop_profile() {
  local p; p="$(portage_profile)"
  [[ -z "$p" || "$p" == */desktop || "$p" == */desktop/* ]]
}
_portage_base_use() { portage_desktop_profile || printf '*/* %s\n' "$VITRUM_BASE_USE"; }

pkg_write_portage_files() {
  packages_portage_column keywords | _portage_put package.accept_keywords
  # The base set first: the package lines below it can still take a flag back.
  { _portage_base_use; packages_portage_column use; } | _portage_put package.use
  # The target machines can have no swap; big C++ builds at full -j get OOM-killed.
  printf 'MAKEOPTS="-j%d"\n' "$(half_jobs)" | sudo_write "${VITRUM_ROOTFS:-}/etc/portage/env/vitrum-half-jobs.conf"
  packages_portage_column env      | _portage_put package.env
}
