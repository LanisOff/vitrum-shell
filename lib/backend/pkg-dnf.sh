# shellcheck shell=bash
# Package backend: Fedora dnf (dnf5 on current Fedora). Stages never call dnf
# themselves.
#
# Besides the "a|b" and "@cmd" of every column, the dnf column of
# lib/packages.tsv names where a package comes from when it is not Fedora's:
#   copr:<owner>/<project>:<name>   a COPR repository
#   rpmfusion:<name>                RPM Fusion free
# pkg_prepare enables only the repositories that the rows this run installs
# need, and says which ones on screen: they are third-party, and someone who
# reads the log should not find them there by surprise.

# Fedora 41 and older have no COPR builds left (the COPRs publish 43 and newer
# only), and their Qt is older than the one the shell is written for.
VITRUM_FEDORA_MIN=43

# The packages Fedora ships in a conflicting variant that vitrum cannot use,
# as new=old. Fedora's ffmpeg-free cannot decode H.264 or HEVC, so the live
# wallpaper's poster frame fails on most mp4s. Workstation's tuned-ppd serves
# the power profiles over D-Bus but has no powerprofilesctl, which the shell
# runs. Both have to be swapped, which dnf only does with --allowerasing.
declare -gA _DNF_REPLACES=([ffmpeg]=ffmpeg-free [power-profiles-daemon]=tuned-ppd)

# _dnf_strip <one alternative> — the package name, without the repository prefix.
_dnf_strip() {
  local s="$1"
  case "$s" in
    copr:*)      s="${s#copr:}"; s="${s#*:}" ;;
    rpmfusion:*) s="${s#rpmfusion:}" ;;
  esac
  printf '%s\n' "$s"
}

# _dnf_name <spec> — what gets installed: the first alternative, no @cmd, no prefix.
_dnf_name() { local s="${1%@*}"; _dnf_strip "${s%%|*}"; }

# _dnf_copr <spec> — owner/project of a COPR entry, nothing for any other.
_dnf_copr() {
  local s="${1%@*}"; s="${s%%|*}"
  [[ "$s" == copr:* ]] || return 0
  s="${s#copr:}"; printf '%s\n' "${s%%:*}"
}

# A COPR row counts only when the package came from a COPR. Fedora's own
# matugen (3.x) and quickshell (a 0.2 snapshot) install under the same names
# and are too old for the shell: with them in place the theme silently falls
# back to the preset.
_dnf_from_copr() {
  local v
  v="$(rpm -q --qf '%{VENDOR}' "$1" 2>/dev/null)" || return 1
  [[ "$v" == *Copr* ]]
}

pkg_installed() {
  local spec="$1" alt
  if [[ "$spec" == *@* ]]; then have "${spec##*@}" && return 0; spec="${spec%@*}"; fi
  IFS='|' read -ra alts <<<"$spec"
  for alt in "${alts[@]}"; do
    if [[ "$alt" == copr:* ]]; then _dnf_from_copr "$(_dnf_strip "$alt")" && return 0
    else rpm -q "$(_dnf_strip "$alt")" >/dev/null 2>&1 && return 0; fi
  done
  return 1
}

# _dnf_copr_enabled <owner/project> — dnf copr writes one repo file per project.
_dnf_copr_enabled() {
  local o="${1%%/*}" p="${1#*/}" f
  for f in "${VITRUM_ROOTFS:-}"/etc/yum.repos.d/_copr*:"$o":"$p".repo; do
    [[ -f "$f" ]] && grep -q '^enabled=1' "$f" && return 0
  done
  return 1
}

_dnf_rpmfusion_enabled() { rpm -q "rpmfusion-${1:-free}-release" >/dev/null 2>&1; }

# Every package name the enabled repositories offer, read once per process:
# one repoquery takes seconds, and the packages stage asks about a hundred names.
# A COPR keeps its source packages in the same repository, and a source
# package is nothing dnf install can use: those are left out.
declare -gA _DNF_AVAIL=()
_dnf_avail_load() {
  [[ ${#_DNF_AVAIL[@]} -gt 0 ]] && return 0
  local n a
  while read -r n a; do [[ -n "$n" && "$a" != src ]] && _DNF_AVAIL[$n]=1; done \
    < <(dnf -q repoquery --available --qf '%{name} %{arch}\n' 2>/dev/null)
  _DNF_AVAIL[" loaded"]=1
}

# A dry run enables no repository, so what a COPR or RPM Fusion would offer
# cannot be looked up yet; it is taken as there.
pkg_available() {
  local spec="${1%@*}" name copr
  spec="${spec%%|*}"; name="$(_dnf_strip "$spec")"; copr="$(_dnf_copr "$spec")"
  if [[ "$DRY_RUN" == "1" ]]; then
    [[ -n "$copr" ]] && ! _dnf_copr_enabled "$copr" && return 0
    [[ "$spec" == rpmfusion:* ]] && ! _dnf_rpmfusion_enabled free && return 0
  fi
  _dnf_avail_load
  [[ -n "${_DNF_AVAIL[$name]+x}" ]]
}

# _dnf_os <key> — a value from os-release.
_dnf_os() {
  awk -F= -v k="$1" '$1 == k { gsub(/"/, "", $2); print $2 }' "${VITRUM_ROOTFS:-}/etc/os-release" 2>/dev/null
}

_dnf_check_release() {
  local id ver
  id="$(_dnf_os ID)"; ver="$(_dnf_os VERSION_ID)"
  if [[ "$id" != fedora ]]; then
    warn '%s is not Fedora: vitrum is tested on Fedora %s and newer, and its COPR repositories may have nothing for it' "${id:-this system}" "$VITRUM_FEDORA_MIN"
    return 0
  fi
  [[ "$ver" =~ ^[0-9]+$ ]] || return 0
  (( ver >= VITRUM_FEDORA_MIN )) \
    || die 'Fedora %s is too old for vitrum: it needs Fedora %s or newer (the COPR repositories it uses build for no older release, and the shell wants Qt 6.11)' "$ver" "$VITRUM_FEDORA_MIN"
}

# dnf copr is a plugin: dnf5-plugins on dnf5, dnf-plugins-core on dnf4.
_dnf_copr_plugin() {
  local plugin=dnf-plugins-core
  { have dnf5 || dnf --version 2>/dev/null | grep -q dnf5; } && plugin=dnf5-plugins
  rpm -q "$plugin" >/dev/null 2>&1 && return 0
  step "installing $plugin (it provides dnf copr)"
  run sudo dnf install -y "$plugin"
}

# _dnf_enable_rpmfusion free [nonfree] — the release packages, which carry the
# repository files and keys, straight from RPM Fusion's mirror.
_dnf_enable_rpmfusion() {
  local ver k urls=() which=()
  ver="$(rpm -E %fedora 2>/dev/null)"
  [[ "$ver" =~ ^[0-9]+$ ]] || ver="$(_dnf_os VERSION_ID)"
  for k in "$@"; do
    _dnf_rpmfusion_enabled "$k" && continue
    urls+=("https://mirrors.rpmfusion.org/$k/fedora/rpmfusion-$k-release-$ver.noarch.rpm"); which+=("$k")
  done
  [[ ${#urls[@]} -eq 0 ]] && return 0
  local why="ffmpeg with H.264 and HEVC"
  [[ " ${which[*]} " == *" nonfree "* ]] && why+="; nonfree for the NVIDIA GPU"
  step "enabling the third-party repository RPM Fusion (${which[*]}): $why"
  run sudo dnf install -y "${urls[@]}"
  ok "RPM Fusion enabled: ${which[*]}"
}

# The COPRs vitrum enabled itself, one owner/project per line. Only those get
# limited to vitrum's packages: one the user had enabled before (a Hyprland
# user's sdegler/hyprland, danklinux for DMS) is theirs, whole, and stays so.
_dnf_ours_file() { printf '%s/coprs-enabled\n' "${VITRUM_STATE:-$HOME/.local/share/vitrum}"; }
_dnf_copr_ours() { grep -qxF "$1" "$(_dnf_ours_file)" 2>/dev/null; }
_dnf_copr_record() {
  local f; f="$(_dnf_ours_file)"
  _dnf_copr_ours "$1" && return 0
  mkdir -p "$(dirname "$f")" && printf '%s\n' "$1" >> "$f"
}

_dnf_enable_coprs() {
  local c todo=()
  for c in "$@"; do _dnf_copr_enabled "$c" || todo+=("$c"); done
  [[ ${#todo[@]} -eq 0 ]] && return 0
  _dnf_copr_plugin
  step "enabling third-party COPR repositories, each for the packages named below only: ${todo[*]}"
  # -y also accepts each COPR's signing key, imported on its first install.
  for c in "${todo[@]}"; do
    run sudo dnf copr enable -y "$c"
    [[ "$DRY_RUN" == "1" ]] || _dnf_copr_record "$c"
  done
  ok "COPR repositories enabled: ${todo[*]}"
}

# dnf5's id of a COPR repository.
_dnf_copr_id() { printf 'copr:copr.fedorainfracloud.org:%s:%s\n' "${1%%/*}" "${1#*/}"; }

# Every COPR the table names, one per line.
_dnf_table_coprs() {
  awk -F'\t' '!/^#/ && NF { n = split($8, a, "|"); for (i = 1; i <= n; i++) if (a[i] ~ /^copr:/) { c = a[i]; sub(/^copr:/, "", c); sub(/:.*/, "", c); print c } }' "$_PKG_TABLE" | sort -u
}

# _dnf_copr_table_names <owner/project> — what the table takes from it, all
# rows (not only this run's), so a part chosen later still finds its package.
_dnf_copr_table_names() {
  awk -F'\t' -v c="copr:$1:" '!/^#/ && NF { n = split($8, a, "|"); for (i = 1; i <= n; i++) { x = a[i]; sub(/@.*/, "", x); if (index(x, c) == 1) print substr(x, length(c) + 1) } }' "$_PKG_TABLE" | sort -u
}

# _dnf_repo_includepkgs <repo id> — its includepkgs as dnf reads it: the repo
# file first, then dnf5's overrides (config-manager setopt writes there).
_dnf_repo_includepkgs() {
  local r="${VITRUM_ROOTFS:-}" files=()
  mapfile -t files < <(compgen -G "$r/etc/yum.repos.d/*.repo"; compgen -G "$r/etc/dnf/repos.override.d/*.repo")
  [[ ${#files[@]} -gt 0 ]] || return 0
  awk -v id="[$1]" '/^\[/ { on = ($0 == id) } on && /^includepkgs[[:space:]]*=/ { v = $0; sub(/^[^=]*=[[:space:]]*/, "", v); last = v } END { print last }' "${files[@]}"
}

_dnf_is_dnf5() { have dnf5 || dnf --version 2>/dev/null | grep -q dnf5; }

# _dnf_copr_deps <owner/project> <name>... — what those packages need that
# only this COPR has (quickshell's cpptrace: Fedora has none). Asked of the
# COPR with no filter on it, beside the repositories that are not COPRs.
# Fails when dnf does: an empty answer then means "unknown", not "nothing".
_dnf_copr_deps() {
  local id r out repos=(); id="$(_dnf_copr_id "$1")"; shift
  while read -r r _; do [[ -n "$r" && "$r" != copr:* ]] && repos+=("--repo=$r"); done \
    < <(dnf -q repo list --enabled 2>/dev/null | tail -n +2)
  if _dnf_is_dnf5; then
    out="$(dnf -q repoquery --setopt="$id.includepkgs=" "${repos[@]}" "--repo=$id" --providers-of=requires --recursive \
      --qf '%{name} %{repoid}\n' "$@" 2>/dev/null)" || return 1
  else
    out="$(dnf -q repoquery --setopt="$id.includepkgs=" "${repos[@]}" "--repo=$id" --requires --resolve --recursive \
      --qf '%{name} %{repoid}' "$@" 2>/dev/null)" || return 1
  fi
  awk -v id="$id" '$2 == id { print $1 }' <<<"$out" | sort -u
}

# _dnf_copr_installed <owner/project> — what is installed from it now: a limit
# never strands a package that already came from the COPR.
_dnf_copr_installed() {
  local id out; id="$(_dnf_copr_id "$1")"
  out="$(dnf -q repoquery --installed --qf '%{name} %{from_repo}\n' 2>/dev/null)" || return 1
  awk -v id="$id" '$2 == id { print $1 }' <<<"$out" | sort -u
}

# _dnf_copr_limit <owner/project> — a COPR vitrum enabled serves the packages
# the table takes from it, their dependencies only it has, and what is already
# installed from it; nothing else of it replaces Fedora's builds (danklinux
# also carries cliphist, cava, qt6ct-kde…; the Hyprland COPRs whole library
# stacks), now or at any later dnf upgrade. The dependencies are asked again
# every run, as a COPR build can gain one; when that cannot be asked, the
# list as it is stays.
_dnf_copr_limit() {
  local c="$1" id cur want=() deps inst list
  id="$(_dnf_copr_id "$c")"
  mapfile -t want < <(_dnf_copr_table_names "$c")
  [[ ${#want[@]} -gt 0 ]] || return 0
  if ! _dnf_copr_enabled "$c"; then
    [[ "$DRY_RUN" == "1" ]] && dim "would take only ${want[*]} (and what they need from it) from $c"
    return 0
  fi
  if ! _dnf_copr_ours "$c"; then
    info "COPR $c: you had it enabled before vitrum — left as it is (vitrum takes ${want[*]} from it)"
    return 0
  fi
  cur="$(_dnf_repo_includepkgs "$id")"
  if ! deps="$(_dnf_copr_deps "$c" "${want[@]}")" || ! inst="$(_dnf_copr_installed "$c")"; then
    warn 'COPR %s: could not ask dnf what its packages need — its package list stays as it is (%s)' "$c" "${cur:-not limited yet}"
    return 0
  fi
  list="$(printf '%s\n' "${want[@]}" "$deps" "$inst" | awk 'NF && !seen[$0]++' | paste -sd, -)"
  # The same set in another order is no change.
  [[ "$(tr ',' '\n' <<<"$list" | sort -u)" == "$(tr ',' '\n' <<<"$cur" | awk 'NF' | sort -u)" ]] && return 0
  info "COPR $c: only ${list//,/, } come from it"
  if _dnf_is_dnf5; then
    run sudo dnf config-manager setopt "$id.includepkgs=$list"
  else
    _dnf4_repo_set "$c" includepkgs "$list"
  fi
}

# dnf4 has no setopt that persists: the line goes into the COPR's repo file.
_dnf4_repo_set() {  # <owner/project> <key> <value>
  local f id; id="$(_dnf_copr_id "$1")"
  f="$(compgen -G "${VITRUM_ROOTFS:-}/etc/yum.repos.d/_copr*:${1%%/*}:${1#*/}.repo" | head -n 1)"
  [[ -n "$f" ]] || return 0
  awk -v id="[$id]" -v k="$2" -v v="$3" '
    /^\[/ { if (on && !done) { print k "=" v; done = 1 } on = ($0 == id) }
    on && index($0, k "=") == 1 { if (!done) print k "=" v; done = 1; next }
    { print }
    END { if (on && !done) print k "=" v }' "$f" | sudo_write "$f"
}

# The repositories the rows of this run need, for what is not installed yet.
pkg_prepare() {
  _dnf_check_release
  local needs=() specs=() s c coprs=() fusion=()
  mapfile -t needs < <(_package_needs)
  mapfile -t specs < <(packages_for "${needs[@]}" 2>/dev/null)
  for s in "${specs[@]}"; do
    [[ -n "$s" ]] || continue
    pkg_installed "$s" && continue
    c="$(_dnf_copr "$s")"
    if [[ -n "$c" ]] && ! printf '%s\n' "${coprs[@]}" | grep -qxF "$c"; then coprs+=("$c"); fi
    [[ "${s%%|*}" == rpmfusion:* ]] && fusion=(free)
  done
  # nonfree is the NVIDIA driver's repository; it needs free beside it.
  if printf '%s\n' "${needs[@]}" | grep -qx nvidia; then fusion=(free nonfree); fi
  [[ ${#fusion[@]} -gt 0 ]] && _dnf_enable_rpmfusion "${fusion[@]}"
  [[ ${#coprs[@]} -gt 0 ]] && _dnf_enable_coprs "${coprs[@]}"
  # Every COPR of the table that is enabled, this run's and an earlier one's.
  for c in $(_dnf_table_coprs); do _dnf_copr_limit "$c"; done
  return 0
}

pkg_install() {
  [[ $# -eq 0 ]] && return 0
  local p n old plain=() swapped=() upgrade=()
  for p in "$@"; do
    n="$(_dnf_name "$p")"
    if [[ -n "${_DNF_REPLACES[$n]+x}" ]]; then swapped+=("$n"); continue; fi
    plain+=("$n")
    # Installed, but not from the COPR the row names: the COPR's newer build replaces it.
    [[ -n "$(_dnf_copr "$p")" ]] && rpm -q "$n" >/dev/null 2>&1 && upgrade+=("$n")
  done
  # The swaps first: the batch below then links against them (mpv and
  # gpu-screen-recorder take whichever libavcodec is installed).
  for n in "${swapped[@]}"; do
    old="${_DNF_REPLACES[$n]}"
    if rpm -q "$old" >/dev/null 2>&1; then
      step "replacing $old with $n"
      _dnf_erasing sudo dnf swap -y --allowerasing "$old" "$n"
    else
      _dnf_erasing sudo dnf install -y --allowerasing "$n"
    fi
    # tuned-ppd goes, tuned itself stays: two daemons would set the CPU's
    # power policy against each other.
    if [[ "$n" == power-profiles-daemon ]] && systemctl -q is-enabled tuned.service 2>/dev/null; then
      step "turning tuned off: power-profiles-daemon sets the power profile now"
      run_ok sudo systemctl disable --now tuned.service || warn 'could not turn off %s — run: sudo systemctl disable --now %s' tuned.service tuned.service
    fi
  done
  [[ ${#plain[@]} -gt 0 ]] && run sudo dnf install -y "${plain[@]}"
  if [[ ${#upgrade[@]} -gt 0 ]]; then
    step "replacing Fedora's builds with the COPR ones: ${upgrade[*]}"
    run sudo dnf upgrade -y "${upgrade[@]}"
  fi
  return 0
}

# _dnf_erasing <command> — run it and say what --allowerasing took away with it.
_dnf_erasing() {
  if [[ "$DRY_RUN" == "1" ]]; then run "$@"; return 0; fi
  local before gone
  before="$(rpm -qa --qf '%{name}\n' 2>/dev/null | sort -u)"
  run "$@"
  gone="$(comm -23 <(printf '%s\n' "$before") <(rpm -qa --qf '%{name}\n' 2>/dev/null | sort -u) | paste -sd' ' -)"
  [[ -z "$gone" ]] || info "dnf removed to make room: $gone"
}

pkg_apply_use() { :; }

pkg_write_portage_files() { :; }
