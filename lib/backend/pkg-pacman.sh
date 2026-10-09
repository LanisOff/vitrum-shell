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

_aur_helper() { if have paru; then echo paru; elif have yay; then echo yay; fi; }

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
    if [[ -z "$h" ]]; then _aur_bootstrap; h=paru; fi
    run "$h" -Syu --needed --noconfirm "${aur[@]}"
  fi
}

# No AUR helper: build paru-bin from the AUR, the way the AUR asks to be used.
_aur_bootstrap() {
  step "no AUR helper — building paru-bin"
  local dir="$BUILD_DIR/paru-bin"
  run rm -rf "$dir"
  run git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$dir"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would run: makepkg -si in $dir"; return 0; fi
  ( cd "$dir" && makepkg -si --noconfirm ) || die "could not build paru-bin — install paru or yay and re-run"
}

# Nothing to prepare: pkg_install syncs and upgrades in one transaction.
pkg_prepare() { :; }

pkg_apply_use() { :; }

pkg_write_portage_files() { :; }
