# shellcheck shell=bash disable=SC1090,SC1091
_load() { source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/stages/50-apps.sh"; stub sudo '"$@"'; sudo_write() { cat > /dev/null; }; }

test_apps_install_as_vitrum_configs_sharing_the_shell() {
  _load
  stage_apps >/dev/null
  for app in settings disks about; do
    [[ -f "$XDG_CONFIG_HOME/quickshell/vitrum-$app/shell.qml" ]] || { echo "no vitrum-$app"; return 1; }
    for d in theme components services lib data; do
      assert_eq "$(readlink "$XDG_CONFIG_HOME/quickshell/vitrum-$app/$d")" "$XDG_CONFIG_HOME/quickshell/vitrum/$d"
    done
    [[ -f "$XDG_CONFIG_HOME/quickshell/vitrum-$app/common/AppWindow.qml" ]] || { echo "no common in $app"; return 1; }
    [[ ! -L "$XDG_CONFIG_HOME/quickshell/vitrum-$app/common" ]]
  done
}
test_apps_launchers_and_desktop_entries() {
  _load
  stage_apps >/dev/null
  l="$(cat "$HOME/.local/bin/vitrum-settings")"
  bash -n "$HOME/.local/bin/vitrum-settings"
  assert_contains "$l" "VITRUM_PANE"
  assert_contains "$l" "vitrum-settings/shell.qml"
  for app in settings disks about; do [[ -x "$HOME/.local/bin/vitrum-$app" ]]; done
  d="$(cat "$XDG_DATA_HOME/applications/vitrum-settings.desktop")"
  assert_contains "$d" "Exec=$HOME/.local/bin/vitrum-settings"
  assert_contains "$d" "StartupWMClass=vitrum-settings"
  ! grep -rqi "mac\|finder\|spotlight" "$XDG_DATA_HOME/applications/"
}
test_apps_remove_niri_tahoe_leftovers() {
  _load
  mkdir -p "$HOME/.local/bin" "$XDG_DATA_HOME/applications" "$XDG_CONFIG_HOME/quickshell/niri-tahoe-settings"
  touch "$HOME/.local/bin/niri-tahoe-settings" "$XDG_DATA_HOME/applications/niri-tahoe-about.desktop" "$XDG_DATA_HOME/applications/finder.desktop"
  stage_apps >/dev/null
  [[ ! -e "$HOME/.local/bin/niri-tahoe-settings" && ! -e "$XDG_DATA_HOME/applications/niri-tahoe-about.desktop" && ! -e "$XDG_DATA_HOME/applications/finder.desktop" ]]
  [[ ! -e "$XDG_CONFIG_HOME/quickshell/niri-tahoe-settings" ]]
}
