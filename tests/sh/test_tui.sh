# shellcheck shell=bash disable=SC1090,SC1091,SC2016,SC2034
# The terminal layer under the screens (lib/tui.sh): keys, the check for a
# terminal to draw on, and the frame painter.

_tui() {
  source "$VITRUM_DIR/lib/common.sh"
  source "$VITRUM_DIR/lib/tui.sh"
}

# _tui_keys <bytes> — the bytes as the keyboard input of the next tui_key calls.
_tui_keys() { TUI_IN="$HOME/keys"; printf '%s' "$1" > "$TUI_IN"; }

test_key_decoding() {
  _tui
  _tui_keys $'\e[A\e[B \n\eOCx'
  # Called in this shell, not in $(…), so the input keeps its place between calls.
  local i
  for i in 1 2 3 4 5 6; do tui_key; done > "$HOME/out"
  assert_eq "$(tr '\n' ' ' < "$HOME/out")" "up down space enter right x "
}

test_more_keys() {
  _tui
  _tui_keys $'\eOA\e[D\t\x7f\e[1;5B\e[3~q'
  local i
  for i in 1 2 3 4 5 6 7; do tui_key; done > "$HOME/out"
  # Ctrl+Down is still down; a key the screens have no use for (Delete) is
  # an empty line, not stray characters.
  assert_eq "$(tr '\n' ' ' < "$HOME/out")" "up left tab backspace down  q "
}

test_lone_escape() {
  _tui
  _tui_keys $'\e'
  assert_eq "$(tui_key)" esc
}

# The end of the input is its own key, not Esc: the screens take it as
# leave, where Esc only goes back a screen.
test_end_of_input_is_eof() {
  _tui
  _tui_keys ""
  local rc=0 k
  k="$(tui_key)" || rc=$?
  assert_eq "$k/$rc" eof/1
}

# A Cyrillic letter is one key, as the screens' Russian-layout keys need.
test_cyrillic_key() {
  _tui
  _tui_keys "фк"
  local i
  for i in 1 2; do tui_key; done > "$HOME/out"
  assert_eq "$(tr '\n' ' ' < "$HOME/out")" "ф к "
}

# The words of a hint are not file names.
test_wrap_does_not_glob() {
  _tui
  cd "$HOME" || return 1
  touch a1 a2
  assert_eq "$(tui_wrap 20 "tick a* and *")" "tick a* and *"
  assert_eq "$(tui_wrap 6 "one two three")" $'one\ntwo\nthree'
  # Every line of a text, not only the first.
  assert_eq "$(tui_wrap 40 $'first line\nsecond line')" "first line second line"
}

# A test hook: with TUI_IN and TUI_OUT files the screens need no terminal.
test_force_hook() {
  _tui
  export TERM=xterm-256color
  unset VITRUM_TTY
  ASSUME_YES=0 VITRUM_FORCE_TUI=1 TUI_IN="$HOME/keys" TUI_OUT="$HOME/screen"
  tui_available </dev/null >/dev/null || { echo "not available with the hook"; return 1; }
  # Without the files it is the real check, and --yes still wins.
  unset TUI_IN
  ! tui_available >/dev/null || { echo "available without a terminal"; return 1; }
  TUI_IN="$HOME/keys" ASSUME_YES=1
  ! tui_available || { echo "available under --yes"; return 1; }
}

# Ctrl+C right after tui_begin finds the traps already set: they were put in
# place before the terminal modes changed.
test_traps_are_set_before_the_terminal_changes() {
  _tui
  _tui_keys ""
  TUI_OUT="$HOME/screen"
  local seen=""
  stty() { seen+="stty:$(trap -p INT | grep -c _tui_signal)/$_TUI_ON "; }
  # stty is only called with a real terminal; pretend there is one.
  unset TUI_IN
  { : <>/dev/tty; } 2>/dev/null || { echo "SKIP: needs a terminal for stty" >&2; return 0; }
  tui_begin
  tui_end
  assert_contains "$seen" "stty:1/1"
}

# _tui_deadline <seconds> <cmd...> — run it in the background and fail if it
# is still running when the time is up. macOS has no timeout(1).
_tui_deadline() {
  local secs="$1" pid i rc=0; shift
  "$@" &
  pid=$!
  for (( i = 0; i < secs * 10; i++ )); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; echo "still running after ${secs}s: $*"; return 124; fi
  wait "$pid" || rc=$?
  return "$rc"
}

test_not_available_without_tty() {
  _tui
  export VITRUM_TTY=1 TERM=xterm-256color
  ASSUME_YES=1
  ! tui_available || { echo "available under --yes"; return 1; }
  ASSUME_YES=0 TERM=dumb
  ! tui_available || { echo "available with TERM=dumb"; return 1; }
  TERM=xterm-256color
  if ! command -v setsid >/dev/null; then
    echo "SKIP: test_not_available_without_tty needs setsid" >&2
    # The harness itself may have no controlling terminal; then the same
    # case can at least be checked here.
    if ! { : <>/dev/tty; } 2>/dev/null; then
      ! tui_available || { echo "available without a controlling terminal"; return 1; }
    fi
    return 0
  fi
  local rc=0
  # setsid drops the controlling terminal, so /dev/tty cannot be opened.
  _tui_deadline 5 setsid --wait bash -c 'source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/tui.sh"; tui_available' \
    </dev/null >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 1
}

test_frame_cuts_to_width() {
  _tui
  _tui_keys ""
  TUI_OUT="$HOME/screen" TUI_ROWS=5 TUI_COLS=20
  local line="" i
  for (( i = 0; i < 20; i++ )); do line+=$'\e[38;5;39m'"ab"$'\e[0m'; done
  printf '%s\nshort\n' "$line" > "$HOME/frame"
  tui_begin
  tui_frame "$HOME/frame"
  tui_end
  local painted
  painted="$(sed $'s/\e\\[[0-9;?]*[A-Za-z]//g' "$HOME/screen")"
  assert_eq "$painted" $'abababababababababab\nshort'
}

test_frame_keeps_to_the_rows() {
  _tui
  _tui_keys ""
  TUI_OUT="$HOME/screen" TUI_ROWS=3 TUI_COLS=20
  printf '%s\n' one two three four five > "$HOME/frame"
  tui_begin; tui_frame "$HOME/frame"; tui_end
  assert_eq "$(sed $'s/\e\\[[0-9;?]*[A-Za-z]//g' "$HOME/screen")" $'one\ntwo\nthree'
}

# tui_begin enters the alternate screen and hides the cursor; tui_end puts
# both back, also when it is called twice, and gives back an EXIT trap that
# was there before.
test_begin_and_end() {
  _tui
  _tui_keys ""
  TUI_OUT="$HOME/screen"
  trap 'echo earlier' EXIT
  tui_begin
  assert_contains "$(trap -p EXIT)" "tui_end"
  assert_contains "$(trap -p EXIT)" "echo earlier"
  tui_end
  tui_end
  assert_eq "$(trap -p EXIT)" "trap -- 'echo earlier' EXIT"
  trap - EXIT
  local s; s="$(cat "$HOME/screen")"
  assert_contains "$s" $'\e[?1049h'
  assert_contains "$s" $'\e[?25l'
  assert_contains "$s" $'\e[?25h'
  assert_contains "$s" $'\e[?1049l'
  # The second tui_end drew nothing more.
  assert_eq "$(grep -o $'\e\\[?1049l' "$HOME/screen" | wc -l | tr -d ' ')" 1
}

test_size_falls_back() {
  _tui
  unset TUI_ROWS TUI_COLS TUI_OUT
  tui_size </dev/null
  # Run from a terminal, the tests see its real size; without one, the fallback.
  if { : <>/dev/tty; } 2>/dev/null; then
    [[ "$TUI_ROWS" =~ ^[1-9][0-9]*$ && "$TUI_COLS" =~ ^[1-9][0-9]*$ ]]
  else
    assert_eq "$TUI_ROWS/$TUI_COLS" 24/80
  fi
}
