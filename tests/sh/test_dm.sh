# shellcheck shell=bash disable=SC1090,SC1091,SC2016,SC2329
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
# The confirmation screen asks, before any stage runs; dm_use_sddm only reads
# REPLACE_DM, also when there is a terminal to ask on.
test_other_dm_kept_without_replace_dm_and_nothing_asked() {
  _dm_world openrc lightdm; export ASSUME_YES=0 REPLACE_DM=0
  confirm() { echo asked >> "$HOME/asked"; return 0; }
  dm_use_sddm 2>/dev/null
  [[ ! -e "$HOME/asked" ]] || { echo "dm_use_sddm asked"; return 1; }
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/conf.d/display-manager")" 'DISPLAYMANAGER="lightdm"'
}
test_replace_dm_without_yes() {
  _dm_world openrc lightdm; export ASSUME_YES=0 REPLACE_DM=1
  confirm() { echo asked >> "$HOME/asked"; return 1; }
  dm_use_sddm >/dev/null 2>&1
  [[ ! -e "$HOME/asked" ]] || { echo "dm_use_sddm asked"; return 1; }
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/conf.d/display-manager")" 'DISPLAYMANAGER="sddm"'
}

# runit: the login screen is whichever is linked into the runlevel.
_runit_dm() {  # _runit_dm [running] [current dm]
  stub sudo '"$@"'; stub sv; stub sleep
  export VITRUM_ROOTFS="$HOME/rootfs" VITRUM_SYSROOT="$HOME/rootfs" INIT_BACKEND=runit
  local d
  for d in sddm gdm lightdm; do mkdir -p "$VITRUM_ROOTFS/etc/sv/$d"; done
  mkdir -p "$VITRUM_ROOTFS/etc/runit/runsvdir/default"; ln -s default "$VITRUM_ROOTFS/etc/runit/runsvdir/current"
  if [[ "${1:-}" == running ]]; then
    mkdir -p "$VITRUM_ROOTFS/run/runit/runsvdir" "$VITRUM_ROOTFS/var"
    ln -s ../etc/runit/runsvdir/current "$VITRUM_ROOTFS/var/service"
  fi
  [[ -n "${2:-}" ]] && ln -s "/etc/sv/$2" "$VITRUM_ROOTFS/etc/runit/runsvdir/default/$2"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-runit.sh"; source "$VITRUM_DIR/lib/dm.sh"
}
test_runit_current_dm_detected() {
  _runit_dm running lightdm
  assert_eq "$(dm_current)" lightdm
  _runit_dm "" gdm 2>/dev/null || true
}
test_runit_no_dm_is_empty() {
  _runit_dm running
  assert_eq "$(dm_current)" ""
}
# Linked now, SDDM would start on top of the running install.
test_runit_sddm_waits_for_the_next_boot() {
  _runit_dm running; export ASSUME_YES=1
  dm_use_sddm >/dev/null 2>&1
  [[ ! -e "$VITRUM_ROOTFS/var/service/sddm" ]]
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/rc.local")" "ln -sfn /etc/sv/sddm /etc/runit/runsvdir/current/sddm"
  assert_eq "$(dm_current)" sddm      # what the next boot starts
}
test_runit_other_dm_kept_under_yes() {
  _runit_dm running gdm; export ASSUME_YES=1
  dm_use_sddm 2>/dev/null
  [[ -L "$VITRUM_ROOTFS/var/service/gdm" && ! -e "$VITRUM_ROOTFS/etc/rc.local" ]]
}
test_runit_replace_dm_unlinks_the_other_at_the_next_boot() {
  _runit_dm running gdm; export ASSUME_YES=1 REPLACE_DM=1
  dm_use_sddm >/dev/null 2>&1
  rc="$(cat "$VITRUM_ROOTFS/etc/rc.local")"
  assert_contains "$rc" "rm -f /etc/runit/runsvdir/current/gdm"
  assert_contains "$rc" "ln -sfn /etc/sv/sddm /etc/runit/runsvdir/current/sddm"
  [[ -L "$VITRUM_ROOTFS/var/service/gdm" ]]     # the running session is left alone
  assert_eq "$(cat "$VITRUM_STATE/previous-dm")" gdm
  assert_eq "$(dm_current)" sddm
}
# In a chroot nothing runs: the links change at once.
test_runit_not_running_links_directly() {
  _runit_dm "" gdm; export ASSUME_YES=1 REPLACE_DM=1
  dm_use_sddm >/dev/null 2>&1
  d="$VITRUM_ROOTFS/etc/runit/runsvdir/default"
  [[ -L "$d/sddm" && ! -e "$d/gdm" && ! -e "$VITRUM_ROOTFS/etc/rc.local" ]]
}
# uninstall.sh before the reboot: gdm back, and the queued SDDM switch cancelled.
test_runit_restore_before_the_reboot_cancels_the_queued_switch() {
  _runit_dm running gdm; export ASSUME_YES=1 REPLACE_DM=1
  dm_use_sddm >/dev/null 2>&1
  svc_enable_display_manager gdm force >/dev/null 2>&1
  rc="$(cat "$VITRUM_ROOTFS/etc/rc.local")"
  ! grep -q "ln -sfn /etc/sv/sddm" <<<"$rc"
  ! grep -q "rm -f /etc/runit/runsvdir/current/gdm" <<<"$rc"
  assert_eq "$(dm_current)" gdm
}
