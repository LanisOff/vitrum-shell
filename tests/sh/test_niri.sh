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

# runit has no systemd for niri's systemd feature to talk to: built without it, as Void does.
test_runit_builds_without_the_systemd_feature() {
  _load
  INIT_BACKEND=runit; assert_eq "$(niri_cargo_features | tr '\n' ' ')" "--no-default-features --features dbus,xdp-gnome-screencast "
  INIT_BACKEND=systemd; assert_eq "$(niri_cargo_features)" ""
  INIT_BACKEND=openrc; assert_eq "$(niri_cargo_features)" ""
}
test_build_passes_features_and_keeps_a_given_target_cpu() {
  _load; export INIT_BACKEND=runit BUILD_DIR="$HOME/build" NIRI_SRC="$HOME/src"; mkdir -p "$NIRI_SRC"
  stub cargo 'echo "cargo $* RUSTFLAGS=$RUSTFLAGS" >> "$HOME/calls"'
  RUSTFLAGS="-C target-cpu=x86-64" _niri_build >/dev/null 2>&1
  c="$(cat "$HOME/calls")"
  assert_contains "$c" "--no-default-features --features dbus,xdp-gnome-screencast"
  assert_contains "$c" "target-cpu=x86-64"
  ! grep -q native <<<"$c"
}
test_install_takes_the_binary_from_cargo_target_dir() {
  _load; export CARGO_TARGET_DIR="$HOME/tgt" VITRUM_NIRI_BIN="$HOME/bin/niri"
  mkdir -p "$CARGO_TARGET_DIR/release" "$HOME/bin"; printf '#!/bin/sh\necho niri 26.04\n' > "$CARGO_TARGET_DIR/release/niri"
  _niri_install >/dev/null 2>&1
  [[ -x "$VITRUM_NIRI_BIN" ]]
}
