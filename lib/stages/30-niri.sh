#!/usr/bin/env bash
# Stage: niri — build the compositor with liquid glass.
#
# niri v26.04 with the YeFaDa/Niri-glass overlay. The overlay replaces whole
# source files, so both revisions are pinned and built together; one build
# path on every distribution, packages only supply the toolchain.

NIRI_REPO="https://github.com/YaLTeR/niri.git"
NIRI_REV="6a0a862b8089accd72a4b7298817c8d76cc26b7b"     # tag v26.04
GLASS_REPO="https://github.com/YeFaDa/Niri-glass.git"
GLASS_REV="9fa9fc4be6b58590b482c90df63c4e3a70acfc92"    # 2026-09-27
NIRI_SRC="$BUILD_DIR/niri"
GLASS_SRC="$BUILD_DIR/niri-glass"
VITRUM_NIRI_BIN="${VITRUM_NIRI_BIN:-/usr/local/bin/niri}"
# Where earlier installs put it, under another name; moved to niri.
VITRUM_NIRI_OLD="${VITRUM_NIRI_OLD:-/usr/local/bin/vitrum-niri}"

# What the overlay ships: everything else is upstream niri.
OVERLAY_FILES=(
  src/render_helpers/liquid_glass.rs
  src/render_helpers/background_effect.rs
  src/render_helpers/framebuffer_effect.rs
  src/render_helpers/xray.rs
  src/render_helpers/mod.rs
  src/render_helpers/shaders/mod.rs
  src/render_helpers/shaders/clipped_surface.frag
  niri-config/src/appearance.rs
)

stage_niri() {
  stage "Compositor (niri with liquid glass)"
  _niri_rename_old
  if _niri_up_to_date; then
    ok "niri is up to date (niri ${NIRI_REV:0:7}, glass ${GLASS_REV:0:7})"
    stage_done; return 0
  fi
  _niri_fetch "$NIRI_REPO" "$NIRI_REV" "$NIRI_SRC"
  _niri_fetch "$GLASS_REPO" "$GLASS_REV" "$GLASS_SRC"
  _niri_apply_overlay
  _niri_apply_patches
  _niri_build
  _niri_install
  stage_done
}

# Earlier installs named it vitrum-niri. It is niri: the same build, renamed.
_niri_rename_old() {
  [[ -e "$VITRUM_NIRI_OLD" ]] || return 0
  if [[ -x "$VITRUM_NIRI_BIN" ]]; then run sudo rm -f "$VITRUM_NIRI_OLD"; return 0; fi
  step "renaming vitrum-niri to niri"
  run sudo mv -f "$VITRUM_NIRI_OLD" "$VITRUM_NIRI_BIN"
}

# What niri.rev records: both pins, and a checksum of the local patches when
# there are any, so changing a patch rebuilds too.
niri_stamp() {
  local stamp="$NIRI_REV+$GLASS_REV" p sums=""
  for p in "$VITRUM_DIR"/patches/niri-glass/*.patch; do
    [[ -e "$p" ]] && sums+="$(cksum < "$p")"
  done
  [[ -n "$sums" ]] && stamp+="+p$(printf '%s' "$sums" | cksum | cut -d' ' -f1)"
  printf '%s\n' "$stamp"
}

_niri_up_to_date() {
  [[ "${FRESH:-0}" == "1" ]] && return 1
  [[ -x "$VITRUM_NIRI_BIN" ]] || return 1
  [[ "$(cat "$VITRUM_STATE/niri.rev" 2>/dev/null)" == "$(niri_stamp)" ]]
}

# _niri_fetch <repo> <rev> <dir> — exactly that revision, clean tree.
_niri_fetch() {
  local repo="$1" rev="$2" dir="$3"
  step "fetching ${repo##*/} @ ${rev:0:7}"
  if [[ ! -d "$dir/.git" ]]; then
    run mkdir -p "$dir"
    run git -C "$dir" init -q
    run git -C "$dir" remote add origin "$repo"
  fi
  run git -C "$dir" fetch -q --depth 1 origin "$rev"
  run git -C "$dir" checkout -q --force FETCH_HEAD
  run git -C "$dir" clean -qfdx -e target
}

_niri_apply_overlay() {
  step "applying the glass overlay (${#OVERLAY_FILES[@]} files)"
  local f
  for f in "${OVERLAY_FILES[@]}"; do
    [[ "$DRY_RUN" == "1" ]] && continue
    [[ -f "$GLASS_SRC/$f" ]] || die "overlay file missing: $f (Niri-glass ${GLASS_REV:0:7})"
    install -m644 "$GLASS_SRC/$f" "$NIRI_SRC/$f" || die "could not copy $f"
  done
}

# Local fixes on top of the overlay, if any (patches/niri-glass/*.patch, in order).
_niri_apply_patches() {
  local p
  for p in "$VITRUM_DIR"/patches/niri-glass/*.patch; do
    [[ -e "$p" ]] || continue
    step "patch ${p##*/}"
    run git -C "$NIRI_SRC" apply "$p"
  done
}

_niri_build() {
  local jobs; jobs="$(half_jobs)"
  step "building (20–40 minutes, $jobs jobs)"
  info "progress: tail -f $BUILD_DIR/niri-build.log"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would run: cargo build --release"; return 0; fi
  mkdir -p "$BUILD_DIR"
  if ! ( cd "$NIRI_SRC" && RUSTFLAGS="${RUSTFLAGS:-} -C target-cpu=native" cargo build --release --locked --jobs "$jobs" ) \
       > "$BUILD_DIR/niri-build.log" 2>&1; then
    tail -n 40 "$BUILD_DIR/niri-build.log" >&2
    die "niri did not build — full log: $BUILD_DIR/niri-build.log (the installed niri, if any, is untouched)"
  fi
  ok "built"
}

_niri_install() {
  step "installing $VITRUM_NIRI_BIN"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would install the binary"; return 0; fi
  sudo install -m755 "$NIRI_SRC/target/release/niri" "$VITRUM_NIRI_BIN" || die "could not install $VITRUM_NIRI_BIN"
  mkdir -p "$VITRUM_STATE"
  niri_stamp > "$VITRUM_STATE/niri.rev"
  ok "installed $("$VITRUM_NIRI_BIN" --version 2>/dev/null | head -1)"
}
