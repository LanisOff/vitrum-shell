# shellcheck shell=bash disable=SC1090,SC1091
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
test_components_round_trip_new_keys() {
  source "$VITRUM_DIR/lib/common.sh"
  WANT_SDDM=0 WANT_PLYMOUTH=1 WANT_LIVE_WALLPAPER=0 WANT_TMUX=1 WANT_NVIM=0 WANT_TMUX_AUTOSTART=0
  save_components
  WANT_SDDM="" WANT_PLYMOUTH="" WANT_LIVE_WALLPAPER="" WANT_TMUX=""
  load_components
  assert_eq "$WANT_SDDM/$WANT_PLYMOUTH/$WANT_LIVE_WALLPAPER/$WANT_TMUX" "0/1/0/1"
}
test_cpu_count_without_nproc() {
  PATH="$STUBS:$(dirname "$BASH"):/usr/bin:/bin"; stub nproc 'exit 127'
  source "$VITRUM_DIR/lib/common.sh"
  n="$(cpu_count)"; [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 ))
}
test_components_remember_the_tmux_keys() {
  # vitrum's tmux keys or tmux's own: asked once, then repeated on updates.
  source "$VITRUM_DIR/lib/common.sh"
  WANT_TMUX=1 WANT_TMUX_KEYS=default; save_components
  assert_contains "$(cat "$(components_file)")" '"tmux_keys": "default"'
  WANT_TMUX_KEYS=""; load_components
  assert_eq "$WANT_TMUX_KEYS" default
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
