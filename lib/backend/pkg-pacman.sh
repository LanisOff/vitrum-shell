# shellcheck shell=bash
# Package backend: Arch pacman, with an AUR helper for names written aur:<name>
# in lib/packages.tsv. Stages never call pacman themselves.

# "name@cmd" also counts as installed when cmd exists (see pkg-portage.sh).
pkg_installed() {
  local spec="$1"
  if [[ "$spec" == *@* ]]; then have "${spec##*@}" && return 0; spec="${spec%@*}"; fi
  pacman -Qq "${spec#aur:}" >/dev/null 2>&1
}

pkg_available() { [[ "$1" == aur:* ]] || pacman -Si "$1" >/dev/null 2>&1; }

# A helper that starts. paru-bin built for an older pacman is installed but
# dies on the spot ("libalpm.so.15: cannot open") after a pacman upgrade —
# that counts as no helper.
_helper_ok() { have "$1" && "$1" --version >/dev/null 2>&1; }
_aur_helper() { if _helper_ok paru; then echo paru; elif _helper_ok yay; then echo yay; fi; }
AUR_HELPER=""

pkg_install() {
  local repo=() aur=() p h
  for p in "$@"; do
    p="${p%@*}"
    if [[ "$p" == aur:* ]]; then aur+=("${p#aur:}"); else repo+=("$p"); fi
  done
  # -Syu, never a bare -Sy: syncing the databases without upgrading is Arch's
  # classic partial upgrade, which breaks systems.
  if [[ ${#repo[@]} -gt 0 ]]; then run sudo pacman -Syu --needed --noconfirm "${repo[@]}"; fi
  if [[ ${#aur[@]} -gt 0 ]]; then
    h="$(_aur_helper)"
    if [[ -z "$h" ]]; then _aur_bootstrap; h="$AUR_HELPER"; fi
    run "$h" -Syu --needed --noconfirm "${aur[@]}"
  fi
}

# No working AUR helper. A broken prebuilt one goes first (it would conflict
# with its replacement). Then the distribution's own build if it ships one
# (CachyOS, EndeavourOS, Manjaro), linked against its pacman; else paru built
# from source in the AUR — never paru-bin, which breaks whenever pacman's
# library moves on. Sets AUR_HELPER.
_aur_bootstrap() {
  local h
  for h in paru yay; do
    if pacman -Qq "$h-bin" >/dev/null 2>&1 && ! _helper_ok "$h"; then
      step "$h-bin does not start (built for an older pacman) — replacing it"
      run sudo pacman -Rdd --noconfirm "$h-bin"
    fi
  done
  for h in paru yay; do
    if pacman -Si "$h" >/dev/null 2>&1; then
      step "AUR helper: $h from the repositories"
      run sudo pacman -S --needed --noconfirm "$h"
      AUR_HELPER="$h"; return 0
    fi
  done
  step "no AUR helper — building paru"
  local dir="$BUILD_DIR/paru"
  run rm -rf "$dir"
  run git clone --depth 1 https://aur.archlinux.org/paru.git "$dir"
  AUR_HELPER=paru
  if [[ "$DRY_RUN" == "1" ]]; then dim "would run: makepkg -si in $dir"; return 0; fi
  ( cd "$dir" && makepkg -si --noconfirm ) || die "could not build paru — install paru or yay and re-run"
}

# Nothing to prepare: pkg_install syncs and upgrades in one transaction.
pkg_prepare() { :; }

pkg_apply_use() { :; }

pkg_write_portage_files() { :; }
