# shellcheck shell=bash disable=SC1090,SC1091,SC2001,SC2034,SC2119,SC2329
# The screens (lib/screens/*.sh), drawn from a fake state with no terminal:
# the render functions print the frame, the key functions change the state.

_screens() {
  export NO_COLOR=1
  unset VITRUM_LANG
  source "$VITRUM_DIR/lib/common.sh"
  source "$VITRUM_DIR/lib/screens/choose.sh"
  components_defaults
}

# _down_to <id> — move the cursor down until it is on that item or pick.
_down_to() {
  local i
  for (( i = 0; i < 40; i++ )); do
    [[ "${CHOOSE_ROWS[CHOOSE_CURSOR]#*:}" == "$1" ]] && return 0
    choose_key down
  done
  echo "never reached $1"; return 1
}

_up_to() {
  local i
  for (( i = 0; i < 40; i++ )); do
    [[ "${CHOOSE_ROWS[CHOOSE_CURSOR]#*:}" == "$1" ]] && return 0
    choose_key up
  done
  echo "never reached $1"; return 1
}

# _in_order <text> <needle...> — each needle appears after the one before.
_in_order() {
  local rest="$1" n; shift
  for n in "$@"; do
    [[ "$rest" == *"$n"* ]] || { echo "[$n] missing or out of order"; return 1; }
    rest="${rest#*"$n"}"
  done
}

# _visible <text> — the text without its escape codes.
_visible() { sed $'s/\e\\[[0-9;?]*[A-Za-z]//g' <<<"$1"; }

test_fresh_screen_lists_groups_in_order() {
  _screens
  choose_init
  local out; out="$(_visible "$(choose_render)")"
  assert_contains "$out" "vitrum — what to install"
  _in_order "$out" "Terminal" "kitty" "Login screen (SDDM)" "Tools" "Extras — the author's own setup"
  assert_contains "$out" "[x] Login screen (SDDM)"
  assert_contains "$out" "[ ] Boot splash (Plymouth)"
  assert_contains "$out" "[ ] Neovim with the author's config"
  assert_contains "$out" "(•) kitty"
  assert_contains "$out" "(•) picture"
  assert_contains "$out" "( ) distribution logo"
}

test_rows_are_built_in_order() {
  _screens
  choose_init
  assert_eq "${CHOOSE_ROWS[*]:0:5}" "pick:terminal pick:shell pick:fastfetch_logo head:desktop item:sddm"
  assert_eq "${CHOOSE_ROWS[*]: -4}" "head:extras item:author_nvim item:author_tmux_keys item:tmux_autostart"
  assert_eq "$CHOOSE_CURSOR/$CHOOSE_TOP" 0/0
}

test_space_toggles_and_enter_finishes() {
  _screens
  choose_init
  _down_to plymouth
  choose_key space
  assert_eq "$(component_get plymouth)" 1
  choose_key space
  assert_eq "$(component_get plymouth)" 0
  local rc=0
  choose_key enter || rc=$?
  assert_eq "$rc" 10
  rc=0
  choose_key esc || rc=$?
  assert_eq "$rc" 11
}

test_up_and_down_skip_headings() {
  _screens
  choose_init
  _down_to fastfetch_logo
  choose_key down
  assert_eq "${CHOOSE_ROWS[CHOOSE_CURSOR]}" item:sddm
  choose_key up
  assert_eq "${CHOOSE_ROWS[CHOOSE_CURSOR]}" pick:fastfetch_logo
  # The ends stop the cursor.
  choose_key up; choose_key up; choose_key up
  assert_eq "$CHOOSE_CURSOR" 0
}

test_left_right_cycle_a_pick() {
  _screens
  choose_init
  _down_to fastfetch_logo
  choose_key right
  assert_eq "$VITRUM_FASTFETCH_LOGO" distro
  choose_key right
  assert_eq "$VITRUM_FASTFETCH_LOGO" picture
  choose_key left
  assert_eq "$VITRUM_FASTFETCH_LOGO" distro
  # A pick with one option stays as it is.
  choose_init
  choose_key right
  assert_eq "$VITRUM_TERMINAL" kitty
}

test_disabled_option_is_skipped_and_explained() {
  _screens
  pick_option_disabled() { [[ "$1:$2" == fastfetch_logo:picture ]]; }
  VITRUM_FASTFETCH_LOGO=distro
  choose_init
  _down_to fastfetch_logo
  choose_key right
  assert_eq "$VITRUM_FASTFETCH_LOGO" distro
  choose_key left
  assert_eq "$VITRUM_FASTFETCH_LOGO" distro
  assert_contains "$(choose_hint fastfetch_logo)" "kitty cannot show images"
}

test_untick_tmux_drops_its_dependents() {
  _screens
  component_set tmux_autostart 1
  choose_init
  _down_to tmux
  choose_key space
  assert_eq "$(component_get tmux)/$(component_get tmux_autostart)/$(component_get author_tmux_keys)" 0/0/0
  _down_to tmux_autostart
  choose_key space
  assert_eq "$(component_get tmux_autostart)" 0
  local out; out="$(_visible "$(choose_render)")"
  assert_contains "$out" "[ ] Start tmux with every terminal  (needs tmux)"
  assert_contains "$(choose_hint tmux_autostart)" "tmux, themed, with plugins"
  # With tmux back, the dependent toggles again.
  _up_to tmux
  choose_key space
  _down_to tmux_autostart
  choose_key space
  assert_eq "$(component_get tmux_autostart)" 1
}

# --no-tmux --tmux-autostart: the screen opens with autostart off, as the
# stage would leave it.
test_init_turns_off_what_cannot_be_on() {
  _screens
  component_set tmux 0; component_set tmux_autostart 1
  choose_init
  assert_eq "$(component_get tmux_autostart)" 0
}

test_group_toggle() {
  _screens
  choose_init
  _down_to games
  local tools="tmux games utilities cli_tools file_manager ocr" id got
  choose_key a
  got=""; for id in $tools; do got+="$(component_get "$id")"; done
  assert_eq "$got" 000000
  choose_key a
  got=""; for id in $tools; do got+="$(component_get "$id")"; done
  assert_eq "$got" 111111
  # Some ticked is not all ticked: a ticks the rest.
  component_set ocr 0
  choose_key a
  assert_eq "$(component_get ocr)" 1
  # The other groups were left alone.
  assert_eq "$(component_get sddm)/$(component_get author_nvim)" 1/0
}

# The same key on a Russian layout.
test_group_key_on_a_russian_layout() {
  _screens
  choose_init
  _down_to games
  choose_key ф
  assert_eq "$(component_get games)$(component_get ocr)" 00
  choose_key Ф
  assert_eq "$(component_get games)$(component_get ocr)" 11
}

# The end of the input leaves both screens instead of sending one to the
# other: Esc on the choice goes back, Change on the confirmation comes back.
test_end_of_input_leaves_the_screens() {
  _screens
  source "$VITRUM_DIR/lib/screens/confirm.sh"
  FACT_FREE_MB=100000 FACT_NIRI_BUILD=0 FACT_FISH_IS_SHELL=1 FACT_DM=""
  TUI_OUT="$HOME/screen" TUI_IN="$HOME/keys"
  : > "$TUI_IN"
  local rc=0
  choose_run || rc=$?
  assert_eq "$rc" 2
  rc=0; confirm_run || rc=$?
  assert_eq "$rc" 2
  rc=0; choose_key eof || rc=$?
  assert_eq "$rc" 12
  rc=0; confirm_key eof || rc=$?
  assert_eq "$rc" 22
}

test_group_toggle_leaves_what_cannot_be_ticked() {
  _screens
  component_set tmux 0
  choose_init
  _down_to author_nvim
  choose_key a
  assert_eq "$(component_get author_nvim)/$(component_get author_tmux_keys)/$(component_get tmux_autostart)" 1/0/0
  # Everything that can be ticked is, so a second a unticks.
  choose_key a
  assert_eq "$(component_get author_nvim)" 0
}

test_update_mode_shows_only_given_ids() {
  _screens
  choose_init ocr plymouth
  assert_eq "${CHOOSE_ROWS[*]}" "head:desktop item:plymouth head:tools item:ocr"
  assert_eq "${CHOOSE_ROWS[CHOOSE_CURSOR]}" item:plymouth
  local out; out="$(_visible "$(choose_render)")"
  assert_contains "$out" "Text from screenshots"
  assert_contains "$out" "Boot splash"
  assert_contains "$out" "Tools"
  assert_contains "$out" "Desktop"
  [[ "$out" != *"Login screen"* ]] || { echo "Login screen shown"; return 1; }
  [[ "$out" != *"Terminal"* ]] || { echo "Terminal shown"; return 1; }
}

test_small_terminal_scrolls() {
  _screens
  TUI_ROWS=12
  choose_init
  local i
  for (( i = 0; i < 12; i++ )); do choose_key down; done
  choose_render > "$HOME/frame"
  local lines; lines="$(wc -l < "$HOME/frame" | tr -d ' ')"
  (( lines <= 12 )) || { echo "$lines lines"; cat "$HOME/frame"; return 1; }
  local id="${CHOOSE_ROWS[CHOOSE_CURSOR]#item:}"
  assert_contains "$(_visible "$(cat "$HOME/frame")")" "$(choose_label "$id")"
  (( CHOOSE_TOP > 0 )) || { echo "did not scroll"; return 1; }
  # Back up to the top, and the first rows are in view again.
  for (( i = 0; i < 12; i++ )); do choose_key up; done
  choose_render > "$HOME/frame"
  assert_eq "$CHOOSE_TOP" 0
  assert_contains "$(cat "$HOME/frame")" "Terminal"
}

# 24 rows by 60 columns: nothing is wider than the terminal, so nothing
# wraps, in either language (the Russian labels are the longer ones).
test_narrow_terminal_fits() {
  _screens
  TUI_ROWS=24 TUI_COLS=60
  local lang line n
  for lang in en ru; do
    VITRUM_LANG=$lang
    choose_init
    _down_to author_tmux_keys
    n=0
    while IFS= read -r line; do
      n=$((n + 1))
      line="$(_visible "$line")"
      (( ${#line} <= 60 )) || { echo "$lang: line $n is ${#line} wide: [$line]"; return 1; }
    done < <(choose_render)
    (( n <= 24 )) || { echo "$lang: $n lines"; return 1; }
  done
}

test_russian_render() {
  _screens
  VITRUM_LANG=ru
  choose_init
  local out; out="$(choose_render)"
  assert_contains "$out" "${I18N_RU[Desktop]}"
  assert_contains "$out" "${I18N_RU['Login screen (SDDM)']}"
}

test_every_item_has_a_label_and_a_hint() {
  _screens
  local id
  for id in $(component_ids) terminal shell fastfetch_logo; do
    [[ -n "$(choose_label "$id")" ]] || { echo "no label for $id"; return 1; }
    [[ -n "$(choose_hint "$id")" ]] || { echo "no hint for $id"; return 1; }
  done
}

test_choose_run_loop() {
  _screens
  TUI_OUT="$HOME/screen" TUI_IN="$HOME/keys"
  # Down past the three picks to SDDM, untick it, Enter.
  printf '%s' $'\e[B\e[B\e[B \n' > "$TUI_IN"
  choose_run
  assert_eq "$(component_get sddm)" 0
  assert_contains "$(cat "$HOME/screen")" "Login screen (SDDM)"
  printf '%s' $'\e' > "$TUI_IN"
  local rc=0
  choose_run || rc=$?
  assert_eq "$rc" 1
}

test_language_preselect() {
  _screens
  source "$VITRUM_DIR/lib/screens/language.sh"
  TUI_OUT="$HOME/screen" TUI_IN="$HOME/keys"
  printf '\n' > "$TUI_IN"
  VITRUM_DEVICE_LOCALE=ru_RU.UTF-8; unset VITRUM_LANG
  language_run
  assert_eq "$VITRUM_LANG" ru
  VITRUM_DEVICE_LOCALE=C; unset VITRUM_LANG
  language_run
  assert_eq "$VITRUM_LANG" en
  # Down and Enter picks the other one.
  printf '%s' $'\e[B\n' > "$TUI_IN"
  unset VITRUM_LANG
  language_run
  assert_eq "$VITRUM_LANG" ru
  assert_contains "$(cat "$HOME/screen")" "Русский"
}

test_language_escape_quits() {
  _screens
  source "$VITRUM_DIR/lib/screens/language.sh"
  TUI_OUT="$HOME/screen" TUI_IN="$HOME/keys"
  printf '%s' $'\e' > "$TUI_IN"
  local rc=0
  ( language_run ) || rc=$?
  assert_eq "$rc" 130
  # The terminal was given back before the exit.
  assert_contains "$(cat "$HOME/screen")" $'\e[?1049l'
}

# ------------------------------------------------------ the confirmation -----

_confirm() {
  _screens
  source "$VITRUM_DIR/lib/screens/confirm.sh"
  FACT_FREE_MB=100000 FACT_NIRI_BUILD=0 FACT_FISH_IS_SHELL=1 FACT_DM="" FACT_SHELL=/usr/bin/fish
  unset WANT_LOGIN_SHELL REPLACE_DM ACCEPT_LOW_DISK CONFIRM_INSTALLED
}

# _confirm_to <var> — move the row cursor onto that toggle.
_confirm_to() {
  local i
  for (( i = 0; i < 10; i++ )); do confirm_key up; done
  for (( i = 0; i < 10; i++ )); do
    [[ "${CONFIRM_TOGGLES[CONFIRM_CURSOR]:-}" == "$1" ]] && return 0
    confirm_key down
  done
  echo "no row for $1"; return 1
}

test_confirm_lists_what_and_what_not() {
  _confirm
  confirm_init
  local out; out="$(_visible "$(confirm_render)")"
  assert_contains "$out" "needs sudo"
  assert_contains "${out%%not:*}" "Login screen"
  assert_contains "${out#*not:}" "Boot splash"
  [[ "${out%%not:*}" != *"Boot splash"* ]] || { echo "Boot splash among what is installed"; return 1; }
  # No estimate until there is one (progress_estimate_total says 0).
  [[ "$out" != *"about "*" min"* ]] || { echo "an estimate of 0"; return 1; }
}

test_confirm_shows_the_estimate() {
  _confirm
  # Seconds in, minutes on the screen, rounded up.
  progress_estimate_total() { printf '1490\n'; }
  confirm_init
  assert_contains "$(_visible "$(confirm_render)")" "about 25 min"
}

# The estimate is for the stages that will run, from the progress view's table.
test_confirm_estimate_is_for_the_stages_that_run() {
  _confirm
  source "$VITRUM_DIR/lib/progress.sh"
  PKG_BACKEND=pacman
  niri_needs_build() { return 0; }
  CONFIRM_STAGES=(packages niri)
  confirm_init
  assert_contains "$(_visible "$(confirm_render)")" "about 13 min"
  CONFIRM_STAGES=()
  confirm_init
  [[ "$(confirm_render)" != *"about "*" min"* ]] || { echo "an estimate with no stages"; return 1; }
}

# The questions' answers reach a stage that runs in a child bash.
test_confirm_exports_the_answers() {
  _confirm
  FACT_FISH_IS_SHELL=0 FACT_SHELL=/bin/bash
  confirm_init
  _confirm_to WANT_LOGIN_SHELL
  confirm_key space
  assert_eq "$(bash -c 'echo "$WANT_LOGIN_SHELL/$REPLACE_DM/$ACCEPT_LOW_DISK"')" 0/0/0
}

test_confirm_says_no_longer_managed_in_an_update() {
  _confirm
  CONFIRM_INSTALLED="sddm tmux"
  component_set sddm 0
  confirm_init
  local out; out="$(_visible "$(confirm_render)")"
  assert_contains "$out" "no longer managed: Login screen"
  # Unticked and never installed is still just "not"; what was installed is
  # not among them.
  local nots="${out#*not:}"; nots="${nots%%no longer managed:*}"
  assert_contains "$nots" "Boot splash"
  [[ "$nots" != *"Login screen"* ]] || { echo "Login screen under not:"; return 1; }
}

test_confirm_rows_only_when_they_apply() {
  _confirm
  FACT_FISH_IS_SHELL=1 FACT_DM=""
  confirm_init
  local out; out="$(_visible "$(confirm_render)")"
  [[ "$out" != *"login shell"* ]] || { echo "login shell row with fish as the shell"; return 1; }
  [[ "$out" != *"Replace"* ]] || { echo "Replace row without another login screen"; return 1; }
  assert_eq "${#CONFIRM_TOGGLES[@]}" 0

  FACT_FISH_IS_SHELL=0 FACT_SHELL=/bin/bash FACT_DM=gdm
  component_set sddm 1
  confirm_init
  out="$(_visible "$(confirm_render)")"
  assert_contains "$out" "[x] Make fish my login shell (now bash)"
  assert_contains "$out" "[ ] Replace gdm with SDDM"
  assert_eq "$WANT_LOGIN_SHELL/$REPLACE_DM" 1/0

  # Without SDDM ticked there is nothing to replace.
  component_set sddm 0
  confirm_init
  [[ "$(confirm_render)" != *"Replace"* ]] || { echo "Replace row with SDDM unticked"; return 1; }
}

test_confirm_keeps_a_flag_given_on_the_command_line() {
  _confirm
  FACT_DM=lightdm REPLACE_DM=1
  confirm_init
  assert_contains "$(_visible "$(confirm_render)")" "[x] Replace lightdm with SDDM"
}

test_confirm_space_toggles_the_row() {
  _confirm
  FACT_FISH_IS_SHELL=0 FACT_SHELL=/bin/zsh FACT_DM=gdm
  confirm_init
  _confirm_to REPLACE_DM
  confirm_key space
  assert_eq "$REPLACE_DM" 1
  _confirm_to WANT_LOGIN_SHELL
  confirm_key space
  assert_eq "$WANT_LOGIN_SHELL" 0
}

test_low_disk_blocks_install_until_ticked() {
  _confirm
  FACT_FREE_MB=500 FACT_NIRI_BUILD=1
  confirm_init
  local rc=0
  confirm_key enter || rc=$?
  assert_eq "$rc" 0
  local out; out="$(_visible "$(confirm_render)")"
  assert_contains "$out" "[ ] Only 500MB free, niri wants about 5GB: install anyway"
  assert_contains "$out" "$(T "Tick the disk space row to install anyway, or free some space first.")"
  _confirm_to ACCEPT_LOW_DISK
  confirm_key space
  rc=0
  confirm_key enter || rc=$?
  assert_eq "$rc" 20
}

test_low_disk_is_no_matter_without_a_build() {
  _confirm
  FACT_FREE_MB=500 FACT_NIRI_BUILD=0
  confirm_init
  [[ "$(confirm_render)" != *"5GB"* ]] || { echo "disk row without a niri build"; return 1; }
  local rc=0
  confirm_key enter || rc=$?
  assert_eq "$rc" 20
}

test_confirm_buttons() {
  _confirm
  confirm_init
  local rc
  confirm_key right; rc=0; confirm_key enter || rc=$?; assert_eq "$rc" 21
  confirm_key tab;   rc=0; confirm_key enter || rc=$?; assert_eq "$rc" 22
  confirm_key tab;   rc=0; confirm_key enter || rc=$?; assert_eq "$rc" 20
  confirm_key left;  rc=0; confirm_key enter || rc=$?; assert_eq "$rc" 22
  rc=0; confirm_key esc || rc=$?; assert_eq "$rc" 21
  assert_contains "$(_visible "$(confirm_render)")" "[ Cancel ]"
}

# A short, narrow terminal loses summary lines, never the questions or the
# buttons, and nothing is wider than the terminal.
test_confirm_fits_a_small_terminal() {
  _confirm
  FACT_FREE_MB=500 FACT_NIRI_BUILD=1 FACT_FISH_IS_SHELL=0 FACT_SHELL=/bin/bash FACT_DM=gdm
  TUI_ROWS=16 TUI_COLS=60
  local lang line n out
  for lang in en ru; do
    VITRUM_LANG=$lang
    confirm_init
    out="$(confirm_render)"
    n=0
    while IFS= read -r line; do
      n=$((n + 1))
      line="$(_visible "$line")"
      (( ${#line} <= 60 )) || { echo "$lang: line $n is ${#line} wide: [$line]"; return 1; }
    done <<<"$out"
    (( n <= 16 )) || { echo "$lang: $n lines"; return 1; }
    assert_contains "$out" "$(T "Install")"
    assert_contains "$out" "$(T "Replace %s with SDDM" gdm)"
    assert_contains "$out" "$(T "Only %sMB free, niri wants about 5GB: install anyway" 500 | cut -c1-20)"
  done
}

test_confirm_run_loop() {
  _confirm
  TUI_OUT="$HOME/screen" TUI_IN="$HOME/keys"
  printf '\n' > "$TUI_IN"
  local rc=0
  confirm_run || rc=$?
  assert_eq "$rc" 0
  printf '%s' $'\e[C\n' > "$TUI_IN"
  rc=0; confirm_run || rc=$?
  assert_eq "$rc" 1
  printf '%s' $'\e[D\n' > "$TUI_IN"
  rc=0; confirm_run || rc=$?
  assert_eq "$rc" 2
}

test_confirm_in_russian() {
  _confirm
  VITRUM_LANG=ru
  FACT_FISH_IS_SHELL=0 FACT_SHELL=/bin/bash
  confirm_init
  local out; out="$(confirm_render)"
  assert_contains "$out" "${I18N_RU['not:']}"
  assert_contains "$out" "${I18N_RU['Install']}"
}

# ------------------------------------------------- facts before the screens -----

test_preflight_facts() {
  _screens
  source "$VITRUM_DIR/lib/stages/00-preflight.sh"
  stub df 'printf "Filesystem 1M-blocks Used Available Capacity Mounted\n/dev/x 100000 99500 500 99%% /\n"'
  SHELL=/usr/bin/fish
  VITRUM_NIRI_BIN="$HOME/no-niri"
  preflight_facts
  assert_eq "$FACT_FREE_MB/$FACT_SHELL/$FACT_FISH_IS_SHELL/$FACT_NIRI_BUILD/$FACT_DM" "500//usr/bin/fish/1/1/"
  # An installed niri built from the pinned revisions needs no build.
  printf '#!/bin/sh\n' > "$HOME/no-niri"; chmod +x "$HOME/no-niri"
  mkdir -p "$VITRUM_STATE"; niri_stamp > "$VITRUM_STATE/niri.rev"
  SHELL=/bin/bash
  dm_current() { printf 'gdm\n'; }
  preflight_facts
  assert_eq "$FACT_FISH_IS_SHELL/$FACT_NIRI_BUILD/$FACT_DM" "0/0/gdm"
  dm_current() { printf 'sddm\n'; }
  preflight_facts
  assert_eq "$FACT_DM" ""
}

# The stage asks nothing any more: the confirmation did, before it ran.
test_preflight_asks_nothing() {
  _screens
  source "$VITRUM_DIR/lib/stages/00-preflight.sh"
  stub uname 'echo Linux'
  stub sudo 'exit 0'
  stub lspci 'exit 0'
  stub df 'printf "Filesystem 1M-blocks Used Available Capacity Mounted\n/dev/x 100000 99500 500 99%% /\n"'
  PKG_BACKEND=pacman INIT_BACKEND=systemd
  confirm() { echo asked >> "$HOME/asked"; return 0; }
  local out
  out="$(stage_preflight 2>&1)" || { echo "$out"; return 1; }
  [[ ! -e "$HOME/asked" ]] || { echo "preflight asked"; return 1; }
  assert_contains "$out" "only 500MB free"
}

# The boot splash's hint is about every system, not Gentoo's dracut alone, and
# it has its Russian text.
test_plymouth_hint_names_both_initramfs_tools() {
  _screens
  local h; h="$(choose_hint plymouth)"
  assert_contains "$h" "dracut or mkinitcpio" || return 1
  [[ "$h" != *Gentoo* ]] || { echo "$h"; return 1; }
  VITRUM_LANG=ru
  assert_contains "$(choose_hint plymouth)" "dracut или mkinitcpio"
}
