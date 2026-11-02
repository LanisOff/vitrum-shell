# shellcheck shell=bash disable=SC1090,SC1091
# The input method (input_method): its place in the registry and on the choice
# screen, its packages, doctor, uninstall and the vitrum-im helper.
_comps() {
  source "$VITRUM_DIR/lib/common.sh"
  VITRUM_LANG=en
  source "$VITRUM_DIR/lib/i18n.sh"
  source "$VITRUM_DIR/lib/components.sh"
  VITRUM_PREFIX="$XDG_CONFIG_HOME/vitrum"
  mkdir -p "$VITRUM_STATE" "$VITRUM_PREFIX/niri/generated"
}
test_input_method_is_off_by_default() {
  _comps
  assert_eq "$(component_field input_method group)/$(component_field input_method default)/$(component_field input_method need)/$(component_field input_method var)" \
    "desktop/0/input-method/WANT_INPUT_METHOD"
  components_defaults
  assert_eq "$(component_get input_method)" 0
}
test_input_method_flags_and_stored_choice() {
  _comps
  components_flag --with-input-method; assert_eq "$(component_get input_method)" 1
  components_flag --no-input-method; assert_eq "$(component_get input_method)" 0
  components_defaults
  component_set input_method 1
  components_save
  assert_contains "$(cat "$(components_file)")" '"input_method": true'
}
test_input_method_needs_its_packages() {
  _comps
  export PKG_BACKEND=pacman
  source "$VITRUM_DIR/lib/packages.sh"
  components_defaults; component_set input_method 1
  assert_contains "$(components_needs | tr '\n' ' ')" "input-method"
  local names; names="$(packages_for input-method | tr '\n' ' ')"
  assert_eq "$names" "fcitx5 fcitx5-qt fcitx5-gtk fcitx5-mozc fcitx5-hangul fcitx5-chinese-addons "
}
test_input_method_packages_on_every_distribution() {
  _comps
  source "$VITRUM_DIR/lib/packages.sh"
  local b out
  for b in portage pacman dnf xbps; do
    PKG_BACKEND=$b
    out="$(packages_for input-method 2>&1)"
    [[ "$out" != *"not packaged"* ]] || { echo "$b: $out"; return 1; }
  done
  PKG_BACKEND=portage
  assert_eq "$(packages_for input-method | tr '\n' ' ')" "app-i18n/fcitx app-i18n/fcitx-qt app-i18n/fcitx-gtk app-i18n/mozc app-i18n/fcitx-hangul app-i18n/fcitx-chinese-addons "
  PKG_BACKEND=dnf
  assert_eq "$(packages_for input-method | tr '\n' ' ')" "fcitx5 fcitx5-qt6 fcitx5-gtk3 fcitx5-gtk4 fcitx5-mozc fcitx5-hangul fcitx5-chinese-addons "
  PKG_BACKEND=xbps
  assert_eq "$(packages_for input-method | tr '\n' ' ')" "fcitx5 fcitx5-qt6 fcitx5-gtk+3 fcitx5-gtk4 fcitx5-mozc fcitx5-hangul fcitx5-chinese-addons "
}
test_cjk_layouts_are_found() {
  _comps
  ! cjk_layouts_set || return 1
  echo '{"keyboard": {"layouts": ["us", "ru"]}}' > "$XDG_CONFIG_HOME/vitrum/settings.json"
  ! cjk_layouts_set || return 1
  echo '{"keyboard": {"layouts": ["us", "ru", "jp"]}}' > "$XDG_CONFIG_HOME/vitrum/settings.json"
  cjk_layouts_set
  rm "$XDG_CONFIG_HOME/vitrum/settings.json"
  printf 'input {\n    keyboard {\n        xkb {\n            layout "us,ru,jp"\n        }\n    }\n}\n' > "$VITRUM_PREFIX/niri/generated/input.kdl"
  cjk_layouts_set
  printf '            layout "us,mkr"\n' > "$VITRUM_PREFIX/niri/generated/input.kdl"
  ! cjk_layouts_set || return 1
}
test_the_screen_ticks_it_for_cjk_layouts() {
  _comps
  echo '{"keyboard": {"layouts": ["us", "jp"]}}' > "$XDG_CONFIG_HOME/vitrum/settings.json"
  components_defaults
  assert_eq "$(component_get input_method)" 0      # the default stays off: no screen, no change
  components_suggest
  assert_eq "$(component_get input_method)" 1
}
test_the_screen_leaves_a_decision_alone() {
  _comps
  echo '{"keyboard": {"layouts": ["us", "jp"]}}' > "$XDG_CONFIG_HOME/vitrum/settings.json"
  components_flag --no-input-method
  components_suggest
  assert_eq "$(component_get input_method)" 0
  WANT_INPUT_METHOD=0 COMPONENT_FLAGGED_INPUT_METHOD="" COMPONENTS_KNOWN="input_method"
  components_suggest
  assert_eq "$(component_get input_method)" 0
}
test_choose_screen_has_words_for_it() {
  _comps
  source "$VITRUM_DIR/lib/screens/choose.sh"
  assert_contains "$(choose_label input_method)" "fcitx5"
  assert_contains "$(choose_hint input_method)" "Alt+Shift"
}
_im() {
  mkdir -p "$XDG_DATA_HOME/vitrum" "$XDG_CONFIG_HOME/fcitx5"
  printf '{"input_method": %s}\n' "${1:-true}" > "$XDG_DATA_HOME/vitrum/components.json"
  cat > "$XDG_CONFIG_HOME/fcitx5/profile" <<'P'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=keyboard-us

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=keyboard-ru
Layout=

[Groups/0/Items/2]
Name=mozc
Layout=

[GroupOrder]
0=Default
P
  stub fcitx5 'echo "fcitx5 $*" >> "$HOME/calls"'
  stub fcitx5-remote 'if [ "$1" = -n ]; then cat "$HOME/im"; else echo "remote $*" >> "$HOME/calls"; fi'
  export XDG_RUNTIME_DIR="$HOME/run"; mkdir -p "$XDG_RUNTIME_DIR"
  echo keyboard-us > "$HOME/im"
}
test_vitrum_im_steps_through_the_profile() {
  _im
  "$VITRUM_DIR/tools/vitrum-im" next
  assert_contains "$(cat "$HOME/calls")" "remote -s keyboard-ru"
  echo mozc > "$HOME/im"; : > "$HOME/calls"
  "$VITRUM_DIR/tools/vitrum-im" next
  assert_contains "$(cat "$HOME/calls")" "remote -s keyboard-us"
  echo keyboard-us > "$HOME/im"; : > "$HOME/calls"
  "$VITRUM_DIR/tools/vitrum-im" prev
  assert_contains "$(cat "$HOME/calls")" "remote -s mozc"
  assert_eq "$("$VITRUM_DIR/tools/vitrum-im" list | tr '\n' ' ')" "keyboard-us keyboard-ru mozc "
}
test_vitrum_im_holds_still_in_a_game() {
  _im
  "$VITRUM_DIR/tools/vitrum-im" hold on
  "$VITRUM_DIR/tools/vitrum-im" next
  [[ ! -e "$HOME/calls" ]]
  "$VITRUM_DIR/tools/vitrum-im" hold off
  "$VITRUM_DIR/tools/vitrum-im" next
  assert_contains "$(cat "$HOME/calls")" "remote -s keyboard-ru"
}
test_vitrum_im_skips_the_engines_at_a_password() {
  _im
  "$VITRUM_DIR/tools/vitrum-im" hold keys
  echo keyboard-ru > "$HOME/im"
  "$VITRUM_DIR/tools/vitrum-im" next
  assert_contains "$(cat "$HOME/calls")" "remote -s keyboard-us"
  ! grep -q mozc "$HOME/calls"
  "$VITRUM_DIR/tools/vitrum-im" hold off
  [[ ! -e "$XDG_RUNTIME_DIR/vitrum-im-hold" ]]
}
test_vitrum_im_replaces_a_stale_daemon_at_login() {
  _im
  "$VITRUM_DIR/tools/vitrum-im" start
  assert_contains "$(cat "$HOME/calls")" "fcitx5 --replace -d"
}
test_vitrum_im_does_nothing_without_the_component() {
  _im false
  "$VITRUM_DIR/tools/vitrum-im" start || true
  "$VITRUM_DIR/tools/vitrum-im" next || true
  [[ ! -e "$HOME/calls" ]]
}
_doc() {
  export PKG_BACKEND=portage INIT_BACKEND=openrc
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"
  source "$VITRUM_DIR/lib/components.sh"; source "$VITRUM_DIR/lib/stages/90-doctor.sh"
  export VITRUM_SYSROOT="$HOME/sys"
  mkdir -p "$VITRUM_STATE" "$VITRUM_SYSROOT/usr/share/fcitx5/inputmethod"
  printf '{"version": 2, "known": ["input_method"], "input_method": %s}\n' "${1:-true}" > "$(components_file)"
  _DOC_FAIL=0 _DOC_WARN=0
}
test_doctor_is_silent_without_it() {
  _doc false
  assert_eq "$(_doctor_input_method)" ""
}
test_doctor_wants_fcitx5() {
  _doc
  have() { [[ "$1" != fcitx5 ]] && command -v "$1" >/dev/null 2>&1; }
  out="$(_doctor_input_method 2>&1)"
  assert_contains "$out" "fcitx5 is not installed"
}
test_doctor_checks_engines_and_daemon() {
  _doc
  stub fcitx5; stub fcitx5-remote 'exit 1'
  touch "$VITRUM_SYSROOT/usr/share/fcitx5/inputmethod/mozc.conf"
  export WAYLAND_DISPLAY=wayland-1
  out="$(_doctor_input_method 2>&1)"
  assert_contains "$out" "input method: mozc"
  assert_contains "$out" "input method: hangul — the engine is missing"
  assert_contains "$out" "fcitx5 is not running"
  stub fcitx5-remote 'exit 0'
  assert_contains "$(_doctor_input_method 2>&1)" "fcitx5 is running"
  unset WAYLAND_DISPLAY
  ! grep -q "running" <<<"$(_doctor_input_method 2>&1)"
}
test_uninstall_takes_vitrums_files_and_keeps_dictionaries() {
  stub sudo '"$@"'; stub uname 'echo Linux'
  export VITRUM_SYSROOT="$HOME/sys"
  mkdir -p "$VITRUM_SYSROOT/usr/local/bin" "$XDG_DATA_HOME/vitrum" "$XDG_CONFIG_HOME/fcitx5/conf" "$XDG_DATA_HOME/fcitx5/themes/vitrum" "$XDG_DATA_HOME/fcitx5/pinyin" "$XDG_CONFIG_HOME/mozc"
  touch "$XDG_DATA_HOME/vitrum/fcitx-managed" "$XDG_DATA_HOME/fcitx5/themes/vitrum/theme.conf"
  echo mine > "$XDG_DATA_HOME/fcitx5/pinyin/user.dict"; echo mine > "$XDG_CONFIG_HOME/mozc/user_dictionary.db"
  echo ours > "$XDG_CONFIG_HOME/fcitx5/profile"; echo theirs > "$XDG_CONFIG_HOME/fcitx5/profile.pre-vitrum"
  echo ours > "$XDG_CONFIG_HOME/fcitx5/config"; echo ours > "$XDG_CONFIG_HOME/fcitx5/conf/classicui.conf"
  mkdir -p "$XDG_CONFIG_HOME/autostart"; printf '[Desktop Entry]\nHidden=true\n# Written by vitrum: vitrum-im starts it.\n' > "$XDG_CONFIG_HOME/autostart/org.fcitx.Fcitx5.desktop"
  printf '# >>> vitrum input method\n--enable-wayland-ime\n# <<< vitrum input method\n' > "$XDG_CONFIG_HOME/electron-flags.conf"
  printf -- '--mine\n# >>> vitrum input method\n--enable-wayland-ime\n# <<< vitrum input method\n' > "$XDG_CONFIG_HOME/vesktop-flags.conf"
  ( cd "$VITRUM_DIR" && ./uninstall.sh --yes ) >/dev/null 2>&1 || true
  assert_eq "$(cat "$XDG_CONFIG_HOME/fcitx5/profile")" theirs
  [[ ! -e "$XDG_CONFIG_HOME/fcitx5/config" && ! -e "$XDG_CONFIG_HOME/fcitx5/conf/classicui.conf" ]]
  [[ ! -e "$XDG_DATA_HOME/fcitx5/themes/vitrum" && ! -e "$XDG_CONFIG_HOME/autostart/org.fcitx.Fcitx5.desktop" ]]
  assert_eq "$(cat "$XDG_DATA_HOME/fcitx5/pinyin/user.dict")" mine
  assert_eq "$(cat "$XDG_CONFIG_HOME/mozc/user_dictionary.db")" mine
  [[ ! -e "$XDG_CONFIG_HOME/electron-flags.conf" ]]
  assert_eq "$(cat "$XDG_CONFIG_HOME/vesktop-flags.conf")" "--mine"
}
