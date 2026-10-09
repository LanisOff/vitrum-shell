# shellcheck shell=bash disable=SC1090,SC1091
_load_theming() {
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/stages/60-theming.sh"
  stub gsettings 'echo "gsettings $*" >> "$HOME/calls"'
  mkdir -p "$XDG_CONFIG_HOME/vitrum"
}
test_gtk_settings_from_vitrum_settings() {
  _load_theming
  printf '{"icons":{"theme":"Papirus-Light"},"fonts":{"sans":"Noto Sans"},"cursor":{"theme":"Bibata-Modern-Ice"}}' > "$XDG_CONFIG_HOME/vitrum/settings.json"
  stage_theming >/dev/null 2>&1
  for v in 3 4; do
    s="$(cat "$XDG_CONFIG_HOME/gtk-$v.0/settings.ini")"
    assert_contains "$s" "gtk-icon-theme-name=Papirus-Light"
    assert_contains "$s" "gtk-cursor-theme-name=Bibata-Modern-Ice"
    assert_contains "$s" "gtk-font-name=Noto Sans 11"
    assert_contains "$s" "gtk-theme-name=Adwaita"
  done
  assert_contains "$(cat "$HOME/calls")" "icon-theme Papirus-Light"
}
test_gtk_off_keeps_your_gtk_theme() {
  _load_theming
  printf '{"toolkits":{"gtk":false}}' > "$XDG_CONFIG_HOME/vitrum/settings.json"
  mkdir -p "$XDG_CONFIG_HOME/gtk-3.0" "$XDG_CONFIG_HOME/gtk-4.0"
  printf '[Settings]\ngtk-theme-name=Orchis-Dark\n' > "$XDG_CONFIG_HOME/gtk-4.0/settings.ini"
  stage_theming >/dev/null 2>&1
  assert_contains "$(cat "$XDG_CONFIG_HOME/gtk-4.0/settings.ini")" "gtk-theme-name=Orchis-Dark"
  ! grep -q "gtk-theme-name" "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
  ! grep -q "gtk-theme " "$HOME/calls"
  assert_contains "$(cat "$HOME/calls")" "icon-theme Papirus-Dark"
}
test_qt_goes_through_kvantum_vitrum() {
  _load_theming
  stage_theming >/dev/null 2>&1
  assert_contains "$(cat "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig")" "theme=vitrum"
  assert_contains "$(cat "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig")" "vitrumcompact=Throne"
  q="$(cat "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf")"
  assert_contains "$q" "style=kvantum"
  assert_contains "$q" "icon_theme=Papirus-Dark"
  assert_contains "$(cat "$XDG_CONFIG_HOME/qt5ct/qt5ct.conf")" "style=kvantum"
}
test_default_cursor_and_dolphin() {
  _load_theming
  stage_theming >/dev/null 2>&1
  assert_contains "$(cat "$XDG_DATA_HOME/icons/default/index.theme")" "Inherits=Bibata-Modern-Classic"
  assert_contains "$(cat "$XDG_CONFIG_HOME/dolphinrc")" "[General]"
}
test_theming_has_no_mac_leftovers() {
  _load_theming
  stage_theming >/dev/null 2>&1
  ! grep -rqiE "whitesur|SF Pro|SF Mono|tahoe|finder" "$XDG_CONFIG_HOME/gtk-3.0" "$XDG_CONFIG_HOME/qt6ct" "$XDG_CONFIG_HOME/Kvantum" "$XDG_CONFIG_HOME/dolphinrc"
  [[ ! -d "$HOME/Applications" ]]
}
test_existing_dolphinrc_is_kept() {
  _load_theming
  printf '[General]\nShowFullPath=true\n' > "$XDG_CONFIG_HOME/dolphinrc"
  stage_theming >/dev/null 2>&1
  assert_contains "$(cat "$XDG_CONFIG_HOME/dolphinrc")" "ShowFullPath=true"
}
# From a tty or ssh there is no session bus and dconf is unreachable: gsettings
# goes through a bus of its own instead of failing quietly.
test_gsettings_without_session_bus_get_one() {
  _load_theming
  unset DBUS_SESSION_BUS_ADDRESS
  stub dbus-run-session 'echo "dbus-run-session $*" >> "$HOME/calls"'
  stage_theming >/dev/null 2>&1
  assert_contains "$(cat "$HOME/calls")" "dbus-run-session -- gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark"
}
test_gsettings_inside_a_session_used_directly() {
  _load_theming
  export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/bus
  stub dbus-run-session 'echo "dbus-run-session $*" >> "$HOME/calls"'
  stage_theming >/dev/null 2>&1
  ! grep -q "dbus-run-session" "$HOME/calls"
  assert_contains "$(cat "$HOME/calls")" "gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark"
}
