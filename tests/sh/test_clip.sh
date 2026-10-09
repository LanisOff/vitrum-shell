# shellcheck shell=bash
# tools/vitrum-clip: everything stored, never trimmed by count; only images
# beyond clipboard.images go, oldest first.
_clip_world() {  # _clip_world <images cap or "">
  # The shell's settings file: always ~/.config, whatever XDG_CONFIG_HOME says.
  mkdir -p "$HOME/.config/vitrum"
  [[ -n "$1" ]] && printf '{"clipboard":{"images":%s}}\n' "$1" > "$HOME/.config/vitrum/settings.json"
  # Newest first, as cliphist lists: 3 images among text.
  printf '9\t[[ binary data 2 KiB png 10x10 ]]\n8\thello\n7\t[[ binary data 3 KiB jpg 9x9 ]]\n6\tworld\n5\t[[ binary data 1 KiB png 4x4 ]]\n' > "$HOME/list"
  stub cliphist 'echo "cliphist $*" >> "$HOME/calls"; case "$*" in *store*) cat > "$HOME/stored";; *list*) cat "$HOME/list";; *delete*) cat >> "$HOME/deleted";; esac'
}

test_text_is_stored_without_a_limit_and_nothing_trimmed() {
  _clip_world 2
  printf 'some text' | "$VITRUM_DIR/tools/vitrum-clip" store
  assert_eq "$(cat "$HOME/stored")" "some text"
  assert_contains "$(cat "$HOME/calls")" "-max-items 1000000000 store"
  # Text cannot add a picture: the history is not even listed.
  [[ ! -e "$HOME/deleted" ]] && ! grep -q list "$HOME/calls"
}
test_a_picture_trims_pictures_to_the_cap() {
  _clip_world 2
  printf 'PNG' | "$VITRUM_DIR/tools/vitrum-clip" store image
  # The oldest picture goes; the two newest stay, and no text is touched.
  assert_eq "$(cat "$HOME/deleted")" "$(printf '5\t[[ binary data 1 KiB png 4x4 ]]')"
}

test_default_cap_is_500() {
  _clip_world ""
  "$VITRUM_DIR/tools/vitrum-clip" prune
  [[ ! -s "$HOME/deleted" ]]
}

test_cap_zero_keeps_no_images() {
  _clip_world 0
  "$VITRUM_DIR/tools/vitrum-clip" prune
  assert_eq "$(wc -l < "$HOME/deleted" | tr -d ' ')" "3"
}
