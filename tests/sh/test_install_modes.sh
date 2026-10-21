# shellcheck shell=bash disable=SC1090,SC1091,SC2016,SC2031,SC2034,SC2329
# install.sh's flow: which screens a run shows (fresh, update, --choose, --yes),
# what it remembers, and the final screen. Against a stub Arch world, as
# test_matrix.sh does.

_world() {
  PATH="$STUBS:$(dirname "$BASH"):/usr/bin:/bin:/usr/sbin:/sbin"
  stub uname "echo Linux"
  local c
  for c in sudo systemctl fc-cache lspci qs git; do
    stub "$c" "echo \"$c \$*\" >> \"\$CALLS\"; exit 0"
  done
  # Everything installed and available, so a run that is not dry has nothing
  # to put back.
  stub pacman "echo \"pacman \$*\" >> \"\$CALLS\"; exit 0"
  export CALLS; CALLS="$(mktemp)"
  local rootfs; rootfs="$(mktemp -d)"
  mkdir -p "$rootfs/run/systemd/system"
  export VITRUM_ROOTFS="$rootfs"
  mkdir -p "$XDG_DATA_HOME/vitrum"
  unset VITRUM_FORCE_TUI TUI_IN TUI_OUT VITRUM_SKIP_STAGES_FOR_TEST ASSUME_YES
}

# _head <rev> — git says the checkout is at that revision.
_head() {
  stub git "echo \"git \$*\" >> \"\$CALLS\"; case \"\$*\" in *'rev-parse HEAD'*) echo $1 ;; esac; exit 0"
}

# _installed — the marker of an existing install.
_installed() {
  printf '{"version": "0.3.0"}\n' > "$XDG_DATA_HOME/vitrum/install.json"
}

# _v2 <python expression changing d> — a v2 components.json with every part
# known and ticked, then changed as given.
_v2() {
  python3 - "$XDG_DATA_HOME/vitrum/components.json" "${1:-}" "$VITRUM_DIR" <<'PY'
import json, subprocess, sys
ids = subprocess.run(["bash", "-c", 'export VITRUM_DIR="$1"; source "$1/lib/common.sh"; component_ids', "_", sys.argv[3]],
                     capture_output=True, text=True, check=True).stdout.split()
d = {"version": 2, "language": "en", "terminal": "kitty", "shell": "fish", "fastfetch_logo": "picture", "known": list(ids)}
for i in ids:
    d[i] = True
exec(sys.argv[2])
json.dump(d, open(sys.argv[1], "w"), indent=1)
PY
}

# _tui_run <args…> — install.sh with the screens forced on, keys from
# $HOME/keys (empty unless a test wrote some), the screens into $HOME/screen.
_tui_run() {
  [[ -e "$HOME/keys" ]] || : > "$HOME/keys"
  : > "$HOME/screen"
  ( cd "$VITRUM_DIR" && VITRUM_FORCE_TUI=1 TUI_IN="$HOME/keys" TUI_OUT="$HOME/screen" ./install.sh "$@" ) \
    > "$HOME/out" 2>&1
}

_visible() { sed $'s/\e\\[[0-9;?]*[A-Za-z]//g' "$@"; }

# Every asset in place, so a run that is not dry fetches no font.
_assets_in_place() {
  ( source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/assets.sh"
    local a _a_url _a_sum _a_kind _a_dest
    mkdir -p "$VITRUM_STATE/assets"
    for a in $(asset_names); do
      _asset_row "$a"
      mkdir -p "$(dirname "$_a_dest")"; touch "$_a_dest"
      printf '%s' "$_a_sum" > "$VITRUM_STATE/assets/$a.sha256"
    done )
}

test_yes_runs_without_screens_on_a_fresh_home() {
  _world
  local rc=0
  ( cd "$VITRUM_DIR" && ./install.sh --dry-run --yes --only terminal ) > "$HOME/out" 2>&1 || rc=$?
  assert_eq "$rc" 0 || { tail -20 "$HOME/out"; return 1; }
  ! grep -q $'\e\\[?1049h' "$HOME/out" || { echo "a screen under --yes"; return 1; }
  assert_contains "$(cat "$HOME/out")" "This run"
  [[ ! -e "$XDG_DATA_HOME/vitrum/components.json" ]] || { echo "components.json written in a dry run"; return 1; }
}

test_update_with_nothing_new_shows_no_screen() {
  _world; _installed; _v2
  export VITRUM_LOG="$HOME/log"; : > "$VITRUM_LOG"
  _tui_run --dry-run --only terminal || { tail -20 "$HOME/out"; return 1; }
  local screen; screen="$(_visible "$HOME/screen")"
  [[ "$screen" != *"what to install"* ]] || { echo "the choice screen in a quiet update"; return 1; }
  [[ "$screen" != *"ready to install"* ]] || { echo "the confirmation in a quiet update"; return 1; }
  # Straight to the progress view, then the final screen in the output.
  assert_contains "$screen" "Terminal"
  assert_contains "$(cat "$HOME/out")" "is updated"
  # No banner and no "This run" block on the interactive path's screen; the
  # log has both, so it still says what the run was.
  [[ "$(cat "$HOME/out")" != *"This run"* ]] || { echo "the line-by-line summary under the screens"; return 1; }
  local log; log="$(_visible "$VITRUM_LOG")"
  assert_contains "$log" "This run"
  assert_contains "$log" "update from 0.3.0"
  assert_contains "$log" "packages: pacman, init: systemd"
  assert_contains "$log" "parts"
  [[ "$log" != *$'\e[?1049h'* ]] || { echo "a screen in the log"; return 1; }
}

test_update_offers_new_and_unticked_only() {
  _world; _installed
  _v2 'd["known"].remove("ocr"); del d["ocr"]; d["plymouth"] = False'
  # No keys: the choice screen is left at once, nothing done.
  local rc=0
  _tui_run --dry-run || rc=$?
  assert_eq "$rc" 0 || { tail -20 "$HOME/out"; return 1; }
  local screen; screen="$(_visible "$HOME/screen")"
  assert_contains "$screen" "what to install"
  assert_contains "$screen" "Text from screenshots"
  assert_contains "$screen" "Boot splash"
  [[ "$screen" != *"Login screen"* ]] || { echo "an item neither new nor unticked"; return 1; }
  assert_contains "$(cat "$HOME/out")" "Nothing done."
}

# Enter on the short screen and on the confirmation: the update runs with
# the new item at its default, the unticked one still unticked.
test_update_screen_then_confirmation_then_progress() {
  _world; _installed; _assets_in_place
  _v2 'd["known"].remove("ocr"); del d["ocr"]; d["plymouth"] = False'
  export VITRUM_SKIP_STAGES_FOR_TEST=1
  printf '\n\n' > "$HOME/keys"
  _tui_run --dry-run || { tail -20 "$HOME/out"; return 1; }
  local screen; screen="$(_visible "$HOME/screen")"
  assert_contains "$screen" "ready to install"
  assert_contains "$screen" "11/11"
  local out; out="$(_visible "$HOME/out")"
  assert_contains "$out" "is updated"
  # OCR is new and ticked, so it is installed; the unticked one is not.
  local yes="${out#*Installed:}"; yes="${yes%%Not installed:*}"
  assert_contains "$yes" "OCR"
  assert_contains "${out#*Not installed:}" "Boot splash"
}

# A partial run (--only, --from, --skip) is about its stages: no short list
# and no confirmation, whatever is unticked. --choose still brings the screen
# (test_choose_shows_everything).
test_partial_update_shows_no_screens() {
  _world; _installed
  _v2 'd["known"].remove("ocr"); del d["ocr"]; d["plymouth"] = False'
  local flags
  for flags in "--only terminal" "--from doctor" "--skip niri --skip packages --skip fonts --skip shell --skip apps --skip theming --skip boot --skip session --skip doctor --skip preflight"; do
    # shellcheck disable=SC2086  # the flags are words
    _tui_run --dry-run $flags || { tail -20 "$HOME/out"; return 1; }
    local screen; screen="$(_visible "$HOME/screen")"
    [[ "$screen" != *"what to install"* ]] || { echo "the choice screen under $flags"; return 1; }
    [[ "$screen" != *"ready to install"* ]] || { echo "the confirmation under $flags"; return 1; }
    assert_contains "$(cat "$HOME/out")" "is updated" || return 1
  done
}

# Esc on the update's short list keeps the choices as they were (a tick made
# there is undone) and goes on with the update, without the confirmation.
test_update_esc_keeps_choices_and_goes_on() {
  _world; _installed; _assets_in_place
  _v2 'd["known"].remove("ocr"); del d["ocr"]; d["plymouth"] = False'
  export VITRUM_SKIP_STAGES_FOR_TEST=1
  # Space on every row, so whichever the cursor is on is changed, then Esc.
  printf ' \e[B \e' > "$HOME/keys"
  _tui_run || { tail -20 "$HOME/out"; return 1; }
  local out; out="$(_visible "$HOME/out")"
  assert_contains "$out" "Your choices are kept as they were; the update goes on."
  assert_contains "$out" "is updated"
  [[ "$(_visible "$HOME/screen")" != *"ready to install"* ]] || { echo "the confirmation after Esc"; return 1; }
  local f; f="$(cat "$XDG_DATA_HOME/vitrum/components.json")"
  assert_contains "$f" '"plymouth": false'
  assert_contains "$f" '"ocr": true'
}

# Cancel on the update's confirmation leaves, and says the pulled update is
# still to be installed. A first install's Cancel says no such thing.
test_update_cancel_says_how_to_finish() {
  _world; _installed; _head abc123
  _v2 'd["plymouth"] = False'
  printf '\n\e[C\e[C\n' > "$HOME/keys"
  local rc=0
  _tui_run --dry-run || rc=$?
  assert_eq "$rc" 0
  local out; out="$(cat "$HOME/out")"
  assert_contains "$out" "Nothing done."
  assert_contains "$out" "to install it later: vitrum update"
}

test_migrated_author_setup_needs_no_answers() {
  _world; _installed; _assets_in_place
  cat > "$XDG_DATA_HOME/vitrum/components.json" <<'EOF'
{
  "starship": true, "fish": true, "kitty": true, "fastfetch": true,
  "tmux": true, "tmux_autostart": true, "tmux_keys": "vitrum", "nvim": true,
  "sddm": true, "plymouth": true, "live_wallpaper": true, "extras": true, "phone": true
}
EOF
  export VITRUM_SKIP_STAGES_FOR_TEST=1
  _tui_run --only terminal || { tail -30 "$HOME/out"; return 1; }
  [[ "$(_visible "$HOME/screen")" != *"what to install"* ]] || { echo "a migrated install was asked"; return 1; }
  local f; f="$(cat "$XDG_DATA_HOME/vitrum/components.json")"
  assert_contains "$f" '"version": 2'
  assert_contains "$f" '"author_nvim": true'
  assert_contains "$f" '"author_tmux_keys": true'
  assert_contains "$f" '"tmux_autostart": true'
  assert_contains "$f" '"cli_tools": true'
  # An update is no first login: no welcome tour.
  [[ ! -e "$XDG_DATA_HOME/vitrum/welcome" ]] || { echo "welcome marker after an update"; return 1; }
}

test_old_flags() {
  _world
  local rc=0
  ( cd "$VITRUM_DIR" && ./install.sh --no-extras --tmux-keys=default --with-nvim --yes --dry-run --only terminal ) \
    > "$HOME/out" 2>&1 || rc=$?
  assert_eq "$rc" 0 || { tail -20 "$HOME/out"; return 1; }
  local summary; summary="$(_visible "$HOME/out" | sed -n '/This run/,/^$/p')"
  assert_contains "$summary" "author_nvim"
  assert_contains "$summary" "tmux keys"
  assert_contains "$(grep 'tmux keys' <<<"$summary")" default
  [[ "$summary" != *games* && "$summary" != *utilities* ]] || { echo "extras in the summary: $summary"; return 1; }
}

test_finish_lists_warnings_once() {
  export NO_COLOR=1
  source "$VITRUM_DIR/lib/common.sh"
  source "$VITRUM_DIR/lib/screens/finish.sh"
  components_defaults
  VITRUM_RUN_DIR="$HOME/run"; mkdir -p "$VITRUM_RUN_DIR"
  printf 'low disk\nlow disk\nslow mirror\n' > "$VITRUM_RUN_DIR/warnings"
  PROGRESS_STAGES=(packages shell apps session)
  printf 'skip\n' > "$VITRUM_RUN_DIR/packages.status"
  printf 'needs\n' > "$VITRUM_RUN_DIR/shell.status"; printf 'packages\n' > "$VITRUM_RUN_DIR/shell.needs"
  printf 'needs\n' > "$VITRUM_RUN_DIR/apps.status"; printf 'shell\n' > "$VITRUM_RUN_DIR/apps.needs"
  printf 'ok\n' > "$VITRUM_RUN_DIR/session.status"
  INSTALL_MODE=update CONFIRM_INSTALLED="sddm plymouth"
  component_set sddm 0
  local out; out="$(finish_render)"
  assert_eq "$(grep -c 'low disk' <<<"$out")" 1
  assert_contains "$out" "slow mirror"
  assert_contains "$out" "Mod+/"
  assert_contains "$out" "Mod+Space"
  assert_contains "$out" "Mod+Alt+W"
  assert_contains "$out" "vitrum update"
  assert_contains "$out" "is updated"
  assert_contains "$out" "Skipped: Packages — not run without it: Shell, Apps"
  assert_contains "$out" "To run it later: ./install.sh --from packages"
  assert_contains "$out" "no longer managed: Login screen"
  assert_contains "${out#*Not installed:}" "Phone"
}

# Fresh: language, choice, confirmation, then the progress view and the
# final screen; the welcome tour is promised once the session stage was ok.
test_fresh_flow_and_the_welcome_marker() {
  _world; _assets_in_place
  export VITRUM_SKIP_STAGES_FOR_TEST=1
  printf '\n\n\n' > "$HOME/keys"
  _tui_run --only session || { tail -30 "$HOME/out"; return 1; }
  local screen; screen="$(_visible "$HOME/screen")"
  assert_contains "$screen" "Choose a language"
  assert_contains "$screen" "what to install"
  assert_contains "$screen" "ready to install"
  assert_contains "$(cat "$HOME/out")" "is installed"
  [[ -e "$XDG_DATA_HOME/vitrum/welcome" ]] || { echo "no welcome marker after a clean fresh install"; return 1; }
  assert_contains "$(cat "$XDG_DATA_HOME/vitrum/components.json")" '"language": "en"'
}

# Without the session there is nothing to log in to: no tour promised.
test_no_welcome_marker_without_the_session() {
  _world; _assets_in_place
  export VITRUM_SKIP_STAGES_FOR_TEST=1
  printf '\n\n\n' > "$HOME/keys"
  _tui_run --only terminal || { tail -30 "$HOME/out"; return 1; }
  assert_contains "$(cat "$HOME/out")" "is installed"
  [[ ! -e "$XDG_DATA_HOME/vitrum/welcome" ]] || { echo "welcome marker without the session stage"; return 1; }
}

# Cancel on the confirmation: nothing is done and nothing remembered.
test_cancel_does_nothing() {
  _world
  printf '\n\n\e[D\n' > "$HOME/keys"
  local rc=0
  _tui_run --only terminal || rc=$?
  assert_eq "$rc" 0
  assert_contains "$(cat "$HOME/out")" "Nothing done."
  [[ "$(cat "$HOME/out")" != *"vitrum update"* ]] || { echo "an update hint on a first install"; return 1; }
  [[ ! -e "$XDG_DATA_HOME/vitrum/components.json" ]] || { echo "choices saved after Cancel"; return 1; }
}

# --choose: the whole screen again, with what was stored.
test_choose_shows_everything() {
  _world; _installed; _v2 'd["phone"] = False'
  local rc=0
  _tui_run --dry-run --choose --only terminal || rc=$?
  local screen; screen="$(_visible "$HOME/screen")"
  assert_contains "$screen" "Login screen (SDDM)"
  assert_contains "$screen" "[x] Neovim with the author's config"
  assert_contains "$screen" "[ ] Phone (KDE Connect)"
}

# vitrum install.json without components.json: what was chosen is unknown, so
# every item is offered.
test_install_without_components_offers_everything() {
  _world; _installed
  _tui_run --dry-run || true
  local screen; screen="$(_visible "$HOME/screen")"
  assert_contains "$screen" "what to install"
  assert_contains "$screen" "Login screen (SDDM)"
  assert_contains "$screen" "Neovim with the author's config"
}

test_help_lists_the_flags() {
  local out; out="$(cd "$VITRUM_DIR" && ./install.sh --help 2>&1)"
  local f
  for f in --update --choose --with-games --no-utilities --with-cli-tools --with-file-manager --with-ocr \
           --with-author-nvim --with-author-tmux-keys --no-tmux-autostart --with-extras --tmux-keys --check; do
    assert_contains "$out" "$f" || return 1
  done
  # Every system the installer supports, as detect.sh accepts them.
  for f in "Gentoo with OpenRC or systemd" "Arch with systemd" "Fedora 43 or newer with systemd" "Void (glibc) with runit"; do
    assert_contains "$out" "$f" || return 1
  done
}

# _login_world — fish on PATH, another login shell, the log in $HOME/log (the
# terminal stage's dry-run lines are in it, the progress view keeps them out
# of the output).
_login_world() {
  _world
  stub fish 'exit 0'
  export SHELL=/bin/bash VITRUM_LOG="$HOME/log"
  : > "$VITRUM_LOG"
}

# A stored "no" survives an update that asks nothing.
test_login_shell_no_survives_a_quiet_update() {
  _login_world; _installed; _v2 'd["login_shell"] = False'
  _tui_run --dry-run --only terminal || { tail -20 "$HOME/out"; return 1; }
  [[ "$(_visible "$HOME/screen")" != *"ready to install"* ]] || { echo "the update asked"; return 1; }
  assert_contains "$(cat "$VITRUM_LOG")" "left as /bin/bash"
  ! grep -q "would set fish as the login shell" "$VITRUM_LOG" || { echo "fish made the login shell"; return 1; }
}

# A file from an installer that never kept the answer, and an update with no
# screen: the login shell is left alone.
test_login_shell_unknown_in_a_quiet_update_is_left_alone() {
  _login_world; _installed
  cat > "$XDG_DATA_HOME/vitrum/components.json" <<'JSON'
{ "tmux": true, "tmux_autostart": true, "tmux_keys": "vitrum", "nvim": true, "sddm": true,
  "plymouth": true, "live_wallpaper": true, "extras": true, "phone": true }
JSON
  _tui_run --dry-run --only terminal || { tail -20 "$HOME/out"; return 1; }
  [[ "$(_visible "$HOME/screen")" != *"ready to install"* ]] || { echo "the update asked"; return 1; }
  assert_contains "$(cat "$VITRUM_LOG")" "left as /bin/bash"
}

# --yes on a first install keeps the old default: fish becomes the login shell.
test_login_shell_under_yes_is_fish() {
  _login_world
  ( cd "$VITRUM_DIR" && ./install.sh --dry-run --yes --only terminal ) > "$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  assert_contains "$(cat "$HOME/out")" "would set fish as the login shell"
}

# ...but that default is no answer: nothing about the login shell is stored.
test_login_shell_default_under_yes_is_not_stored() {
  _login_world; _assets_in_place
  export VITRUM_SKIP_STAGES_FOR_TEST=1
  ( cd "$VITRUM_DIR" && ./install.sh --yes --only terminal ) > "$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  local f; f="$(cat "$XDG_DATA_HOME/vitrum/components.json")"
  assert_contains "$f" '"version": 2'
  [[ "$f" != *login_shell* ]] || { echo "the --yes default stored as an answer"; return 1; }
}

# --check (what vitrum update runs when nothing is new) writes no choices: a
# v1 file stays a v1 file, and the quiet update after it leaves zsh alone.
test_check_writes_no_choices_and_the_next_update_leaves_the_shell() {
  _login_world; _installed; _assets_in_place
  export SHELL=/bin/zsh
  cat > "$XDG_DATA_HOME/vitrum/components.json" <<'JSON'
{ "tmux": true, "tmux_autostart": true, "tmux_keys": "vitrum", "nvim": true, "sddm": true,
  "plymouth": true, "live_wallpaper": true, "extras": true, "phone": true }
JSON
  local before; before="$(cat "$XDG_DATA_HOME/vitrum/components.json")"
  ( cd "$VITRUM_DIR" && ./install.sh --yes --check ) > "$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  assert_eq "$(cat "$XDG_DATA_HOME/vitrum/components.json")" "$before"
  _tui_run --dry-run --only terminal || { tail -20 "$HOME/out"; return 1; }
  assert_contains "$(cat "$VITRUM_LOG")" "left as /bin/zsh"
  ! grep -q "would set fish as the login shell" "$VITRUM_LOG" || { echo "fish made the login shell"; return 1; }
}

# --yes on an update changes no login shell either: there was no question.
test_login_shell_under_yes_in_an_update_is_left() {
  _login_world; _installed; _v2
  ( cd "$VITRUM_DIR" && ./install.sh --dry-run --yes --only terminal ) > "$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  assert_contains "$(cat "$HOME/out")" "left as /bin/bash"
}

# A yes stored at install time does not undo a switch to zsh made since.
test_stored_yes_does_not_undo_a_switch() {
  _login_world; _installed; _v2 'd["login_shell"] = True'
  export SHELL=/bin/zsh
  _tui_run --dry-run --only terminal || { tail -20 "$HOME/out"; return 1; }
  assert_contains "$(cat "$VITRUM_LOG")" "left as /bin/zsh"
  ! grep -q "would set fish as the login shell" "$VITRUM_LOG" || { echo "the stored yes was repeated"; return 1; }
}

# Fish already the login shell at install: no row, so nothing is stored, and
# a later switch away is not reverted by the updates.
test_no_row_no_stored_answer() {
  _login_world; _assets_in_place
  export SHELL="$STUBS/fish" VITRUM_SKIP_STAGES_FOR_TEST=1
  printf '\n\n\n' > "$HOME/keys"
  _tui_run --only terminal || { tail -30 "$HOME/out"; return 1; }
  [[ "$(_visible "$HOME/screen")" != *"login shell"* ]] || { echo "a login shell row with fish as the shell"; return 1; }
  [[ "$(cat "$XDG_DATA_HOME/vitrum/components.json")" != *login_shell* ]] || { echo "an answer stored for a row not shown"; return 1; }
}

# The row shown and answered: the answer is stored. In an update the row
# starts unticked, and ticking it there is what makes fish the login shell.
test_answered_row_is_stored() {
  _login_world; _assets_in_place
  export VITRUM_SKIP_STAGES_FOR_TEST=1
  printf '\n\n\n' > "$HOME/keys"
  _tui_run --only terminal || { tail -30 "$HOME/out"; return 1; }
  assert_contains "$(_visible "$HOME/screen")" "[x] Make fish my login shell (now bash)"
  assert_contains "$(cat "$XDG_DATA_HOME/vitrum/components.json")" '"login_shell": true'

  _v2 'd["plymouth"] = False; d["login_shell"] = False'
  printf '\n \n' > "$HOME/keys"
  _tui_run || { tail -30 "$HOME/out"; return 1; }
  assert_contains "$(_visible "$HOME/screen")" "[ ] Make fish my login shell (now bash)"
  assert_contains "$(cat "$XDG_DATA_HOME/vitrum/components.json")" '"login_shell": true'
}

# The update's row ticked on this run reaches the terminal stage.
test_update_row_ticked_sets_fish() {
  _login_world; _installed; _v2 'd["plymouth"] = False'
  printf '\n \n' > "$HOME/keys"
  _tui_run --dry-run || { tail -30 "$HOME/out"; return 1; }
  assert_contains "$(cat "$VITRUM_LOG")" "would set fish as the login shell"
}

# install.json: the revision installed, and only when the run was complete.
test_install_records_the_revision_only_when_complete() {
  _world; _installed; _v2; _assets_in_place
  export VITRUM_SKIP_STAGES_FOR_TEST=1
  local head=abc123
  _head "$head"
  _tui_run --only shell || { tail -20 "$HOME/out"; return 1; }
  local f; f="$(cat "$XDG_DATA_HOME/vitrum/install.json")"
  assert_contains "$f" '"complete": false'
  assert_contains "$f" '"version": "0.3.0"'
  assert_contains "$f" '"revision": ""'
  _tui_run || { tail -20 "$HOME/out"; return 1; }
  f="$(cat "$XDG_DATA_HOME/vitrum/install.json")"
  assert_contains "$f" '"complete": true'
  assert_contains "$f" "\"version\": \"$(cat "$VITRUM_DIR/VERSION")\""
  assert_contains "$f" "\"revision\": \"$head\""
  # A partial run after it keeps that revision.
  _tui_run --only shell || { tail -20 "$HOME/out"; return 1; }
  assert_contains "$(cat "$XDG_DATA_HOME/vitrum/install.json")" "\"revision\": \"$head\""
}

# The test hooks do nothing without VITRUM_TEST: the screens are not drawn
# into a file (lib/common.sh drops the rest; test_common.sh). The fake root
# goes too, so the run may well refuse this machine; that is not the point.
test_hooks_need_vitrum_test() {
  _world
  : > "$HOME/keys"; : > "$HOME/screen"
  ( cd "$VITRUM_DIR" && env -u VITRUM_TEST VITRUM_FORCE_TUI=1 TUI_IN="$HOME/keys" TUI_OUT="$HOME/screen" \
      VITRUM_SKIP_STAGES_FOR_TEST=1 ./install.sh --dry-run --only terminal ) > "$HOME/out" 2>&1 || true
  [[ ! -s "$HOME/screen" ]] || { echo "the screens went to TUI_OUT"; return 1; }
  ! grep -q $'\e\\[?1049h' "$HOME/out" || { echo "a screen drawn"; return 1; }
}

# A ticked part is listed as installed only when the stages that put it in
# place ran cleanly.
test_finish_lists_skipped_parts_as_not_installed() {
  export NO_COLOR=1
  source "$VITRUM_DIR/lib/common.sh"
  source "$VITRUM_DIR/lib/screens/finish.sh"
  components_defaults
  VITRUM_RUN_DIR="$HOME/run"; mkdir -p "$VITRUM_RUN_DIR"
  INSTALL_MODE=fresh
  PROGRESS_STAGES=(packages shell terminal boot)
  printf 'ok\n' > "$VITRUM_RUN_DIR/packages.status"
  printf 'ok\n' > "$VITRUM_RUN_DIR/shell.status"
  printf 'ok\n' > "$VITRUM_RUN_DIR/terminal.status"
  printf 'skip\n' > "$VITRUM_RUN_DIR/boot.status"
  local out yes no
  out="$(finish_render)"
  yes="${out#*Installed:}"; yes="${yes%%Not installed:*}"
  no="${out#*Not installed:}"
  assert_contains "$no" "Login screen (skipped)"
  assert_contains "$out" "To run it later: ./install.sh --only boot"
  [[ "$yes" != *"Login screen"* ]] || { echo "skipped SDDM listed as installed"; return 1; }
  assert_contains "$yes" "tmux"
  assert_contains "$yes" "Game mode"
  # A first install with --only: what the run did not do is not installed.
  PROGRESS_STAGES=(terminal)
  out="$(finish_render)"
  yes="${out#*Installed:}"; yes="${yes%%Not installed:*}"
  no="${out#*Not installed:}"
  assert_contains "$no" "Login screen (not in this run)"
  assert_contains "$no" "tmux (not in this run)"
  [[ "$yes" != *"tmux"* ]] || { echo "tmux listed as installed without its packages"; return 1; }
  # An update with --only: what was there before still is.
  INSTALL_MODE=update CONFIRM_INSTALLED="sddm tmux"
  out="$(finish_render)"
  yes="${out#*Installed:}"; yes="${yes%%Not installed:*}"
  assert_contains "$yes" "Login screen"
  assert_contains "$yes" "tmux"
  assert_contains "$yes" "kitty"
}
