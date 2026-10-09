# shellcheck shell=bash disable=SC1090,SC1091
# install.sh --dry-run on each supported combination, against a stub world.
# Expect: exit 0, nothing written under HOME, the backend's verbs used.
_world() {  # _world <pkg> <init>
  PATH="$STUBS:$(dirname "$BASH"):/usr/bin:/bin:/usr/sbin:/sbin"
  stub uname "echo Linux"
  for c in sudo systemctl rc-update rc-service fc-cache lspci portageq equery python3 qs; do
    stub "$c" "echo \"$c \$*\" >> \"\$CALLS\"; exit 0"
  done
  stub "$1" "echo \"$1 \$*\" >> \"\$CALLS\"; case \"\$1\" in -Si) exit 0;; esac; exit 1"   # nothing installed, everything available
  stub portageq "echo \"portageq \$*\" >> \"\$CALLS\"; echo x/available-1"
  export CALLS; CALLS="$(mktemp)"
  local rootfs; rootfs="$(mktemp -d)"
  case "$2" in openrc) mkdir -p "$rootfs/run/openrc";; systemd) mkdir -p "$rootfs/run/systemd/system";; esac
  export VITRUM_ROOTFS="$rootfs"
}
_run() { ( cd "$VITRUM_DIR" && ./install.sh --dry-run --yes --skip niri ) > "$HOME/../matrix-out.$$" 2>&1; }
_assert_clean_home() {
  local left; left="$(find "$HOME" -type f 2>/dev/null)"
  [[ -z "$left" ]] || { echo "dry-run wrote files:"; echo "$left"; return 1; }
}

test_matrix_portage_openrc() {
  _world emerge openrc
  _run || { tail -30 "$HOME/../matrix-out.$$"; return 1; }
  _assert_clean_home
  assert_contains "$(cat "$HOME/../matrix-out.$$")" "packages: portage, init: openrc"
}
test_matrix_portage_systemd() {
  _world emerge systemd
  _run || { tail -30 "$HOME/../matrix-out.$$"; return 1; }
  _assert_clean_home
  assert_contains "$(cat "$HOME/../matrix-out.$$")" "packages: portage, init: systemd"
}
test_matrix_pacman_systemd() {
  _world pacman systemd
  _run || { tail -30 "$HOME/../matrix-out.$$"; return 1; }
  _assert_clean_home
  assert_contains "$(cat "$HOME/../matrix-out.$$")" "packages: pacman, init: systemd"
}
test_matrix_pacman_openrc_refused() {
  _world pacman openrc
  ! _run
  assert_contains "$(cat "$HOME/../matrix-out.$$")" "unsupported system"
}
test_no_stage_calls_removed_or_distro_helpers() {
  # Stages go through the backends; these names must not appear outside lib/backend.
  hits="$(grep -nE '\b(pac_install|pac_install_first|aur_install|enable_user_unit|ensure_aur_helper)\b|^\s*[^#]*\b(pacman|emerge|rc-update|rc-service|systemctl) ' "$VITRUM_DIR"/lib/stages/*.sh | grep -v 'runtime-script' || true)"
  [[ -z "$hits" ]] || { echo "$hits"; return 1; }
}
test_unknown_stage_name_is_rejected() {
  _world emerge openrc
  out="$( (cd "$VITRUM_DIR" && ./install.sh --dry-run --yes --only nosuchstage) 2>&1 )" && { echo "should fail"; return 1; }
  assert_contains "$out" "unknown stage: nosuchstage"
}
test_failed_stage_hint_uses_stage_key() {
  _world emerge openrc
  stub git 'exit 1'                       # niri fetch fails
  stub cargo 'exit 1'
  out="$( (cd "$VITRUM_DIR" && ./install.sh --yes --only niri) 2>&1 )" && { echo "should fail"; return 1; }
  assert_contains "$out" './install.sh --from niri'
}
test_component_choices_are_recorded() {
  # An update repeats the first install's answers only if they were saved.
  _world emerge openrc
  ( cd "$VITRUM_DIR" && ./install.sh --dry-run --yes --skip niri --no-tmux ) > "$HOME/../matrix-out.$$" 2>&1 || { tail -20 "$HOME/../matrix-out.$$"; return 1; }
  assert_contains "$(cat "$HOME/../matrix-out.$$")" "would record component choices"
}
