# shellcheck shell=bash disable=SC1090,SC1091
_load_term() {
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/stages/45-terminal.sh"
  stub sudo '"$@"'
  stub rsvg-convert 'for a; do o="$a"; done; : > "$o"'
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\necho "vitrum-theme $*" >> "$HOME/calls"\n' > "$HOME/.local/bin/vitrum-theme"; chmod +x "$HOME/.local/bin/vitrum-theme"
  WANT_TMUX=0; WANT_NVIM=0; WANT_FISH=0; ASSUME_YES=1
}
test_terminal_installs_templates_and_renders_everything() {
  _load_term
  stage_terminal >/dev/null 2>&1
  [[ -f "$XDG_DATA_HOME/vitrum/templates/kitty/vitrum-colors.conf.in" && -f "$XDG_DATA_HOME/vitrum/templates/gtk-4.0/vitrum.css.in" ]]
  assert_contains "$(cat "$HOME/calls")" "vitrum-theme --all"
  [[ -f "$XDG_DATA_HOME/vitrum/fastfetch/logo.png" ]]
}
test_terminal_backs_up_your_configs_first() {
  _load_term
  mkdir -p "$XDG_CONFIG_HOME/kitty"; echo mine > "$XDG_CONFIG_HOME/kitty/kitty.conf"
  printf '[KDE]\nSingleClick=false\n' > "$XDG_CONFIG_HOME/kdeglobals"
  stage_terminal >/dev/null 2>&1
  grep -q "saved .config/kitty/kitty.conf" "$XDG_DATA_HOME/vitrum/originals/.manifest"
  grep -q "saved .config/kdeglobals" "$XDG_DATA_HOME/vitrum/originals/.manifest"
  assert_eq "$(cat "$XDG_DATA_HOME/vitrum/originals/.config/kitty/kitty.conf")" mine
}
test_terminal_removes_niri_tahoe_tools() {
  _load_term
  touch "$HOME/.local/bin/niri-tahoe-theme-sync" "$HOME/.local/bin/niri-tahoe-palette"
  stage_terminal >/dev/null 2>&1
  [[ ! -e "$HOME/.local/bin/niri-tahoe-theme-sync" && ! -e "$HOME/.local/bin/niri-tahoe-palette" ]]
}
test_tmux_plugins_offline_is_not_fatal() {
  _load_term; WANT_TMUX=1
  stub tmux 'exit 1'
  stub git 'exit 128'
  ( stage_terminal >/dev/null 2>&1 ) || { echo "stage died"; return 1; }
}
test_terminal_names_configs_kept_with_a_newer_version_beside_them() {
  _load_term
  printf '#!/bin/sh\nmkdir -p "$XDG_CONFIG_HOME/kitty"; : > "$XDG_CONFIG_HOME/kitty/kitty.conf.vitrum-new"\n' > "$HOME/.local/bin/vitrum-theme"
  out="$(stage_terminal 2>&1)"
  assert_contains "$out" "kitty/kitty.conf.vitrum-new"
}
test_terminal_backs_up_tmux_keys() {
  _load_term
  mkdir -p "$XDG_CONFIG_HOME/tmux"; echo mine > "$XDG_CONFIG_HOME/tmux/keys.conf"
  stage_terminal >/dev/null 2>&1
  grep -q "saved .config/tmux/keys.conf" "$XDG_DATA_HOME/vitrum/originals/.manifest"
}
