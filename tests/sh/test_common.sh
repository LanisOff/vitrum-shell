# shellcheck shell=bash disable=SC1090,SC1091,SC2016,SC2059,SC2329
test_paths_are_vitrum() {
  source "$VITRUM_DIR/lib/common.sh"
  assert_eq "$VITRUM_PREFIX" "$HOME/.config/vitrum"
  assert_eq "$VITRUM_STATE" "$HOME/.local/share/vitrum"
  assert_contains "$BUILD_DIR" "vitrum-build"
}
test_dry_run_writes_nothing() {
  export DRY_RUN=1; source "$VITRUM_DIR/lib/common.sh"
  printf 'hello\n' | write_file "$HOME/x.txt"
  [[ ! -e "$HOME/x.txt" ]]
}
test_repo_version_reads_VERSION() {
  source "$VITRUM_DIR/lib/common.sh"
  assert_eq "$(vitrum_repo_version)" "$(cat "$VITRUM_DIR/VERSION")"
}
test_cpu_count_without_nproc() {
  PATH="$STUBS:$(dirname "$BASH"):/usr/bin:/bin"; stub nproc 'exit 127'
  source "$VITRUM_DIR/lib/common.sh"
  n="$(cpu_count)"; [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 ))
}
# One password for the whole run: sudo -v once, then a background refresher;
# a second call (preflight after install.sh started it) asks nothing more.
test_sudo_keepalive_asks_once() {
  stub sudo 'echo "sudo $*" >> "$HOME/calls"'
  source "$VITRUM_DIR/lib/common.sh"
  sudo_keepalive; sudo_keepalive
  [[ -n "$SUDO_KEEPALIVE" ]] && kill -0 "$SUDO_KEEPALIVE"
  kill "$SUDO_KEEPALIVE"
  assert_eq "$(grep -c "sudo -v" "$HOME/calls")" 1
}
test_sudo_keepalive_nothing_in_dry_run() {
  stub sudo 'echo "sudo $*" >> "$HOME/calls"'
  export DRY_RUN=1
  source "$VITRUM_DIR/lib/common.sh"
  sudo_keepalive
  [[ -z "${SUDO_KEEPALIVE:-}" && ! -e "$HOME/calls" ]]
}
# A printf that behaves like glibc bash's without a UTF-8 locale: \u escapes
# come back verbatim until LC_ALL names one ($1 lists the locales that work).
_fake_locale() {
  _works="$1"
  printf() {
    if [[ "$1" == '\u2713' && " $_works " != *" ${LC_ALL:-none} "* ]]; then builtin printf '%s' '\u2713'
    else builtin printf "$@"; fi
  }
  locale() { builtin printf 'C\nC.utf8\nPOSIX\nen_GB.utf8\n'; }
}
test_missing_locale_borrows_a_utf8_one() {
  unset LC_ALL LC_CTYPE; export LANG=xx_XX.UTF-8
  _fake_locale "C.UTF-8"
  source "$VITRUM_DIR/lib/common.sh"
  assert_eq "$VITRUM_LOCALE_MISSING" "xx_XX.UTF-8 (LANG)"
  assert_eq "$LC_ALL" C.UTF-8
  assert_eq "$G_OK" "$(builtin printf '✓')"
}
test_missing_locale_falls_through_to_locale_a() {
  unset LC_ALL LC_CTYPE; export LANG=xx_XX.UTF-8
  _fake_locale "en_GB.utf8"
  source "$VITRUM_DIR/lib/common.sh"
  assert_eq "$LC_ALL" en_GB.utf8
}
test_no_utf8_locale_at_all_keeps_markers_ascii() {
  unset LC_ALL LC_CTYPE; export LANG=xx_XX.UTF-8
  _fake_locale ""
  source "$VITRUM_DIR/lib/common.sh"
  [[ -z "${LC_ALL:-}" ]]
  assert_eq "$G_OK$G_ERR$G_STEP" "+x-"
  ui_icons
  assert_eq "$G_OK" "+"
}
test_working_locale_is_left_alone() {
  source "$VITRUM_DIR/lib/common.sh"
  [[ -z "${VITRUM_LOCALE_MISSING:-}" ]]
}
test_missing_locale_names_the_variable_that_is_missing() {
  unset LC_ALL; export LC_CTYPE=C.UTF-8 LANG=en_US.UTF-8
  _fake_locale "C.UTF-8"
  source "$VITRUM_DIR/lib/common.sh"
  assert_eq "$VITRUM_LOCALE_MISSING" "en_US.UTF-8 (LANG)"
}

# Under the progress view nothing may stop for an answer: confirm takes the
# default without reading, and says so in the log.
test_confirm_does_not_block_under_progress() {
  source "$VITRUM_DIR/lib/common.sh"
  local fifo="$HOME/fifo" pid i rc=0
  mkfifo "$fifo"
  # Opened read-write, so the open itself does not wait for a writer; reading
  # it would wait for ever.
  ( VITRUM_PROGRESS=1 confirm "x?" n > "$HOME/out" ) <>"$fifo" &
  pid=$!
  for (( i = 0; i < 20; i++ )); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid"; echo "confirm waited for an answer"; return 1; fi
  wait "$pid" || rc=$?
  assert_eq "$rc" 1
  assert_contains "$(cat "$HOME/out")" "(asked: x? — took n)"
  ( VITRUM_PROGRESS=1 confirm "y?" y > /dev/null ) <>"$fifo" || { echo "default y did not give 0"; return 1; }
}

# Under the progress view each stage runs in a subshell: what it warns about,
# its step and its last words go to files the view and the final screen read.
test_run_dir_records() {
  source "$VITRUM_DIR/lib/common.sh"
  export VITRUM_RUN_DIR="$HOME/run" VITRUM_STAGE_KEY=fonts
  mkdir -p "$VITRUM_RUN_DIR"
  ( warn "low on %s" disk; err "broken %s" x; step "fetching Inter" ) 2>/dev/null >/dev/null
  assert_eq "$(cat "$VITRUM_RUN_DIR/warnings")" "low on disk"
  assert_eq "$(cat "$VITRUM_RUN_DIR/errors")" "broken x"
  assert_eq "$(cat "$VITRUM_RUN_DIR/fonts.step")" "fetching Inter"
  ( die "no network for %s" Inter ) >/dev/null 2>&1 && return 1
  assert_eq "$(cat "$VITRUM_RUN_DIR/fonts.error")" "no network for Inter"
  # Without a run directory nothing is written anywhere.
  unset VITRUM_RUN_DIR
  warn "elsewhere" 2>/dev/null
  ! grep -rq elsewhere "$HOME/run"
}

# The keepalive's EXIT trap runs the one set before it (the screens' restore).
test_sudo_keepalive_keeps_an_earlier_exit_trap() {
  stub sudo 'exit 0'
  source "$VITRUM_DIR/lib/common.sh"
  trap 'echo earlier' EXIT
  sudo_keepalive
  local t; t="$(trap -p EXIT)"
  kill "$SUDO_KEEPALIVE"
  trap - EXIT
  assert_contains "$t" "echo earlier"
  assert_contains "$t" 'kill "$SUDO_KEEPALIVE"'
}

# The test hooks are dropped unless VITRUM_TEST=1.
test_hooks_are_dropped_without_vitrum_test() {
  local v out
  out="$(env -u VITRUM_TEST VITRUM_SKIP_STAGES_FOR_TEST=1 VITRUM_FORCE_TUI=1 TUI_IN=k TUI_OUT=s \
    VITRUM_ROOTFS=/r VITRUM_SYSROOT=/s VITRUM_RUNTIME_PREFIX=/p VITRUM_NIRI_BIN=/n bash -c '
      source "$VITRUM_DIR/lib/common.sh"
      for v in VITRUM_SKIP_STAGES_FOR_TEST VITRUM_FORCE_TUI TUI_IN TUI_OUT VITRUM_ROOTFS VITRUM_SYSROOT VITRUM_RUNTIME_PREFIX VITRUM_NIRI_BIN; do
        printf "%s=%s\n" "$v" "${!v-unset}"
      done')"
  for v in VITRUM_SKIP_STAGES_FOR_TEST VITRUM_FORCE_TUI TUI_IN TUI_OUT VITRUM_ROOTFS VITRUM_SYSROOT VITRUM_RUNTIME_PREFIX VITRUM_NIRI_BIN; do
    assert_contains "$out" "$v=unset" || return 1
  done
  # With it, they stay.
  out="$(VITRUM_SKIP_STAGES_FOR_TEST=1 bash -c 'source "$VITRUM_DIR/lib/common.sh"; echo "${VITRUM_SKIP_STAGES_FOR_TEST-unset}"')"
  assert_eq "$out" 1
}

# install.json: a complete run records its version and revision; a partial
# one keeps the last complete one's, and says it is not complete.
test_record_install_partial_keeps_the_last_complete() {
  source "$VITRUM_DIR/lib/common.sh"
  DRY_RUN=0
  vitrum_checkout_revision() { printf 'aaa111\n'; }
  record_install
  local f="$VITRUM_STATE/install.json"
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f"
  assert_contains "$(cat "$f")" '"revision": "aaa111"'
  assert_contains "$(cat "$f")" '"complete": true'
  ! vitrum_install_pending || { echo "pending right after a complete install"; return 1; }
  vitrum_checkout_revision() { printf 'bbb222\n'; }
  vitrum_install_pending || { echo "a new revision not pending"; return 1; }
  printf '{\n  "version": "0.3.0",\n  "revision": "aaa111"\n}\n' > "$f"
  record_install 1
  assert_contains "$(cat "$f")" '"revision": "aaa111"'
  assert_contains "$(cat "$f")" '"version": "0.3.0"'
  assert_contains "$(cat "$f")" '"complete": false'
  # A first install that was partial names no revision at all.
  rm -f "$f"
  record_install 1
  assert_contains "$(cat "$f")" '"revision": ""'
  vitrum_install_pending
}
