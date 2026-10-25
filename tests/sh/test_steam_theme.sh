# shellcheck shell=bash disable=SC1090,SC1091,SC2016,SC2034,SC2329
# The Steam theme part (steam_theme): its place in the registry and on the
# choice screen, the shell stage's step, the doctor and uninstall. Millennium
# itself is vitrum-steam-theme's (tools/vitrum_theme/steam.py, tested in
# tests/py); here it is run for real only against a Millennium already in
# place, and stubbed otherwise. No network and no real Steam: Steam is a
# folder in the temp HOME, /usr/lib/millennium one beside it.

_MILL_FILES="libmillennium_x86.so libmillennium_hhx64.so libmillennium_bootstrap_x86.so libmillennium_bootstrap_hhx64.so libmillennium_luavm_x86 libmillennium_pvs64"

_st() {
  export NO_COLOR=1 PKG_BACKEND="${1:-dnf}" INIT_BACKEND=systemd
  source "$VITRUM_DIR/lib/common.sh"
  source "$VITRUM_DIR/lib/packages.sh"
  mkdir -p "$XDG_DATA_HOME/vitrum" "$HOME/.local/bin"
  # nothing reaches the network or root
  stub curl 'exit 1'; stub sudo 'exit 1'; stub paru 'exit 1'; stub yay 'exit 1'
}

# A Steam that has set itself up: its folder, and ~/.steam/steam pointing there.
_steam() {
  mkdir -p "$XDG_DATA_HOME/Steam/ubuntu12_32" "$XDG_DATA_HOME/Steam/ubuntu12_64" "$HOME/.steam"
  ln -sfn "$XDG_DATA_HOME/Steam" "$HOME/.steam/steam"
}

# A Millennium already installed and hooked (terpinator's AUR package).
_millennium() {
  export VITRUM_MILLENNIUM_LIB="$HOME/sys/usr/lib/millennium"
  mkdir -p "$VITRUM_MILLENNIUM_LIB"
  local f; for f in $_MILL_FILES; do echo aur > "$VITRUM_MILLENNIUM_LIB/$f"; done
  ln -sfn "$VITRUM_MILLENNIUM_LIB/libmillennium_bootstrap_x86.so" "$XDG_DATA_HOME/Steam/ubuntu12_32/libXtst.so.6"
  ln -sfn "$VITRUM_MILLENNIUM_LIB/libmillennium_bootstrap_hhx64.so" "$XDG_DATA_HOME/Steam/ubuntu12_64/libXtst.so.6"
}

# The real helper, from the repo, on the repo's vitrum_theme.
_real_helper() {
  printf '#!/bin/sh\nexec python3 "%s/tools/vitrum-steam-theme" "$@"\n' "$VITRUM_DIR" > "$HOME/.local/bin/vitrum-steam-theme"
  chmod +x "$HOME/.local/bin/vitrum-steam-theme"
}

# _fake_helper <exit> [stderr line] — records its arguments.
_fake_helper() {
  printf '#!/bin/sh\necho "$*" >> "$HOME/helper-calls"\n%s\nexit %s\n' "${2:+echo \"$2\" >&2}" "$1" > "$HOME/.local/bin/vitrum-steam-theme"
  chmod +x "$HOME/.local/bin/vitrum-steam-theme"
}

_stage() { source "$VITRUM_DIR/lib/stages/40-shell.sh"; components_defaults; }

_themes() { printf '%s\n' "$XDG_DATA_HOME/Steam/millennium/themes"; }

# ------------------------------------------------------------ registry -----

test_steam_theme_is_a_tools_part_on_by_default() {
  _st
  assert_eq "$(component_field steam_theme group)/$(component_field steam_theme default)/$(component_field steam_theme need)/$(component_field steam_theme var)" \
    "tools/1/steam-theme/WANT_STEAM_THEME"
  # right after game mode, which it needs, with the Vesktop theme beside it
  assert_contains "$(component_ids | tr '\n' ' ')" "games steam_theme vesktop_theme utilities"
  assert_eq "${COMPONENT_REQUIRES[steam_theme]}" games
}

test_steam_theme_flags_and_stored_choice() {
  _st
  components_flag --no-steam-theme; assert_eq "$(component_get steam_theme)" 0
  components_flag --with-steam-theme; assert_eq "$(component_get steam_theme)" 1
  components_defaults
  component_set steam_theme 0
  components_save
  # what vitrum-theme's sync is gated by
  assert_contains "$(cat "$(components_file)")" '"steam_theme": false'
  WANT_STEAM_THEME=""
  components_load
  assert_eq "$(component_get steam_theme)" 0
  assert_contains " $COMPONENTS_KNOWN " " steam_theme "
  component_set steam_theme 1; components_save
  assert_contains "$(cat "$(components_file)")" '"steam_theme": true'
}

# An install made before the part existed is offered it on the update.
test_steam_theme_is_new_to_an_older_install() {
  _st
  printf '{"version": 2, "known": ["games", "tmux"], "games": true, "tmux": true}\n' > "$(components_file)"
  components_load
  assert_contains "$(components_new | tr '\n' ' ')" "steam_theme"
}

test_steam_theme_needs_games() {
  _st; components_defaults
  component_active steam_theme
  grep -qx steam-theme <<<"$(components_needs)"
  component_set games 0
  ! component_active steam_theme || return 1
  ! grep -qx steam-theme <<<"$(components_needs)" || return 1
  # flags can leave it ticked; the stages still go by component_active
  assert_eq "$(component_get steam_theme)" 1
}

# Millennium is no package of the table: the helper installs it.
test_steam_theme_brings_no_packages_or_assets() {
  local b
  for b in pacman dnf xbps portage; do
    _st "$b"
    assert_eq "$(packages_for steam-theme 2>&1)" "" || { echo "on $b"; return 1; }
  done
  ! grep -qi millennium "$VITRUM_DIR/lib/packages.tsv" "$VITRUM_DIR/lib/assets.tsv" || return 1
}

# ----------------------------------------------------------- the screen -----

test_choice_screen_greys_steam_theme_without_games() {
  _st; source "$VITRUM_DIR/lib/screens/choose.sh"
  components_defaults
  component_set games 0
  choose_init
  assert_eq "$(component_get steam_theme)" 0
  assert_contains "$(choose_render)" "[ ] Steam theme (Millennium)  (needs Game mode)"
  assert_contains "$(choose_hint steam_theme)" "Steam theme: vitrum's look for Steam via Millennium, follows your colours."
  assert_contains "$(choose_hint steam_theme)" "Needs Game mode + HUD (gamemode, MangoHud) ticked."
  # ticking games frees it; unticking games takes it along
  _choose_set games 1; _choose_set steam_theme 1
  assert_eq "$(component_get steam_theme)" 1
  _choose_set games 0
  assert_eq "$(component_get steam_theme)" 0
}

test_choice_screen_steam_theme_in_russian() {
  _st; source "$VITRUM_DIR/lib/screens/choose.sh"; source "$VITRUM_DIR/lib/screens/confirm.sh"
  VITRUM_LANG=ru
  assert_eq "$(choose_label steam_theme)" "Тема для Steam (Millennium)"
  assert_contains "$(choose_hint steam_theme)" "через Millennium, следует за вашими цветами"
  assert_eq "$(confirm_short steam_theme)" "Тема для Steam"
}

# ------------------------------------------------------------ the stage -----

# The shell stage installs the helper and the theme's files beside the others.
test_shell_stage_installs_the_helper_and_the_theme_source() {
  _st; source "$VITRUM_DIR/lib/stages/40-shell.sh"; _shell_check_qml() { :; }
  stub python3 'exit 0'
  stage_shell >/dev/null 2>&1
  [[ -x "$HOME/.local/bin/vitrum-steam-theme" ]]
  [[ -f "$XDG_DATA_HOME/vitrum/steam/vitrum/skin.json" ]]
}

# terpinator's case: Millennium already there, from the AUR. The real helper
# leaves it as it is and puts the theme in, active.
test_stage_with_an_existing_millennium_installs_and_activates_the_theme() {
  _st pacman; _steam; _millennium; _real_helper; _stage
  out="$(_shell_steam_theme 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "Steam theme installed"
  [[ -f "$(_themes)/vitrum/skin.json" ]]
  assert_contains "$(cat "$XDG_CONFIG_HOME/millennium/config.json")" '"activeTheme": "vitrum"'
  # Millennium untouched
  assert_eq "$(cat "$VITRUM_MILLENNIUM_LIB/libmillennium_x86.so")" aur
  # an update: the same again, no error, the theme still active
  out="$(_shell_steam_theme 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "Steam theme installed"
  ! grep -qi "could not" <<<"$out" || { echo "$out"; return 1; }
  assert_contains "$(cat "$XDG_CONFIG_HOME/millennium/config.json")" '"activeTheme": "vitrum"'
}

test_stage_runs_the_helper_install_with_yes() {
  _st; _steam; _fake_helper 0; _stage
  out="$(_shell_steam_theme 2>&1)" || { echo "$out"; return 1; }
  assert_eq "$(cat "$HOME/helper-calls")" "install --yes"
}

test_stage_without_steam_says_so_and_goes_on() {
  _st; _fake_helper 0; _stage
  out="$(_shell_steam_theme 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "Steam is not installed"
  [[ ! -e "$HOME/helper-calls" ]]
  # a Flatpak Steam is not one Millennium supports
  mkdir -p "$HOME/.var/app/com.valvesoftware.Steam"
  assert_contains "$(_shell_steam_theme 2>&1)" "Flatpak"
  [[ ! -e "$HOME/helper-calls" ]]
}

test_stage_respects_the_stored_choice() {
  _st; _steam; _fake_helper 0; source "$VITRUM_DIR/lib/stages/40-shell.sh"
  printf '{"version": 2, "known": ["games", "steam_theme"], "games": true, "steam_theme": false}\n' > "$(components_file)"
  components_load; components_defaults
  assert_eq "$(_shell_steam_theme 2>&1)" ""
  # on, but without games: off as well
  printf '{"version": 2, "known": ["games", "steam_theme"], "games": false, "steam_theme": true}\n' > "$(components_file)"
  WANT_GAMES="" WANT_STEAM_THEME=""
  components_load; components_defaults
  assert_eq "$(_shell_steam_theme 2>&1)" ""
  [[ ! -e "$HOME/helper-calls" ]]
}

# A failure costs the Steam theme, not the shell stage; a terminal it needs is said.
test_stage_reports_the_helper_failing_and_goes_on() {
  _st; _steam; _fake_helper 1 "vitrum-steam-theme: could not download Millennium (no network?)"; _stage
  out="$(_shell_steam_theme 2>&1)" || { echo "the stage should go on"; return 1; }
  assert_contains "$out" "could not download Millennium"
  assert_contains "$out" "the Steam theme could not be installed"
  _fake_helper 2 "vitrum-steam-theme: Millennium is built from the AUR in a terminal"
  out="$(_shell_steam_theme 2>&1)" || return 1
  assert_contains "$out" "run: vitrum-steam-theme install"
  ! grep -q "could not be installed" <<<"$out" || return 1
}

test_stage_dry_run_runs_nothing() {
  _st; _steam; _fake_helper 0; _stage
  DRY_RUN=1
  assert_contains "$(_shell_steam_theme 2>&1)" "would run: vitrum-steam-theme install --yes"
  [[ ! -e "$HOME/helper-calls" ]]
}

# ----------------------------------------------------------- the doctor -----

_doc() {
  _st; source "$VITRUM_DIR/lib/stages/90-doctor.sh"
  printf '{"version": 2, "known": ["games", "steam_theme"], "games": true, "steam_theme": %s}\n' "${1:-true}" > "$(components_file)"
}

test_doctor_says_nothing_when_the_part_is_off_or_there_is_no_steam() {
  _doc false; _steam; _real_helper
  assert_eq "$(_doctor_steam_theme 2>&1)" ""
  _doc; rm -rf "$XDG_DATA_HOME/Steam" "$HOME/.steam"
  assert_eq "$(_doctor_steam_theme 2>&1)" ""
  mkdir -p "$HOME/.var/app/com.valvesoftware.Steam"
  assert_contains "$(_doctor_steam_theme 2>&1)" "Flatpak"
}

test_doctor_reports_millennium_and_the_theme() {
  _doc; _steam
  out="$(_doctor_steam_theme 2>&1)"
  assert_contains "$out" "vitrum-steam-theme is missing"
  _real_helper
  export VITRUM_MILLENNIUM_LIB="$HOME/sys/usr/lib/millennium"
  out="$(_doctor_steam_theme 2>&1)"
  assert_contains "$out" "Millennium — not installed"
  assert_contains "$out" "Steam theme — not installed"
  _millennium
  "$HOME/.local/bin/vitrum-steam-theme" install --yes 2>/dev/null
  out="$(_doctor_steam_theme 2>&1)"
  assert_contains "$out" "✓ Millennium"
  assert_contains "$out" "✓ Steam theme: active"
  ! grep -q '!' <<<"$out" || { echo "$out"; return 1; }
  # not active: said, unless Settings switched it off
  printf '{"themes": {"activeTheme": "default"}}\n' > "$XDG_CONFIG_HOME/millennium/config.json"
  assert_contains "$(_doctor_steam_theme 2>&1)" "installed but not active"
  mkdir -p "$XDG_CONFIG_HOME/vitrum"
  echo '{"steam": {"theme": {"enabled": false}}}' > "$XDG_CONFIG_HOME/vitrum/settings.json"
  assert_contains "$(_doctor_steam_theme 2>&1)" "switched off in Settings"
}

# ------------------------------------------------------------ uninstall -----

test_uninstall_removes_the_theme_and_the_helper_and_keeps_millennium() {
  stub uname 'echo Linux'
  _st; _steam; _millennium; _real_helper
  stub sudo '"$@"'
  "$HOME/.local/bin/vitrum-steam-theme" install --yes 2>/dev/null
  [[ -f "$(_themes)/vitrum/skin.json" ]]
  mkdir -p "$XDG_DATA_HOME/vitrum/steam/vitrum"
  python3 - "$XDG_CONFIG_HOME/millennium/config.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["misc"] = {"hasShownWelcomeModal": True}
json.dump(d, open(sys.argv[1], "w"))
PY
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >"$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  [[ ! -e "$(_themes)/vitrum" && ! -e "$HOME/.local/bin/vitrum-steam-theme" && ! -e "$XDG_DATA_HOME/vitrum/steam" ]]
  local cfg; cfg="$(cat "$XDG_CONFIG_HOME/millennium/config.json")"
  ! grep -q '"activeTheme": *"vitrum"' <<<"$cfg" || { echo "$cfg"; return 1; }
  assert_contains "$cfg" hasShownWelcomeModal
  # Millennium and its hook stay
  [[ -f "$VITRUM_MILLENNIUM_LIB/libmillennium_x86.so" && -L "$XDG_DATA_HOME/Steam/ubuntu12_32/libXtst.so.6" ]]
  assert_contains "$(cat "$HOME/out")" "Millennium is left installed"
}

test_uninstall_without_the_helper_says_nothing_of_it() {
  stub sudo '"$@"'; stub uname 'echo Linux'
  mkdir -p "$XDG_DATA_HOME/vitrum"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >"$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  ! grep -q "Steam theme" "$HOME/out"
}

test_uninstall_dry_run_leaves_the_theme() {
  stub uname 'echo Linux'
  _st; _steam; _millennium; _real_helper
  "$HOME/.local/bin/vitrum-steam-theme" install --yes 2>/dev/null
  stub sudo '"$@"'
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes --dry-run ) >"$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  [[ -f "$(_themes)/vitrum/skin.json" && -x "$HOME/.local/bin/vitrum-steam-theme" ]]
  assert_contains "$(cat "$HOME/out")" "would run: vitrum-steam-theme remove"
}
