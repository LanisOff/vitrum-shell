# shellcheck shell=bash disable=SC1090,SC1091
_load() { source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/stages/40-shell.sh"; }
test_running_shell_is_restarted() {
  _load
  export XDG_RUNTIME_DIR="$HOME/run"; mkdir -p "$XDG_RUNTIME_DIR"
  sleep 30 & local p=$!
  echo "$p" > "$XDG_RUNTIME_DIR/vitrum-shell.pid"
  _shell_restart >/dev/null 2>&1
  sleep 0.2
  ! kill -0 "$p" 2>/dev/null
}
test_locked_screen_keeps_the_shell() {
  _load
  export XDG_RUNTIME_DIR="$HOME/run"; mkdir -p "$XDG_RUNTIME_DIR"
  sleep 30 & local p=$!
  echo "$p" > "$XDG_RUNTIME_DIR/vitrum-shell.pid"; : > "$XDG_RUNTIME_DIR/vitrum-locked-wayland-1"
  out="$(_shell_restart 2>&1)"
  kill -0 "$p" 2>/dev/null || return 1
  kill "$p"
  assert_contains "$out" "locked"
}
test_no_shell_no_restart() {
  _load
  export XDG_RUNTIME_DIR="$HOME/run"; mkdir -p "$XDG_RUNTIME_DIR"
  _shell_restart
}
