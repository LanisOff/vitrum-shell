# shellcheck shell=bash disable=SC1090,SC1091,SC2034
# The component registry (lib/components.sh): defaults, the stored choices,
# the v1 file older installers wrote, and the old flags.

_comps() {
  unset VITRUM_MSG_LANG
  export VITRUM_DEVICE_LOCALE=en_US.UTF-8
  source "$VITRUM_DIR/lib/common.sh"
  mkdir -p "$XDG_DATA_HOME/vitrum"
}

# The v1 file exactly as save_components wrote it before the registry.
_v1_file() {
  local keys="${1:-vitrum}" extras="${2:-true}"
  cat > "$XDG_DATA_HOME/vitrum/components.json" <<EOF
{
  "starship": true,
  "fish": true,
  "kitty": true,
  "fastfetch": true,
  "tmux": true,
  "tmux_autostart": true,
  "tmux_keys": "$keys",
  "nvim": true,
  "sddm": true,
  "plymouth": false,
  "live_wallpaper": true,
  "extras": $extras,
  "phone": false
}
EOF
}

test_fresh_defaults() {
  _comps
  ! components_load || return 1
  components_defaults
  assert_eq "$(component_get sddm)/$(component_get plymouth)/$(component_get author_nvim)/$(component_get ocr)" "1/0/0/1"
  assert_eq "$VITRUM_TERMINAL/$VITRUM_SHELL/$VITRUM_FASTFETCH_LOGO" "kitty/fish/picture"
  assert_eq "$WANT_TMUX_KEYS" default
}

test_v1_migration_keeps_the_author_setup() {
  _comps; _v1_file vitrum true
  components_load
  assert_eq "$(component_get author_nvim)/$(component_get author_tmux_keys)/$(component_get games)/$(component_get utilities)/$(component_get tmux_autostart)" "1/1/1/1/1"
  assert_eq "$(component_get cli_tools)/$(component_get file_manager)/$(component_get ocr)" "1/1/1"
  assert_eq "${COMPONENTS_MIGRATED:-}" 1
  assert_eq "$(components_new)" ""
  assert_eq "$(components_unticked | tr '\n' ' ')" "plymouth phone "
  assert_eq "$WANT_TMUX_KEYS" vitrum
}

test_v1_tmux_keys_default() {
  _comps; _v1_file default true
  components_load
  assert_eq "$(component_get author_tmux_keys)" 0
  assert_eq "$WANT_TMUX_KEYS" default
}

test_flags_beat_the_file() {
  _comps; _v1_file vitrum true
  components_flag --no-extras
  components_load
  assert_eq "$(component_get games)/$(component_get utilities)" "0/0"
  components_flag --tmux-keys=default
  assert_eq "$(component_get author_tmux_keys)" 0
  components_flag --tmux-keys=vitrum
  assert_eq "$(component_get author_tmux_keys)" 1
  components_flag --with-cli-tools
  assert_eq "$(component_get cli_tools)" 1
  components_flag --no-live-wallpaper
  assert_eq "$(component_get live_wallpaper)" 0
  components_flag --with-nvim
  assert_eq "$(component_get author_nvim)" 1
  components_flag --no-tmux-autostart
  assert_eq "$(component_get tmux_autostart)" 0
  components_flag --tmux-autostart
  assert_eq "$(component_get tmux_autostart)" 1
  ! components_flag --bogus || return 1
  ! components_flag --tmux-keys=emacs || return 1
}

test_save_round_trip() {
  _comps
  components_defaults
  component_set plymouth 1; component_set games 1; component_set utilities 0
  component_set author_tmux_keys 1; component_set phone 1
  VITRUM_FASTFETCH_LOGO=distro VITRUM_LANG=ru
  components_save
  local f="$XDG_DATA_HOME/vitrum/components.json"
  assert_contains "$(cat "$f")" '"version": 2'
  assert_contains "$(cat "$f")" '"tmux_keys": "vitrum"'
  assert_contains "$(cat "$f")" '"extras": true'
  python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$f"
  local id before=""
  for id in $(component_ids); do before+="$id=$(component_get "$id") "; done
  for id in $(component_ids); do printf -v "$(component_field "$id" var)" '%s' ""; done
  VITRUM_TERMINAL="" VITRUM_SHELL="" VITRUM_FASTFETCH_LOGO="" WANT_TMUX_KEYS=""
  components_load
  local after=""
  for id in $(component_ids); do after+="$id=$(component_get "$id") "; done
  assert_eq "$after" "$before"
  assert_eq "$VITRUM_FASTFETCH_LOGO/$VITRUM_TERMINAL/$VITRUM_LANG_STORED" "distro/kitty/ru"
  assert_eq "$WANT_TMUX_KEYS" vitrum
  assert_eq "${COMPONENTS_MIGRATED:-0}" 0
}

# An update that shows no language screen saves the language it loaded.
test_save_keeps_the_stored_language() {
  _comps
  components_defaults
  VITRUM_LANG=ru
  components_save
  unset VITRUM_LANG
  VITRUM_LANG_STORED=""
  components_load
  assert_eq "$VITRUM_LANG_STORED" ru
  components_save
  assert_contains "$(cat "$XDG_DATA_HOME/vitrum/components.json")" '"language": "ru"'
  VITRUM_LANG=en
  components_save
  assert_contains "$(cat "$XDG_DATA_HOME/vitrum/components.json")" '"language": "en"'
}

test_save_says_extras_false_without_games_or_utilities() {
  _comps
  components_defaults
  component_set games 0; component_set utilities 0
  components_save
  assert_contains "$(cat "$XDG_DATA_HOME/vitrum/components.json")" '"extras": false'
  assert_contains "$(cat "$XDG_DATA_HOME/vitrum/components.json")" '"tmux_keys": "default"'
}

test_new_items_after_an_upgrade() {
  _comps
  components_defaults
  components_save
  python3 - "$XDG_DATA_HOME/vitrum/components.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["known"].remove("ocr")
del d["ocr"]
json.dump(d, open(sys.argv[1], "w"))
PY
  for id in $(component_ids); do printf -v "$(component_field "$id" var)" '%s' ""; done
  components_load
  assert_eq "$(components_new)" ocr
  assert_eq "$(component_get ocr)" 1
}

test_needs() {
  _comps
  stub lspci 'echo "00:02.0 VGA compatible controller: Intel"'
  components_defaults
  component_set games 1; component_set utilities 0; component_set ocr 0
  local needs; needs=" $(components_needs | tr '\n' ' ')"
  assert_contains "$needs" " required "
  assert_contains "$needs" " games "
  [[ "$needs" != *" utilities "* && "$needs" != *" ocr "* && "$needs" != *" nvidia "* ]]
  component_set ocr 1
  VITRUM_DEVICE_LOCALE=ru_RU.UTF-8
  needs=" $(components_needs | tr '\n' ' ')"
  assert_contains "$needs" " ocr "
  assert_contains "$needs" " ocr-ru "
  VITRUM_DEVICE_LOCALE=en_US.UTF-8
  needs=" $(components_needs | tr '\n' ' ')"
  assert_contains "$needs" " ocr "
  [[ "$needs" != *" ocr-ru "* ]]
  VITRUM_MSG_LANG=ru
  assert_contains " $(components_needs | tr '\n' ' ')" " ocr-ru "
  PKG_BACKEND=pacman; source "$VITRUM_DIR/lib/packages.sh"
  assert_eq "$(packages_for ocr | tr '\n' ' ')" "tesseract tesseract-data-eng "
  assert_eq "$(packages_for ocr-ru)" tesseract-data-rus
}

test_needs_nvidia() {
  _comps
  stub lspci 'echo "01:00.0 VGA compatible controller: NVIDIA Corporation AD104"'
  components_defaults
  assert_contains "$(components_needs)" nvidia
}

test_unknown_ids_are_refused() {
  _comps
  ! component_set nope 1 || return 1
  ! component_get nope || return 1
  ! component_field sddm colour || return 1
}

test_no_python_means_defaults() {
  _comps; _v1_file default false
  stub python3 'exit 127'
  ! components_load || return 1
  components_defaults
  assert_eq "$(component_get games)" 1
}

# A file that is there but cannot be read is not replaced by the defaults,
# unless the screens were answered on this run.
test_unreadable_file_is_not_overwritten() {
  _comps
  printf 'not json\n' > "$XDG_DATA_HOME/vitrum/components.json"
  ! components_load || return 1
  assert_eq "$COMPONENTS_LOAD_FAILED" 1
  components_defaults
  local out; out="$(components_save 2>&1)"
  assert_contains "$out" "could not read"
  assert_eq "$(cat "$XDG_DATA_HOME/vitrum/components.json")" "not json"
  COMPONENTS_CHOSEN=1
  components_save
  assert_contains "$(cat "$XDG_DATA_HOME/vitrum/components.json")" '"version": 2'
}

# What the file had ticked, kept apart from what the flags say on this run.
test_stored_on_ignores_the_flags() {
  _comps; _v1_file vitrum true
  components_flag --no-sddm
  components_load
  assert_contains " $COMPONENTS_STORED_ON " " sddm "
  assert_eq "$(component_get sddm)" 0
  [[ " $COMPONENTS_STORED_ON " != *" plymouth "* ]]
  # No file: nothing stored, nothing failed.
  rm "$XDG_DATA_HOME/vitrum/components.json"
  ! components_load || return 1
  assert_eq "$COMPONENTS_LOAD_FAILED/$COMPONENTS_STORED_ON" "/"
}

# The confirmation's login-shell answer is stored only when it was given on
# this run; otherwise the stored one is kept, or none written at all. Loading
# it never decides this run (install.sh does).
test_login_shell_answer_is_kept() {
  _comps
  components_defaults
  local f="$XDG_DATA_HOME/vitrum/components.json"
  # A default nobody was asked about is not an answer.
  unset WANT_LOGIN_SHELL LOGIN_SHELL_ANSWERED COMPONENTS_LOGIN_SHELL
  components_save
  [[ "$(cat "$f")" != *login_shell* ]] || { echo "a default stored as an answer"; return 1; }
  WANT_LOGIN_SHELL=1
  components_save
  [[ "$(cat "$f")" != *login_shell* ]] || { echo "an unasked yes stored"; return 1; }
  # Answered on this run: stored.
  WANT_LOGIN_SHELL=0 LOGIN_SHELL_ANSWERED=1
  components_save
  assert_contains "$(cat "$f")" '"login_shell": false'
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f"
  # Read back, it is the stored answer, not this run's choice.
  unset WANT_LOGIN_SHELL LOGIN_SHELL_ANSWERED
  components_load
  assert_eq "$COMPONENTS_LOGIN_SHELL" 0
  assert_eq "${WANT_LOGIN_SHELL:-unset}" unset
  # A run that did not ask keeps what the file had.
  WANT_LOGIN_SHELL=1
  components_save
  assert_contains "$(cat "$f")" '"login_shell": false'
  # A file that never kept it has none.
  _v1_file
  components_load
  assert_eq "${COMPONENTS_LOGIN_SHELL:-unset}" unset
}
