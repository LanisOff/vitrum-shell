# shellcheck shell=bash disable=SC1090,SC1091,SC2001,SC2016,SC2034,SC2329
# The progress view and the failure prompt (lib/progress.sh), with fake stages
# in $HOME/stages, the screen in a file and the keys from a file.

_prog() {
  export NO_COLOR=1
  _NAP=$(( 4000000 + RANDOM * 32768 + RANDOM ))
  unset VITRUM_LANG VITRUM_RUN_DIR VITRUM_STAGE_KEY VITRUM_PROGRESS
  source "$VITRUM_DIR/lib/common.sh"
  source "$VITRUM_DIR/lib/progress.sh"
  export VITRUM_LOG="$HOME/log"
  : > "$VITRUM_LOG"
  TUI_OUT="$HOME/screen" TUI_IN="$HOME/keys"
  : > "$TUI_IN"
  mkdir -p "$HOME/stages"
  PKG_BACKEND=pacman INIT_BACKEND=systemd
}

# _fake <key> <body> — a stage file in $HOME/stages defining stage_<key>.
_fake() {
  printf 'stage_%s() {\n%s\n}\n' "$1" "$2" > "$HOME/stages/$1.sh"
  STAGE_FILE[$1]="$HOME/stages/$1.sh"
}

_keys() { printf '%s' "$1" > "$TUI_IN"; }
_visible() { sed $'s/\e\\[[0-9;?]*[A-Za-z]//g' <<<"$1"; }
_status() { cat "$VITRUM_RUN_DIR/$1.status"; }

test_all_ok() {
  _prog
  local k
  for k in a b c; do _fake "$k" 'step "doing"; echo line1; echo line2'; done
  progress_run a b c
  for k in a b c; do assert_eq "$(_status "$k")" ok || return 1; done
  assert_eq "$(grep -c line2 "$VITRUM_LOG")" 3
  # The screen was drawn and given back; nothing of it is in the log.
  assert_contains "$(cat "$HOME/screen")" $'\e[?1049l'
  ! grep -q $'\e\\[?1049h' "$VITRUM_LOG" || { echo "the screen went into the log"; return 1; }
}

test_failure_retry_then_ok() {
  _prog
  _fake a 'true'
  _fake b 'n="$(cat "$HOME/count" 2>/dev/null || echo 0)"; echo $((n + 1)) > "$HOME/count"; (( n >= 1 )) || die "first time"'
  _keys r
  progress_run a b
  assert_eq "$(_status b)" ok
  assert_eq "$(cat "$HOME/count")" 2
  # The attempt that failed is not reported once the retry worked.
  ! grep -q "first time" "$VITRUM_RUN_DIR/errors" 2>/dev/null || { echo "the retried error is still listed"; return 1; }
  grep -q "first time" "$VITRUM_LOG"
}

test_failure_skip_marks_dependents() {
  _prog
  _fake b 'die "boom %s" x'
  _fake c 'touch "$HOME/c-ran"'
  _fake d 'touch "$HOME/d-ran"'
  STAGE_NEEDS[c]=b
  STAGE_NEEDS[d]=c
  _keys s
  progress_run b c d
  assert_eq "$(_status b)/$(_status c)/$(_status d)" skip/needs/needs
  [[ ! -e "$HOME/c-ran" && ! -e "$HOME/d-ran" ]] || { echo "a stage ran without what it needs"; return 1; }
  assert_contains "$(cat "$VITRUM_RUN_DIR/b.error")" "boom x"
  local out; out="$(_visible "$(progress_render)")"
  assert_contains "$out" "skipped: needs b"
}

test_failure_quit() {
  _prog
  _fake a 'true'
  _fake b 'die "boom"'
  _fake c 'touch "$HOME/c-ran"'
  _keys q
  local rc=0 out
  out="$(progress_run a b c)" || rc=$?
  assert_eq "$rc" 1
  assert_contains "$out" "./install.sh --from b"
  assert_contains "$out" "$VITRUM_LOG"
  [[ ! -e "$HOME/c-ran" ]]
  assert_contains "$(cat "$HOME/screen")" $'\e[?1049l'
}

# The end of the keys quits too: a prompt whose terminal went away must not spin.
test_failure_end_of_input_quits() {
  _prog
  _fake b 'die "boom"'
  local rc=0
  progress_run b > /dev/null || rc=$?
  assert_eq "$rc" 1
}

# The keys on a Russian layout are the same keys.
test_failure_keys() {
  _prog
  local k rc want
  for k in r:30 R:30 к:30 К:30 s:31 ы:31 Ы:31 l:33 д:33 q:32 й:32 Й:32 eof:32; do
    want="${k##*:}"
    rc=0; _progress_failure_key "${k%:*}" || rc=$?
    assert_eq "$rc" "$want" || { echo "for ${k%:*}"; return 1; }
  done
  # Arrows move between the buttons; Enter takes the one chosen.
  _PROGRESS_BUTTON=0
  _progress_failure_key right; _progress_failure_key right
  rc=0; _progress_failure_key enter || rc=$?
  assert_eq "$rc" 33
  _progress_failure_key left
  rc=0; _progress_failure_key enter || rc=$?
  assert_eq "$rc" 31
}

test_failure_render() {
  _prog
  PROGRESS_STAGES=(a b c)
  VITRUM_RUN_DIR="$HOME/run"; mkdir -p "$VITRUM_RUN_DIR"
  printf 'ok\n' > "$VITRUM_RUN_DIR/a.status"; printf '3\n' > "$VITRUM_RUN_DIR/a.time"
  printf 'fail\n' > "$VITRUM_RUN_DIR/b.status"; printf '5\n' > "$VITRUM_RUN_DIR/b.time"
  printf 'could not install x\n' > "$VITRUM_RUN_DIR/b.error"
  printf 'compiling\nerror: linker failed\n' > "$VITRUM_RUN_DIR/b.out"
  _PROGRESS_FAILED=b _PROGRESS_BUTTON=0
  local out; out="$(_visible "$(progress_render)")"
  assert_contains "$out" "could not install x"
  assert_contains "$out" "│ error: linker failed"
  assert_contains "$out" "[ Retry ]"
  assert_contains "$out" "Skip this stage"
  assert_contains "$out" "Show log"
  assert_contains "$out" "Quit"
  [[ "$out" != *"min left"* ]] || { echo "the bar under a failure"; return 1; }
}

test_render_shows_tail_and_state() {
  _prog
  PROGRESS_STAGES=(a b c)
  VITRUM_RUN_DIR="$HOME/run"; mkdir -p "$VITRUM_RUN_DIR"
  printf 'ok\n' > "$VITRUM_RUN_DIR/a.status"; printf '3\n' > "$VITRUM_RUN_DIR/a.time"
  printf 'running\n' > "$VITRUM_RUN_DIR/b.status"
  date +%s > "$VITRUM_RUN_DIR/b.start"
  printf 'doing\n' > "$VITRUM_RUN_DIR/b.step"
  printf 'line0\nline1\n\nline2\n   \n\e[1mline3\e[0m\r\n' > "$VITRUM_RUN_DIR/b.out"
  local raw out; raw="$(progress_render)"; out="$(_visible "$raw")"
  assert_contains "$out" "doing"
  assert_contains "$out" "│ line2"
  assert_contains "$out" "│ line3"
  [[ "$out" != *line0* ]] || { echo "more than the last 3 lines"; return 1; }
  # The tail's own colours are dropped, not passed to the frame.
  [[ "$raw" != *$'\e[1mline3'* ]] || { echo "an escape from the output is drawn"; return 1; }
  assert_contains "$out" "1/3"
  assert_contains "$out" "min left"
  # Pending: the dot; done: the check.
  assert_contains "$out" "· c"
  assert_contains "$out" "✓ a"
}

# A line of output wider than the terminal is cut, never wrapped.
test_render_cuts_the_tail() {
  _prog
  TUI_COLS=40
  PROGRESS_STAGES=(b)
  VITRUM_RUN_DIR="$HOME/run"; mkdir -p "$VITRUM_RUN_DIR"
  printf 'running\n' > "$VITRUM_RUN_DIR/b.status"; date +%s > "$VITRUM_RUN_DIR/b.start"
  printf '%s\n' "$(printf 'x%.0s' {1..100})" > "$VITRUM_RUN_DIR/b.out"
  local line
  while IFS= read -r line; do
    line="$(_visible "$line")"
    (( ${#line} <= 40 )) || { echo "line ${#line} wide: [$line]"; return 1; }
  done <<<"$(progress_render)"
}

test_estimate_total() {
  _prog
  PKG_BACKEND=pacman
  niri_needs_build() { return 0; }
  assert_eq "$(progress_estimate_total packages niri)" 780
  PKG_BACKEND=portage
  assert_eq "$(progress_estimate_total packages niri)" 4500
  niri_needs_build() { return 1; }
  assert_eq "$(progress_estimate niri)" 5
  PKG_BACKEND=pacman
  assert_eq "$(progress_estimate_total preflight packages fonts niri shell apps terminal theming boot session doctor)" 373
}

# _until_running <pattern> — wait (up to 10 s) for a process matching it: the
# stage is running and progress_run's traps are set, however slow the machine.
_until_running() {
  local i
  for (( i = 0; i < 100; i++ )); do pgrep -f "$1" >/dev/null 2>&1 && return 0; sleep 0.1; done
  echo "never started: $1"; return 1
}

# _bg_run <stage…> — progress_run in the background, the way the installer
# runs in the foreground of a terminal: with job control on, so it is not
# started with SIGINT ignored (a non-interactive bash does that to every
# command it runs with &, and a Ctrl+C sent there would only test that).
# _BG is its pid.
_bg_run() {
  set -m
  ( progress_run "$@" ) > "$HOME/out" 2>&1 &
  _BG=$!
  set +m
}

# The fake stage sleeps for a length nothing else on the machine uses, so the
# check for what is left (pgrep looks at every process) sees only its own:
# picked at random, so not even what an earlier run left behind.
test_ctrl_c_kills_the_stage() {
  _prog
  _fake a "sleep $_NAP & wait"
  _bg_run a
  local pid=$_BG i rc=0
  _until_running "sleep $_NAP" || { kill -9 "$pid"; return 1; }
  kill -INT "$pid"
  for (( i = 0; i < 30; i++ )); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then kill -9 "$pid"; echo "progress_run still running"; return 1; fi
  wait "$pid" || rc=$?
  assert_eq "$rc" 130
  local left; left="$(pgrep -f "sleep $_NAP" || true)"
  [[ -z "$left" ]] || { pkill -f "sleep $_NAP"; echo "the stage's sleep is left running: $left"; return 1; }
  assert_contains "$(cat "$VITRUM_LOG")" "interrupted by the user"
  assert_contains "$(cat "$HOME/screen")" $'\e[?1049l'
}

test_warnings_survive_the_subshell() {
  _prog
  _fake a 'warn "careful"; err "broken %s" x'
  progress_run a
  assert_contains "$(cat "$VITRUM_RUN_DIR/warnings")" careful
  assert_contains "$(cat "$VITRUM_RUN_DIR/errors")" "broken x"
}

# The doctor reports problems; it is not a stage to retry.
test_doctor_failing_is_no_failure() {
  _prog
  _fake doctor 'err "something is off"; return 1'
  progress_run doctor
  assert_eq "$(_status doctor)" ok
}

# The real stages' dependencies: no packages, nothing that installs from them.
test_skipping_packages_takes_its_dependents() {
  _prog
  local k
  for k in packages fonts niri shell apps session; do _fake "$k" 'true'; done
  _fake packages 'die "no network"'
  _keys s
  progress_run packages fonts niri shell apps session
  assert_eq "$(_status packages)/$(_status fonts)/$(_status niri)/$(_status shell)/$(_status apps)/$(_status session)" \
    skip/ok/needs/needs/needs/needs
}

# A test hook: the stage functions are not called at all.
test_skip_stages_hook() {
  _prog
  _fake a 'touch "$HOME/a-ran"'
  VITRUM_SKIP_STAGES_FOR_TEST=1 progress_run a
  assert_eq "$(_status a)" ok
  [[ ! -e "$HOME/a-ran" ]]
}

test_stage_labels_translate() {
  _prog
  assert_eq "$(STAGE_LABEL preflight)/$(STAGE_LABEL doctor)" "Checks/Doctor"
  VITRUM_LANG=ru
  assert_eq "$(STAGE_LABEL packages)" "${I18N_RU[Packages]}"
}

# Closing the terminal ends the stage too: it is not in the terminal's
# foreground group, so the hang-up would not reach it by itself.
test_hangup_kills_the_stage() {
  _prog
  _fake a "sleep $_NAP & wait"
  _bg_run a
  local pid=$_BG i rc=0
  _until_running "sleep $_NAP" || { kill -9 "$pid"; return 1; }
  kill -HUP "$pid"
  for (( i = 0; i < 30; i++ )); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then kill -9 "$pid"; echo "progress_run still running"; return 1; fi
  wait "$pid" || rc=$?
  assert_eq "$rc" 129
  local left; left="$(pgrep -f "sleep $_NAP" || true)"
  [[ -z "$left" ]] || { pkill -f "sleep $_NAP"; echo "the stage's sleep is left running: $left"; return 1; }
}

# After the run nothing of it is left set for what comes next.
test_run_leaves_nothing_set() {
  _prog
  _fake a 'true'
  progress_run a
  assert_eq "${VITRUM_PROGRESS}/${VITRUM_STAGE_KEY:-unset}" 0/unset
  [[ -z "$(trap -p HUP)" ]] || { echo "a hang-up trap left: $(trap -p HUP)"; return 1; }
}

# A command that reads the terminal from the background is stopped (SIGTTIN)
# and would hang the view for ever; the stage fails instead, with a reason,
# and the prompt comes up. The stage stops itself the way the read would.
test_stage_stopped_for_input_fails() {
  _prog
  _fake a 'echo before; kill -TTIN "$BASHPID"; echo after'
  _fake b 'touch "$HOME/b-ran"'
  # From Show log, where the cursor starts after a stop, one button left is
  # Skip (letters do nothing yet: test_password_prompt_letters_are_not_buttons).
  _keys $'\e[D\n'
  local start=$SECONDS
  progress_run a b
  (( SECONDS - start < 10 )) || { echo "took $(( SECONDS - start ))s"; return 1; }
  assert_eq "$(_status a)" skip
  assert_contains "$(cat "$VITRUM_RUN_DIR/a.error")" "waited for input on the terminal"
  [[ -e "$HOME/b-ran" ]]
  ! grep -q after "$VITRUM_RUN_DIR/a.out" || { echo "the stopped stage went on"; return 1; }
}

# The same with a real read of the terminal, where there is one.
test_stage_reading_the_terminal_fails() {
  _prog
  { : <>/dev/tty; } 2>/dev/null || { echo "SKIP: test_stage_reading_the_terminal_fails needs a terminal" >&2; return 0; }
  _fake a 'read -r x </dev/tty; echo "got $x"'
  _keys q
  local rc=0
  progress_run a >/dev/null || rc=$?
  assert_eq "$rc" 1
  assert_contains "$(cat "$VITRUM_RUN_DIR/a.error" 2>/dev/null)" "waited for input"
}

# Each way the run can be cut short says which one in the log, and leaves no
# run directory behind.
test_interrupt_reasons() {
  _prog
  _fake a "sleep $_NAP & wait"
  local sig want pid i
  for sig in TERM:terminated HUP:"the terminal was closed"; do
    want="${sig#*:}"
    : > "$VITRUM_LOG"
    VITRUM_RUN_DIR="$HOME/run-$RANDOM"; mkdir -p "$VITRUM_RUN_DIR"
    _bg_run a
    pid=$_BG
    _until_running "sleep $_NAP" || { kill -9 "$pid"; return 1; }
    kill -"${sig%%:*}" "$pid"
    for (( i = 0; i < 30; i++ )); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    wait "$pid" || true
    assert_contains "$(cat "$VITRUM_LOG")" "$want" || return 1
    [[ ! -e "$VITRUM_RUN_DIR" ]] || { echo "run directory left after $sig"; return 1; }
    [[ "$(cat "$VITRUM_LOG")" != *"interrupted by the user"* ]] || { echo "user named for $sig"; return 1; }
  done
}

# Ctrl+C in the packages stage: INT first, and time to act on it (pacman and
# emerge stop between two packages), with the screen saying so; whatever is
# left after that still goes.
test_ctrl_c_stops_packages_gently() {
  _prog
  _fake packages 'trap "echo int >> \"\$HOME/sig\"; exit 0" INT; '"sleep $_NAP"' >/dev/null 2>&1 & wait'
  _bg_run packages
  local pid=$_BG i rc=0 start
  _until_running "sleep $_NAP" || { kill -9 "$pid"; return 1; }
  start=$SECONDS
  kill -INT "$pid"
  for (( i = 0; i < 100; i++ )); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then kill -9 "$pid"; echo "progress_run still running"; return 1; fi
  wait "$pid" || rc=$?
  assert_eq "$rc" 130
  assert_eq "$(cat "$HOME/sig" 2>/dev/null)" int
  assert_contains "$(_visible "$(cat "$HOME/screen")")" "Stopping safely: Packages is given up to 15 seconds"
  local left; left="$(pgrep -f "sleep $_NAP" || true)"
  [[ -z "$left" ]] || { pkill -f "sleep $_NAP"; echo "the stage's sleep is left running: $left"; return 1; }
  # It stopped as soon as it could, not after the whole grace.
  (( SECONDS - start < 10 )) || { echo "took $(( SECONDS - start ))s"; return 1; }
}

# Another stage is not waited for.
test_ctrl_c_other_stages_are_not_gentle() {
  _prog
  _fake a 'trap "echo int >> \"\$HOME/sig\"" INT; '"sleep $_NAP"' >/dev/null 2>&1 & wait; wait'
  _bg_run a
  local pid=$_BG rc=0
  _until_running "sleep $_NAP" || { kill -9 "$pid"; return 1; }
  kill -INT "$pid"
  wait "$pid" || rc=$?
  assert_eq "$rc" 130
  [[ ! -e "$HOME/sig" ]] || { echo "INT sent to a stage that is not packages or boot"; return 1; }
  [[ "$(cat "$HOME/screen")" != *"Stopping safely"* ]]
  pkill -f "sleep $_NAP" || true
}

# A stage stopped for a password: the prompt says not to type it here, the
# cursor is on Show log, and letters typed then (the password going on) are
# no buttons: "s" does not skip, and the end of the keys quits.
test_password_prompt_letters_are_not_buttons() {
  _prog
  _fake a 'echo before; kill -TTIN "$BASHPID"'
  _keys s
  local rc=0
  progress_run a > /dev/null || rc=$?
  assert_eq "$rc" 1
  assert_eq "$(_status a)" fail
  local screen; screen="$(_visible "$(cat "$HOME/screen")")"
  assert_contains "$screen" "A command asked for a password on the terminal. Do not type it"
  assert_contains "$screen" "[ Show log ]"
}

# ...and what was typed before the prompt came up is dropped: an Enter typed
# into sudo's prompt does not take the button. The keys come through a pipe,
# as from a terminal: the Enter is there before the prompt, the q later.
test_password_prompt_drops_what_was_typed() {
  _prog
  _fake a 'echo before; kill -TTIN "$BASHPID"'
  local fifo="$HOME/keys.pipe"
  mkfifo "$fifo"
  TUI_IN="$fifo"
  ( exec 7<>"$fifo"; printf '\n' >&7; sleep 5; printf 'q' >&7; sleep 2 ) &
  local writer=$! rc=0
  progress_run a > /dev/null || rc=$?
  kill "$writer" 2>/dev/null || true
  assert_eq "$rc" 1
  # The Enter took nothing: Retry would have run the stage again, Show log
  # would have left the view and come back to it.
  assert_eq "$(grep -c '^before$' "$VITRUM_LOG")" 1
  assert_eq "$(grep -o $'\e\\[?1049h' "$HOME/screen" | wc -l | tr -d ' ')" 1
}
