# shellcheck shell=bash disable=SC1090,SC1091,SC2016,SC2034,SC2329
# The Vesktop theme part (vesktop_theme): its place in the registry and on the
# choice screen, the shell stage's step, the doctor and uninstall. The theme
# itself is vitrum-vesktop-theme's (tools/vitrum_theme/vesktop.py, tested in
# tests/py); here the helper is a stub that records its arguments. No real
# Vesktop: it is a config folder in the temp HOME, or a `vesktop` stub.

_vt() {
  export NO_COLOR=1 PKG_BACKEND="${1:-dnf}" INIT_BACKEND=systemd
  # a vesktop on the machine running the tests is not the one under test
  local d p=""
  IFS=: read -ra _dirs <<<"$PATH"
  for d in "${_dirs[@]}"; do [[ -x "$d/vesktop" ]] || p+="${p:+:}$d"; done
  export PATH="$p"
  source "$VITRUM_DIR/lib/common.sh"
  source "$VITRUM_DIR/lib/packages.sh"
  mkdir -p "$XDG_DATA_HOME/vitrum" "$HOME/.local/bin"
  stub curl 'exit 1'; stub sudo 'exit 1'; stub flatpak 'exit 1'
}

# A Vesktop that has been started once: its config folder.
_vesktop() { mkdir -p "$XDG_CONFIG_HOME/vesktop/themes" "$XDG_CONFIG_HOME/vesktop/settings"; }

# _fake_helper <exit> [stderr line] [status json] — records its arguments;
# with a status, `status` prints it and succeeds.
_fake_helper() {
  rm -f "$HOME/helper-status" "$HOME/helper-err"
  [[ -n "${3:-}" ]] && printf '%s\n' "$3" > "$HOME/helper-status"
  [[ -n "${2:-}" ]] && printf '%s\n' "$2" > "$HOME/helper-err"
  printf '#!/bin/sh\necho "$*" >> "$HOME/helper-calls"\n[ "$1" = status ] && [ -f "$HOME/helper-status" ] && { cat "$HOME/helper-status"; exit 0; }\n[ -f "$HOME/helper-err" ] && cat "$HOME/helper-err" >&2\nexit %s\n' "$1" > "$HOME/.local/bin/vitrum-vesktop-theme"
  chmod +x "$HOME/.local/bin/vitrum-vesktop-theme"
}

_stage() { source "$VITRUM_DIR/lib/stages/40-shell.sh"; components_defaults; }

# ------------------------------------------------------------ registry -----

test_vesktop_theme_is_a_tools_part_on_by_default() {
  _vt
  assert_eq "$(component_field vesktop_theme group)/$(component_field vesktop_theme default)/$(component_field vesktop_theme need)/$(component_field vesktop_theme var)" \
    "tools/1/vesktop-theme/WANT_VESKTOP_THEME"
  # beside the Steam theme, and it needs nothing else ticked
  assert_contains "$(component_ids | tr '\n' ' ')" "games steam_theme vesktop_theme utilities"
  assert_eq "${COMPONENT_REQUIRES[vesktop_theme]:-}" ""
  components_defaults
  component_set games 0
  component_active vesktop_theme
}

test_vesktop_theme_flags_and_stored_choice() {
  _vt
  components_flag --no-vesktop-theme; assert_eq "$(component_get vesktop_theme)" 0
  components_flag --with-vesktop-theme; assert_eq "$(component_get vesktop_theme)" 1
  components_defaults
  component_set vesktop_theme 0
  components_save
  # what vitrum-theme's sync is gated by
  assert_contains "$(cat "$(components_file)")" '"vesktop_theme": false'
  WANT_VESKTOP_THEME=""
  components_load
  assert_eq "$(component_get vesktop_theme)" 0
  assert_contains " $COMPONENTS_KNOWN " " vesktop_theme "
  component_set vesktop_theme 1; components_save
  assert_contains "$(cat "$(components_file)")" '"vesktop_theme": true'
}

# An install made before the part existed is offered it on the update.
test_vesktop_theme_is_new_to_an_older_install() {
  _vt
  local known; known="$(component_ids | grep -vx vesktop_theme | sed 's/.*/"&"/' | paste -sd, -)"
  printf '{"version": 2, "known": [%s], "games": true, "steam_theme": true}\n' "$known" > "$(components_file)"
  components_load
  assert_eq "$(components_new | tr '\n' ' ')" "vesktop_theme "
}

test_vesktop_theme_brings_no_packages_or_assets() {
  local b
  for b in pacman dnf xbps portage; do
    _vt "$b"
    assert_eq "$(packages_for vesktop-theme 2>&1)" "" || { echo "on $b"; return 1; }
  done
  ! grep -qi vesktop "$VITRUM_DIR/lib/packages.tsv" "$VITRUM_DIR/lib/assets.tsv" || return 1
  _vt; components_defaults
  grep -qx vesktop-theme <<<"$(components_needs)"
}

# ----------------------------------------------------------- the screen -----

test_choice_screen_shows_vesktop_theme() {
  _vt; source "$VITRUM_DIR/lib/screens/choose.sh"
  components_defaults
  choose_init
  assert_contains "$(choose_render)" "[x] Vesktop theme (Discord)"
  assert_contains "$(choose_hint vesktop_theme)" "Vesktop theme: vitrum's glass for Discord (Vesktop), follows your colours."
  ! grep -q "Needs" <<<"$(choose_hint vesktop_theme)" || return 1
  _choose_set vesktop_theme 0
  assert_eq "$(component_get vesktop_theme)" 0
}

test_choice_screen_vesktop_theme_in_russian() {
  _vt; source "$VITRUM_DIR/lib/screens/choose.sh"; source "$VITRUM_DIR/lib/screens/confirm.sh"
  VITRUM_LANG=ru
  assert_eq "$(choose_label vesktop_theme)" "Тема Vesktop (Discord)"
  assert_contains "$(choose_hint vesktop_theme)" "Тема Vesktop: стекло vitrum для Discord (Vesktop), следует вашим цветам."
  assert_eq "$(confirm_short vesktop_theme)" "Тема Vesktop"
}

# ------------------------------------------------------------ the stage -----

# The shell stage installs the helper and the theme's files beside the others.
test_shell_stage_installs_the_helper_and_the_theme_source() {
  _vt; source "$VITRUM_DIR/lib/stages/40-shell.sh"; _shell_check_qml() { :; }
  stub python3 'exit 0'
  stage_shell >"$HOME/out" 2>&1 || { tail -5 "$HOME/out"; return 1; }
  [[ -x "$HOME/.local/bin/vitrum-vesktop-theme" ]]
  [[ -d "$XDG_DATA_HOME/vitrum/vesktop" ]]
  diff -r "$VITRUM_DIR/assets/vesktop" "$XDG_DATA_HOME/vitrum/vesktop"
}

test_stage_runs_the_helper_install_with_yes() {
  _vt; _vesktop; _fake_helper 0; _stage
  out="$(_shell_vesktop_theme 2>&1)" || { echo "$out"; return 1; }
  assert_eq "$(cat "$HOME/helper-calls")" "install --yes"
  assert_contains "$out" "Vesktop theme installed"
  # an update: the same again
  _shell_vesktop_theme >/dev/null 2>&1
  assert_eq "$(cat "$HOME/helper-calls")" "install --yes
install --yes"
}

# Vesktop on PATH but never started: the helper is still run.
test_stage_finds_vesktop_on_the_path() {
  _vt; stub vesktop 'exit 0'; _fake_helper 0; _stage
  _shell_vesktop_theme >/dev/null 2>&1
  assert_eq "$(cat "$HOME/helper-calls")" "install --yes"
}

test_stage_without_vesktop_says_so_and_goes_on() {
  _vt; _fake_helper 0; _stage
  export VITRUM_SYSROOT="$HOME/sys"
  out="$(_shell_vesktop_theme 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "Vesktop is not installed"
  [[ ! -e "$HOME/helper-calls" ]]
}

# The Flatpak is themed as well, found by its data or where Flatpak put it.
test_stage_themes_the_flatpak() {
  _vt; _fake_helper 0; _stage
  export VITRUM_SYSROOT="$HOME/sys"
  local d
  for d in "$HOME/.var/app/dev.vencord.Vesktop" "$HOME/sys/var/lib/flatpak/app/dev.vencord.Vesktop" \
           "$XDG_DATA_HOME/flatpak/app/dev.vencord.Vesktop"; do
    rm -f "$HOME/helper-calls"; mkdir -p "$d"
    out="$(_shell_vesktop_theme 2>&1)" || { echo "$out"; return 1; }
    assert_eq "$(cat "$HOME/helper-calls")" "install --yes" || { echo "for $d"; return 1; }
    assert_contains "$out" "Vesktop theme installed"
    rm -rf "$d"
  done
}

test_stage_respects_the_stored_choice() {
  _vt; _vesktop; _fake_helper 0; source "$VITRUM_DIR/lib/stages/40-shell.sh"
  printf '{"version": 2, "known": ["vesktop_theme"], "vesktop_theme": false}\n' > "$(components_file)"
  components_load; components_defaults
  assert_eq "$(_shell_vesktop_theme 2>&1)" ""
  [[ ! -e "$HOME/helper-calls" ]]
}

# A failure costs the Vesktop theme, not the shell stage; a terminal it needs is said.
test_stage_reports_the_helper_failing_and_goes_on() {
  _vt; _vesktop; _fake_helper 1 "vitrum-vesktop-theme: Vencord's settings.json is not JSON"; _stage
  out="$(_shell_vesktop_theme 2>&1)" || { echo "the stage should go on"; return 1; }
  assert_contains "$out" "settings.json is not JSON"
  assert_contains "$out" "the Vesktop theme could not be installed"
  _fake_helper 2 "vitrum-vesktop-theme: run it in a terminal"
  out="$(_shell_vesktop_theme 2>&1)" || return 1
  assert_contains "$out" "run: vitrum-vesktop-theme install"
  ! grep -q "could not be installed" <<<"$out" || return 1
  # the helper gone
  rm -f "$HOME/.local/bin/vitrum-vesktop-theme"
  assert_contains "$(_shell_vesktop_theme 2>&1)" "the Vesktop theme is not installed"
}

test_stage_warning_in_russian() {
  _vt; _vesktop; _fake_helper 1; _stage
  VITRUM_MSG_LANG=ru
  assert_contains "$(_shell_vesktop_theme 2>&1)" "тему для Vesktop установить не удалось"
}

test_stage_dry_run_runs_nothing() {
  _vt; _vesktop; _fake_helper 0; _stage
  DRY_RUN=1
  assert_contains "$(_shell_vesktop_theme 2>&1)" "would run: vitrum-vesktop-theme install --yes"
  [[ ! -e "$HOME/helper-calls" ]]
}

# ----------------------------------------------------------- the doctor -----

_doc() {
  _vt; source "$VITRUM_DIR/lib/stages/90-doctor.sh"
  printf '{"version": 2, "known": ["vesktop_theme"], "vesktop_theme": %s}\n' "${1:-true}" > "$(components_file)"
}

_status() { printf '{"vesktop": true, "installed": %s, "active": %s, "running": false, "themeDir": "%s"}' "$1" "$2" "$XDG_CONFIG_HOME/vesktop/themes"; }

test_doctor_says_nothing_when_the_part_is_off_or_there_is_no_vesktop() {
  _doc false; _vesktop; _fake_helper 0 "" "$(_status false false)"
  export VITRUM_SYSROOT="$HOME/sys"
  assert_eq "$(_doctor_vesktop_theme 2>&1)" ""
  _doc; rm -rf "$XDG_CONFIG_HOME/vesktop"
  assert_eq "$(_doctor_vesktop_theme 2>&1)" ""
  # the Flatpak's is checked like the native one
  mkdir -p "$HOME/.var/app/dev.vencord.Vesktop"
  assert_contains "$(_doctor_vesktop_theme 2>&1)" "Vesktop theme — not installed"
}

test_doctor_reports_the_theme() {
  _doc; _vesktop
  assert_contains "$(_doctor_vesktop_theme 2>&1)" "vitrum-vesktop-theme is missing"
  _fake_helper 1
  assert_contains "$(_doctor_vesktop_theme 2>&1)" "vitrum-vesktop-theme status failed"
  _fake_helper 0 "" "$(_status false false)"
  assert_contains "$(_doctor_vesktop_theme 2>&1)" "Vesktop theme — not installed"
  _fake_helper 0 "" "$(_status true true)"
  out="$(_doctor_vesktop_theme 2>&1)"
  assert_contains "$out" "✓ Vesktop theme: active"
  ! grep -q '!' <<<"$out" || { echo "$out"; return 1; }
  # not active: said, unless Settings switched it off
  _fake_helper 0 "" "$(_status true false)"
  assert_contains "$(_doctor_vesktop_theme 2>&1)" "installed but not active"
  mkdir -p "$XDG_CONFIG_HOME/vitrum"
  echo '{"vesktop": {"theme": {"enabled": false}}}' > "$XDG_CONFIG_HOME/vitrum/settings.json"
  assert_contains "$(_doctor_vesktop_theme 2>&1)" "switched off in Settings"
}

# ------------------------------------------------------------ uninstall -----

test_uninstall_removes_the_theme_and_the_helper() {
  stub uname 'echo Linux'
  _vt; _vesktop; _fake_helper 0
  stub sudo '"$@"'
  mkdir -p "$XDG_DATA_HOME/vitrum/vesktop"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >"$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  assert_eq "$(cat "$HOME/helper-calls")" "remove"
  [[ ! -e "$HOME/.local/bin/vitrum-vesktop-theme" && ! -e "$XDG_DATA_HOME/vitrum/vesktop" ]]
  # Vesktop's own folder stays
  [[ -d "$XDG_CONFIG_HOME/vesktop/themes" ]]
}

test_uninstall_says_when_remove_fails() {
  stub uname 'echo Linux'
  _vt; _vesktop; _fake_helper 1 "vitrum-vesktop-theme: could not write settings.json"
  stub sudo '"$@"'
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >"$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  assert_contains "$(cat "$HOME/out")" "could not remove the Vesktop theme"
  [[ ! -e "$HOME/.local/bin/vitrum-vesktop-theme" ]]
}

test_uninstall_without_the_helper_says_nothing_of_it() {
  stub sudo '"$@"'; stub uname 'echo Linux'
  mkdir -p "$XDG_DATA_HOME/vitrum"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >"$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  ! grep -q "Vesktop theme" "$HOME/out"
}

test_uninstall_dry_run_leaves_the_theme() {
  stub uname 'echo Linux'
  _vt; _vesktop; _fake_helper 0
  stub sudo '"$@"'
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes --dry-run ) >"$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  [[ -x "$HOME/.local/bin/vitrum-vesktop-theme" && ! -e "$HOME/helper-calls" ]]
  assert_contains "$(cat "$HOME/out")" "would run: vitrum-vesktop-theme remove"
}

# ------------------------------------------------------ the real helper -----

# The real helper, from the repo, on the repo's vitrum_theme; Vesktop is its
# config folder, never running (pgrep finds nothing), no system places.
_real_helper() {
  export VITRUM_VESKTOP_PREFIXES=""
  stub pgrep 'exit 1'
  printf '#!/bin/sh\nexec python3 "%s/tools/vitrum-vesktop-theme" "$@"\n' "$VITRUM_DIR" > "$HOME/.local/bin/vitrum-vesktop-theme"
  chmod +x "$HOME/.local/bin/vitrum-vesktop-theme"
}

_vencord() { cat "$XDG_CONFIG_HOME/vesktop/settings/settings.json"; }

test_stage_with_the_real_helper_installs_and_activates_the_theme() {
  _vt; _vesktop; _real_helper; _stage
  echo '{"enabledThemes": [], "transparent": false, "plugins": {"Mine": {"enabled": true}}}' > "$XDG_CONFIG_HOME/vesktop/settings/settings.json"
  out="$(_shell_vesktop_theme 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "Vesktop theme installed"
  [[ -f "$XDG_CONFIG_HOME/vesktop/themes/vitrum.theme.css" ]]
  assert_contains "$(_vencord)" "vitrum.theme.css"
  assert_contains "$(_vencord)" '"Mine"'
  # an update: the same again, no error
  out="$(_shell_vesktop_theme 2>&1)" || { echo "$out"; return 1; }
  ! grep -qi "could not" <<<"$out" || { echo "$out"; return 1; }
  # and the doctor sees it
  source "$VITRUM_DIR/lib/stages/90-doctor.sh"
  printf '{"version": 2, "known": ["vesktop_theme"], "vesktop_theme": true}\n' > "$(components_file)"
  out="$(_doctor_vesktop_theme 2>&1)"
  assert_contains "$out" "✓ Vesktop theme: active"
}

test_uninstall_with_the_real_helper_switches_the_theme_off() {
  stub uname 'echo Linux'; stub sudo '"$@"'
  _vt; _vesktop; _real_helper
  echo '{"enabledThemes": ["mine.css"]}' > "$XDG_CONFIG_HOME/vesktop/settings/settings.json"
  "$HOME/.local/bin/vitrum-vesktop-theme" install --yes 2>/dev/null
  assert_contains "$(_vencord)" "vitrum.theme.css"
  mkdir -p "$XDG_DATA_HOME/vitrum/vesktop"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >"$HOME/out" 2>&1 || { tail -20 "$HOME/out"; return 1; }
  [[ ! -e "$XDG_CONFIG_HOME/vesktop/themes/vitrum.theme.css" && ! -e "$HOME/.local/bin/vitrum-vesktop-theme" ]]
  ! grep -q "vitrum.theme.css" <<<"$(_vencord)" || { _vencord; return 1; }
  assert_contains "$(_vencord)" "mine.css"
}
