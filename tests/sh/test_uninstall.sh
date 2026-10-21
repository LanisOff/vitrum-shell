# shellcheck shell=bash disable=SC1090,SC1091
_installed_world() {
  stub sudo '"$@"'; stub uname 'echo Linux'
  export VITRUM_SYSROOT="$HOME/sys"
  mkdir -p "$VITRUM_SYSROOT/usr/local/bin" "$VITRUM_SYSROOT/usr/local/share/wayland-sessions" "$HOME/.local/bin" "$XDG_CONFIG_HOME/quickshell/vitrum" "$XDG_CONFIG_HOME/vitrum/niri/generated" "$XDG_CONFIG_HOME/fontconfig/conf.d" "$XDG_DATA_HOME/vitrum"
  touch "$VITRUM_SYSROOT/usr/local/bin/niri" "$VITRUM_SYSROOT/usr/local/bin/vitrum-session" "$VITRUM_SYSROOT/usr/local/share/wayland-sessions/niri.desktop"
  touch "$HOME/.local/bin/vitrum-shell" "$HOME/.local/bin/vitrum-startup" "$HOME/.local/bin/vitrum-ipc" "$XDG_CONFIG_HOME/quickshell/vitrum/shell.qml" "$XDG_CONFIG_HOME/vitrum/niri/config.kdl" "$XDG_CONFIG_HOME/fontconfig/conf.d/50-vitrum.conf"
  echo '{"mine":1}' > "$XDG_CONFIG_HOME/vitrum/settings.json"
  # the original of a file we replaced
  local b="$XDG_DATA_HOME/vitrum/originals"
  mkdir -p "$b/.config/kitty"; echo original > "$b/.config/kitty/kitty.conf"; printf 'saved .config/kitty/kitty.conf\n' > "$b/.manifest"
  mkdir -p "$XDG_CONFIG_HOME/kitty"; echo ours > "$XDG_CONFIG_HOME/kitty/kitty.conf"
}
test_uninstall_removes_and_restores() {
  _installed_world
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >/dev/null 2>&1 || { ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) 2>&1 | tail -20; return 1; }
  [[ ! -e "$VITRUM_SYSROOT/usr/local/bin/niri" && ! -e "$VITRUM_SYSROOT/usr/local/share/wayland-sessions/niri.desktop" ]]
  [[ ! -e "$HOME/.local/bin/vitrum-shell" && ! -e "$XDG_CONFIG_HOME/quickshell/vitrum" && ! -e "$XDG_CONFIG_HOME/vitrum/niri" ]]
  assert_eq "$(cat "$XDG_CONFIG_HOME/kitty/kitty.conf")" original
  assert_eq "$(cat "$XDG_CONFIG_HOME/vitrum/settings.json")" '{"mine":1}'   # settings kept without --purge
}
test_uninstall_dry_run_changes_nothing() {
  _installed_world
  before="$(find "$HOME" -type f | sort | xargs cat | cksum)"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --dry-run --yes ) >/dev/null 2>&1
  assert_eq "$(find "$HOME" -type f | sort | xargs cat | cksum)" "$before"
}
test_uninstall_purge_removes_settings() {
  _installed_world
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes --purge ) >/dev/null 2>&1
  [[ ! -e "$XDG_CONFIG_HOME/vitrum" ]]
}
test_uninstall_keeps_portage_keywords_unless_purge() {
  _installed_world
  mkdir -p "$VITRUM_SYSROOT/etc/portage/package.accept_keywords"
  echo "gui-apps/quickshell ~amd64" > "$VITRUM_SYSROOT/etc/portage/package.accept_keywords/50-vitrum"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >/dev/null 2>&1
  [[ -f "$VITRUM_SYSROOT/etc/portage/package.accept_keywords/50-vitrum" ]]
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes --purge ) >/dev/null 2>&1
  [[ ! -e "$VITRUM_SYSROOT/etc/portage/package.accept_keywords/50-vitrum" ]]
}
test_uninstall_removes_the_login_and_boot_themes() {
  _installed_world
  mkdir -p "$VITRUM_SYSROOT/usr/share/sddm/themes/vitrum" "$VITRUM_SYSROOT/usr/share/plymouth/themes/vitrum" "$VITRUM_SYSROOT/etc/sddm.conf.d"
  touch "$VITRUM_SYSROOT/etc/sddm.conf.d/zz-vitrum.conf"
  echo spinner > "$XDG_DATA_HOME/vitrum/previous-plymouth"
  stub plymouth-set-default-theme 'echo "set $*" >> "$HOME/calls"'
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >/dev/null 2>&1
  [[ ! -e "$VITRUM_SYSROOT/usr/share/sddm/themes/vitrum" && ! -e "$VITRUM_SYSROOT/usr/share/plymouth/themes/vitrum" ]]
  [[ ! -e "$VITRUM_SYSROOT/etc/sddm.conf.d/zz-vitrum.conf" ]]
  assert_contains "$(cat "$HOME/calls")" "set spinner"
}
test_uninstall_gives_back_only_the_kde_colours() {
  # kdeglobals collects KDE's own settings after install; uninstall must keep
  # those and swap only vitrum's colours back for the original ones.
  _installed_world
  local b="$XDG_DATA_HOME/vitrum/originals"
  printf '[General]\nColorScheme=BreezeDark\n\n[Colors:View]\nForegroundNormal=9,9,9\n' > "$b/.config/kdeglobals"
  printf 'saved .config/kitty/kitty.conf\nsaved .config/kdeglobals\n' > "$b/.manifest"
  printf '[General]\nColorScheme=Vitrum\n\n[Colors:View]\nForegroundNormal=1,1,1\n\n[UiSettings]\nColorScheme=Vitrum\n\n[Shortcuts]\nfoo=Ctrl+K\n' > "$XDG_CONFIG_HOME/kdeglobals"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >/dev/null 2>&1
  local k; k="$(cat "$XDG_CONFIG_HOME/kdeglobals")"
  assert_contains "$k" "ColorScheme=BreezeDark"
  assert_contains "$k" "ForegroundNormal=9,9,9"
  assert_contains "$k" "foo=Ctrl+K"
  [[ "$k" != *Vitrum* ]] || { echo "$k"; return 1; }
}
test_uninstall_takes_the_keyring_lines_out_of_pam() {
  _installed_world
  mkdir -p "$VITRUM_SYSROOT/etc/pam.d"
  printf 'auth include system-local-login\n# vitrum: open the keyring with the login password\n-auth      optional     pam_gnome_keyring.so\nsession include system-local-login\n' > "$VITRUM_SYSROOT/etc/pam.d/login"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >/dev/null 2>&1
  assert_eq "$(cat "$VITRUM_SYSROOT/etc/pam.d/login")" "$(printf 'auth include system-local-login\nsession include system-local-login')"
}

# install.json is no setting: after an uninstall the next install.sh is a
# first install (the language, the tour). The choices stay for its defaults.
test_uninstall_forgets_the_install() {
  _installed_world
  printf '{"version": "0.4.0"}\n' > "$XDG_DATA_HOME/vitrum/install.json"
  printf '{"version": 2}\n' > "$XDG_DATA_HOME/vitrum/components.json"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >/dev/null 2>&1
  [[ ! -e "$XDG_DATA_HOME/vitrum/install.json" ]] || { echo "install.json left"; return 1; }
  [[ -e "$XDG_DATA_HOME/vitrum/components.json" ]] || { echo "the choices went without --purge"; return 1; }
}

# _runit_world [running] — the installed world on Void: gdm was the login
# screen, the install linked dbus and elogind and, under a running runit,
# queued SDDM in place of gdm for the next boot.
_runit_world() {
  _installed_world
  stub xbps-install; stub sv; stub sleep
  export VITRUM_ROOTFS="$VITRUM_SYSROOT"
  local r="$VITRUM_ROOTFS" d
  mkdir -p "$r/etc"; printf 'ID=void\n' > "$r/etc/os-release"
  for d in sddm gdm dbus elogind; do mkdir -p "$r/etc/sv/$d"; done
  mkdir -p "$r/etc/runit/runsvdir/default"; ln -s default "$r/etc/runit/runsvdir/current"
  for d in gdm dbus elogind; do ln -s "/etc/sv/$d" "$r/etc/runit/runsvdir/default/$d"; done
  if [[ "${1:-}" == running ]]; then
    mkdir -p "$r/run/runit/runsvdir" "$r/var"
    ln -s ../etc/runit/runsvdir/current "$r/var/service"
    cat > "$r/etc/rc.local" <<'RC'
#!/bin/sh
# vitrum begin: service changes for the next boot (written by the vitrum installer; it removes itself)
rm -f /etc/runit/runsvdir/current/gdm
ln -sfn /etc/sv/sddm /etc/runit/runsvdir/current/sddm
sed -i '/^# vitrum begin: service changes/,/^# vitrum end: service changes/d' /etc/rc.local
# vitrum end: service changes for the next boot
RC
  else
    rm "$r/etc/runit/runsvdir/default/gdm"; ln -s /etc/sv/sddm "$r/etc/runit/runsvdir/default/sddm"
  fi
  echo gdm > "$XDG_DATA_HOME/vitrum/previous-dm"
}

# Uninstalled before the reboot: the queued switch to SDDM is taken back, gdm
# (still running the session) stays linked, and the system's own services
# are left alone, as on every init.
test_uninstall_runit_cancels_the_queued_login_screen() {
  _runit_world running
  local out r="$VITRUM_ROOTFS"
  out="$( cd "$VITRUM_DIR" && ./uninstall.sh --yes 2>&1 )" || { echo "$out" | tail -20; return 1; }
  assert_contains "$out" "login screen: back to gdm from the next boot" || return 1
  ! grep -q "ln -sfn /etc/sv/sddm" "$r/etc/rc.local" || { cat "$r/etc/rc.local"; return 1; }
  ! grep -q "rm -f /etc/runit/runsvdir/current/gdm" "$r/etc/rc.local" || { cat "$r/etc/rc.local"; return 1; }
  [[ -L "$r/var/service/gdm" && -L "$r/var/service/dbus" && -L "$r/var/service/elogind" ]]
}

# runit not running (a chroot): the links change at once, so no "next boot".
test_uninstall_runit_not_running_relinks_at_once() {
  _runit_world
  local out d="$VITRUM_ROOTFS/etc/runit/runsvdir/default"
  out="$( cd "$VITRUM_DIR" && ./uninstall.sh --yes 2>&1 )" || { echo "$out" | tail -20; return 1; }
  assert_contains "$out" "login screen: back to gdm" || return 1
  [[ "$out" != *"from the next boot"* ]] || { echo "$out"; return 1; }
  [[ -L "$d/gdm" && ! -e "$d/sddm" && -L "$d/dbus" && -L "$d/elogind" ]]
}

# The earlier login screen's service is gone: nothing is queued, so the step
# does not promise a switch at the next boot, and the backend says why.
test_uninstall_runit_without_the_service_promises_no_next_boot() {
  _runit_world running
  rm -rf "$VITRUM_ROOTFS/etc/sv/gdm"
  local out
  out="$( cd "$VITRUM_DIR" && ./uninstall.sh --yes 2>&1 )" || { echo "$out" | tail -20; return 1; }
  [[ "$out" != *"from the next boot"* ]] || { echo "$out"; return 1; }
  assert_contains "$out" "no runit service gdm"
}
