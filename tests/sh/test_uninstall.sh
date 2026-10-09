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
  before="$(find "$HOME" -type f | sort | xargs cat | shasum)"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --dry-run --yes ) >/dev/null 2>&1
  assert_eq "$(find "$HOME" -type f | sort | xargs cat | shasum)" "$before"
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
