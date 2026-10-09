# shellcheck shell=bash disable=SC1090,SC1091
_dm_world() {  # _dm_world <init> [current dm]
  stub sudo '"$@"'; export VITRUM_ROOTFS="$HOME/rootfs" VITRUM_SYSROOT="$HOME/rootfs"
  export INIT_BACKEND="$1"
  stub rc-update 'echo "rc-update $*" >> "$HOME/calls"; [[ "$1" == show ]] && cat "$HOME/runlevel" 2>/dev/null; exit 0'
  stub systemctl 'echo "systemctl $*" >> "$HOME/calls"; exit 0'
  mkdir -p "$VITRUM_ROOTFS/etc/conf.d" "$VITRUM_ROOTFS/etc/systemd/system"
  if [[ "$1" == openrc && -n "${2:-}" ]]; then
    printf 'CHECKVT=7\nDISPLAYMANAGER="%s"\n' "$2" > "$VITRUM_ROOTFS/etc/conf.d/display-manager"
    echo "      display-manager | default" > "$HOME/runlevel"
  fi
  if [[ "$1" == systemd && -n "${2:-}" ]]; then
    ln -s "/usr/lib/systemd/system/$2.service" "$VITRUM_ROOTFS/etc/systemd/system/display-manager.service"
  fi
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-$1.sh"; source "$VITRUM_DIR/lib/dm.sh"
}
test_openrc_current_dm_detected() {
  _dm_world openrc lightdm
  assert_eq "$(dm_current)" lightdm
}
test_systemd_current_dm_detected() {
  _dm_world systemd gdm
  assert_eq "$(dm_current)" gdm
}
test_other_dm_kept_under_yes() {
  _dm_world openrc lightdm; export ASSUME_YES=1
  dm_use_sddm 2>/dev/null
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/conf.d/display-manager")" 'DISPLAYMANAGER="lightdm"'
  [[ ! -e "$VITRUM_STATE/previous-dm" ]]
}
test_replace_flag_replaces_and_records() {
  _dm_world openrc lightdm; export ASSUME_YES=1 REPLACE_DM=1
  dm_use_sddm >/dev/null 2>&1
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/conf.d/display-manager")" 'DISPLAYMANAGER="sddm"'
  assert_eq "$(cat "$VITRUM_STATE/previous-dm")" lightdm
}
test_no_dm_enables_sddm_without_asking() {
  _dm_world openrc; export ASSUME_YES=1
  dm_use_sddm >/dev/null 2>&1
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/conf.d/display-manager")" 'DISPLAYMANAGER="sddm"'
}
test_systemd_never_forces_without_consent() {
  _dm_world systemd gdm; export ASSUME_YES=1
  dm_use_sddm 2>/dev/null
  ! grep -q -- "--force" "$HOME/calls" 2>/dev/null
}
test_already_sddm_is_noop() {
  _dm_world openrc sddm; export ASSUME_YES=1
  dm_use_sddm >/dev/null 2>&1
  [[ ! -e "$VITRUM_STATE/previous-dm" ]]
}
test_uninstall_restores_previous_dm() {
  _dm_world openrc sddm
  stub uname 'echo Linux'; stub emerge; mkdir -p "$VITRUM_ROOTFS/run/openrc"
  mkdir -p "$VITRUM_STATE"; echo lightdm > "$VITRUM_STATE/previous-dm"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >/dev/null 2>&1 || { ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) 2>&1 | tail -5; return 1; }
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/conf.d/display-manager")" 'DISPLAYMANAGER="lightdm"'
}
