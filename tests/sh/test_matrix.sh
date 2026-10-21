# shellcheck shell=bash disable=SC1090,SC1091,SC2031
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
  # Fedora and Void: os-release says which, nothing is installed, the
  # repositories offer every name of the table's column.
  case "$1" in
    dnf)
      mkdir -p "$rootfs/etc"; printf 'ID=fedora\nVERSION_ID=44\n' > "$rootfs/etc/os-release"
      stub rpm "echo \"rpm \$*\" >> \"\$CALLS\"; [[ \"\$1\" == -E ]] && echo 44; [[ \"\$1\" == -E ]]"
      stub dnf "echo \"dnf \$*\" >> \"\$CALLS\"; [[ \"\$*\" == *repoquery* ]] && awk -F'\\t' '!/^#/ && NF { n = \$8; sub(/@.*/, \"\", n); sub(/[|].*/, \"\", n); sub(/^copr:[^:]*:/, \"\", n); sub(/^rpmfusion:/, \"\", n); print n }' \"$VITRUM_DIR/lib/packages.tsv\"; exit 0" ;;
    xbps-install)
      mkdir -p "$rootfs/etc"; printf 'ID=void\n' > "$rootfs/etc/os-release"
      stub xbps-query "[[ \"\$1\" == -R ]]"
      stub xbps-uhelper "echo x86_64" ;;
  esac
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
test_matrix_dnf_systemd() {
  _world dnf systemd
  _run || { tail -30 "$HOME/../matrix-out.$$"; return 1; }
  _assert_clean_home
  out="$(cat "$HOME/../matrix-out.$$")"
  assert_contains "$out" "packages: dnf, init: systemd"
  assert_contains "$out" "would run: sudo dnf copr enable -y errornointernet/quickshell"
  assert_contains "$out" "rpmfusion-free-release-44"
  assert_contains "$out" "would run: sudo dnf install -y"
  ! grep -q "copr:" "$CALLS"
}
test_matrix_xbps_runit() {
  _world xbps-install none
  _run || { tail -30 "$HOME/../matrix-out.$$"; return 1; }
  _assert_clean_home
  out="$(cat "$HOME/../matrix-out.$$")"
  assert_contains "$out" "packages: xbps, init: runit"
  assert_contains "$out" "would run: sudo xbps-install -Sy"
  assert_contains "$out" "would run: sudo xbps-install -y"
  assert_contains "$out" "would fetch jetbrains-mono-nerd"
  ! grep -q "nerd-fonts-ttf" <<<"$out"
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
# Every asset in place: prereqs_check under --only niri would otherwise fetch
# the fonts from the network, which a test must never wait on.
_assets_in_place() {
  ( source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/assets.sh"
    local a _a_url _a_sum _a_kind _a_dest
    mkdir -p "$VITRUM_STATE/assets"
    for a in $(asset_names); do
      _asset_row "$a"
      [[ "$_a_dest" == "$HOME"/* ]] || continue   # a system path is not wanted on Gentoo
      mkdir -p "$(dirname "$_a_dest")"; touch "$_a_dest"
      printf '%s' "$_a_sum" > "$VITRUM_STATE/assets/$a.sha256"
    done )
}
test_failed_stage_hint_uses_stage_key() {
  _world emerge openrc
  _assets_in_place
  stub curl 'exit 1'; stub wget 'exit 1'  # and nothing reaches the network
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
