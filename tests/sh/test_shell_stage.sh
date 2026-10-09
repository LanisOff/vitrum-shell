# shellcheck shell=bash disable=SC1090,SC1091
_load() { source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/stages/40-shell.sh"; }
test_shell_installs_into_quickshell_vitrum() {
  _load; _shell_check_qml() { :; }
  stage_shell >/dev/null
  [[ -f "$XDG_CONFIG_HOME/quickshell/vitrum/lib/color.js" ]]
}
test_launchers_are_vitrum_named_and_valid() {
  _load; _shell_check_qml() { :; }
  stage_shell >/dev/null
  bash -n "$HOME/.local/bin/vitrum-shell"; bash -n "$HOME/.local/bin/vitrum-ipc"
  assert_contains "$(cat "$HOME/.local/bin/vitrum-shell")" "-c vitrum"
  assert_contains "$(cat "$HOME/.local/bin/vitrum-ipc")" "ipc call"
  [[ ! -e "$HOME/.local/bin/niri-tahoe-shell" ]]
}

test_shell_stage_installs_vitrum_theme() {
  _load; _shell_check_qml() { :; }
  stub python3 'exit 0'
  stage_shell >/dev/null
  [[ -x "$HOME/.local/bin/vitrum-theme" ]]
  [[ -f "$XDG_DATA_HOME/vitrum/lib/vitrum_theme/__init__.py" ]]
}
test_shell_launcher_stops_by_pid_file() {
  _load; _shell_check_qml() { :; }
  stage_shell >/dev/null
  l="$(cat "$HOME/.local/bin/vitrum-shell")"
  assert_contains "$l" "vitrum-shell.pid"
  ! grep -q -- "pkill -f -- '-c vitrum'" <<<"$l"
}
test_shell_stage_creates_settings_only_when_absent() {
  _load; _shell_check_qml() { :; }
  stub python3 'exit 0'
  stage_shell >/dev/null
  [[ "$(cat "$XDG_CONFIG_HOME/vitrum/settings.json")" == "{}" ]]
  printf '{"density":"compact"}\n' > "$XDG_CONFIG_HOME/vitrum/settings.json"
  stage_shell >/dev/null
  assert_contains "$(cat "$XDG_CONFIG_HOME/vitrum/settings.json")" "compact"
}
