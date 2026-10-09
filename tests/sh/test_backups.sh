# shellcheck shell=bash disable=SC1090,SC1091
# C1: a path is saved only the first time vitrum ever touches it; files vitrum
# created are recorded as created, never "saved" by a later run.
_run_install_like() {  # simulate one installer run writing kitty.conf and a launcher
  ( export BACKUP_DIR=""; source "$VITRUM_DIR/lib/common.sh"
    printf 'VITRUM %s\n' "$1" | write_file "$XDG_CONFIG_HOME/kitty/kitty.conf"
    printf '#!/bin/sh\n' | write_file "$HOME/.local/bin/vitrum-shell" )
}
test_two_installs_then_uninstall_restores_originals() {
  stub sudo '"$@"'; stub uname 'echo Linux'
  mkdir -p "$XDG_CONFIG_HOME/kitty"; echo "MINE" > "$XDG_CONFIG_HOME/kitty/kitty.conf"
  _run_install_like 1; _run_install_like 2
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >/dev/null 2>&1
  assert_eq "$(cat "$XDG_CONFIG_HOME/kitty/kitty.conf")" "MINE"
  [[ ! -e "$HOME/.local/bin/vitrum-shell" ]]
}
test_created_file_is_not_saved_later() {
  _run_install_like 1; _run_install_like 2
  m="$(cat "$XDG_DATA_HOME/vitrum/originals/.manifest")"
  assert_contains "$m" "created .local/bin/vitrum-shell"
  ! grep -q "saved .local/bin/vitrum-shell" <<<"$m"
  assert_eq "$(grep -c 'kitty/kitty.conf' <<<"$m")" 1
}
test_uninstall_forgets_originals_after_restoring() {
  stub sudo '"$@"'; stub uname 'echo Linux'
  mkdir -p "$XDG_CONFIG_HOME/kitty"; echo "MINE" > "$XDG_CONFIG_HOME/kitty/kitty.conf"
  _run_install_like 1
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >/dev/null 2>&1
  [[ ! -e "$XDG_DATA_HOME/vitrum/originals" ]]
  echo "MINE2" > "$XDG_CONFIG_HOME/kitty/kitty.conf"; _run_install_like 2
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >/dev/null 2>&1
  assert_eq "$(cat "$XDG_CONFIG_HOME/kitty/kitty.conf")" "MINE2"
}
