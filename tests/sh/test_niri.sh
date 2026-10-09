# shellcheck shell=bash disable=SC1090,SC1091
_load() {
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/stages/30-niri.sh"
  stub git 'echo "git $*" >> "$HOME/calls"'; stub cargo 'echo "cargo $*" >> "$HOME/calls"'; stub sudo '"$@"'
}
test_up_to_date_build_is_skipped() {
  export VITRUM_NIRI_BIN="$HOME/bin/vitrum-niri"; mkdir -p "$HOME/bin"; printf '#!/bin/sh\n' > "$VITRUM_NIRI_BIN"; chmod +x "$VITRUM_NIRI_BIN"
  _load
  mkdir -p "$VITRUM_STATE"; niri_stamp > "$VITRUM_STATE/niri.rev"
  out="$(stage_niri 2>&1)"
  assert_contains "$out" "up to date"
  [[ ! -e "$HOME/calls" ]]
}
test_changed_overlay_rev_rebuilds() {
  export VITRUM_NIRI_BIN="$HOME/bin/vitrum-niri"; mkdir -p "$HOME/bin"; printf '#!/bin/sh\n' > "$VITRUM_NIRI_BIN"; chmod +x "$VITRUM_NIRI_BIN"
  export DRY_RUN=1; _load
  mkdir -p "$VITRUM_STATE"; printf '%s\n' "$NIRI_REV+oldoverlay" > "$VITRUM_STATE/niri.rev"
  out="$(stage_niri 2>&1)"
  assert_contains "$out" "would run: git"
}
test_pins_are_exact() {
  _load
  assert_eq "$NIRI_REV" 6a0a862b8089accd72a4b7298817c8d76cc26b7b
  assert_eq "$GLASS_REV" 9fa9fc4be6b58590b482c90df63c4e3a70acfc92
  assert_eq "${#OVERLAY_FILES[@]}" 8
}
test_missing_overlay_file_dies() {
  _load
  mkdir -p "$GLASS_SRC" "$NIRI_SRC"
  ! (_niri_apply_overlay) 2>/dev/null
}
# The compositor is niri, by its own name (it was installed as vitrum-niri):
# an up-to-date vitrum-niri is renamed, not rebuilt.
test_installs_as_niri() {
  unset VITRUM_NIRI_BIN; _load
  [[ "$VITRUM_NIRI_BIN" == /usr/local/bin/niri ]]
}
test_old_vitrum_niri_is_renamed_without_a_build() {
  mkdir -p "$HOME/bin"; export VITRUM_NIRI_BIN="$HOME/bin/niri" VITRUM_NIRI_OLD="$HOME/bin/vitrum-niri"
  printf '#!/bin/sh\necho niri 26.04\n' > "$VITRUM_NIRI_OLD"; chmod +x "$VITRUM_NIRI_OLD"
  _load
  mkdir -p "$VITRUM_STATE"; niri_stamp > "$VITRUM_STATE/niri.rev"
  out="$(stage_niri 2>&1)"
  [[ -x "$HOME/bin/niri" && ! -e "$HOME/bin/vitrum-niri" ]] || { echo "$out"; ls "$HOME/bin"; return 1; }
  [[ ! -e "$HOME/calls" ]]   # no fetch, no cargo
}
# A local patch is part of the build: changing one rebuilds.
test_changed_patch_rebuilds() {
  export VITRUM_NIRI_BIN="$HOME/bin/niri"; mkdir -p "$HOME/bin"; printf '#!/bin/sh\n' > "$VITRUM_NIRI_BIN"; chmod +x "$VITRUM_NIRI_BIN"
  export DRY_RUN=1; _load
  mkdir -p "$VITRUM_STATE"; printf '%s\n' "$NIRI_REV+$GLASS_REV" > "$VITRUM_STATE/niri.rev"
  out="$(stage_niri 2>&1)"
  if ls "$VITRUM_DIR"/patches/niri-glass/*.patch >/dev/null 2>&1; then assert_contains "$out" "would run: git"; else assert_contains "$out" "up to date"; fi
}
test_stamp_includes_patches() {
  _load
  if ls "$VITRUM_DIR"/patches/niri-glass/*.patch >/dev/null 2>&1; then assert_contains "$(niri_stamp)" "+p"; fi
  assert_contains "$(niri_stamp)" "$NIRI_REV+$GLASS_REV"
}
