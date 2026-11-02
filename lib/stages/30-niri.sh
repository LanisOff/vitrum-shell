#!/usr/bin/env bash
# Stage: niri — build the compositor with liquid glass.
#
# niri from a pinned commit of main with our patches on top (patches/niri, the
# glass among them); one build path on every distribution, packages only
# supply the toolchain. On Arch and its relatives a binary of that same build,
# made by .github/workflows/niri-binary.yml, can stand in for compiling: tried
# first when it is the choice, and anything wrong with it means compiling.

NIRI_REPO="https://github.com/YaLTeR/niri.git"
NIRI_REV="a8562a1126922ed4c1c94d34c1dbb26633491d05"     # main, 2026-10-31
NIRI_SRC="$BUILD_DIR/niri"
NIRI_PATCHES="$VITRUM_DIR/patches/niri"
VITRUM_NIRI_BIN="${VITRUM_NIRI_BIN:-/usr/local/bin/niri}"
# Where earlier installs put it, under another name; moved to niri.
VITRUM_NIRI_OLD="${VITRUM_NIRI_OLD:-/usr/local/bin/vitrum-niri}"
# Where the prebuilt niri is published: <tag>/<asset>, niri_release_tag and
# niri_release_asset below.
NIRI_RELEASES="https://github.com/LanisOff/vitrum-shell/releases/download"
# Why the prebuilt niri was not used, in the device's language.
_NIRI_WHY=""

stage_niri() {
  stage "Compositor (niri with liquid glass)"
  _niri_rename_old
  if _niri_up_to_date; then
    ok "niri is up to date (${NIRI_REV:0:7})"
    stage_done; return 0
  fi
  if niri_prebuilt_wanted; then
    if _niri_prebuilt; then stage_done; return 0; fi
    _niri_build_deps
  fi
  _niri_fetch "$NIRI_REPO" "$NIRI_REV" "$NIRI_SRC"
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

# What niri.rev records: the pin, and a checksum of the patches, so changing a
# patch rebuilds too. Builds from before carry the overlay's pin in theirs, so
# they never match.
niri_stamp() {
  local stamp="$NIRI_REV" p sums=""
  for p in "$NIRI_PATCHES"/*.patch; do
    [[ -e "$p" ]] && sums+="$(cksum < "$p")"
  done
  [[ -n "$sums" ]] && stamp+="+p$(printf '%s' "$sums" | cksum | cut -d' ' -f1)"
  printf '%s\n' "$stamp"
}

# niri_release_tag / niri_release_asset — the stamp's release and archive.
# GitHub renames an asset with a + in its name, so the stamp goes in with a -.
niri_release_tag() { local s; s="$(niri_stamp)"; printf 'niri-%s\n' "${s//+/-}"; }
niri_release_asset() { printf '%s-arch-x86_64.tar.zst\n' "$(niri_release_tag)"; }

# niri_installed_kind — prebuilt or compiled. Everything from before the choice
# was compiled, and left no niri.source.
niri_installed_kind() {
  if [[ "$(cat "$VITRUM_STATE/niri.source" 2>/dev/null)" == prebuilt ]]; then echo prebuilt; else echo compiled; fi
}

# Up to date means the stamp matches and it still runs: a system upgrade can
# take a library away from a niri that was fine, compiled or not, and the
# weekly prebuilt binary is how that one gets repaired. Compile, chosen over a
# prebuilt niri, counts as a change; the other way round a compiled niri stays.
_niri_up_to_date() {
  [[ "${FRESH:-0}" == "1" ]] && return 1
  [[ -x "$VITRUM_NIRI_BIN" ]] || return 1
  [[ "$(cat "$VITRUM_STATE/niri.rev" 2>/dev/null)" == "$(niri_stamp)" ]] || return 1
  [[ "${VITRUM_NIRI_SOURCE:-}" == compile && "$(niri_installed_kind)" == prebuilt ]] && return 1
  "$VITRUM_NIRI_BIN" --version >/dev/null 2>&1
}

# niri_needs_build — 0 when this stage has a new niri to put in place (the
# stamp does not match, or --fresh). The same test the stage makes, nothing
# changed. The estimate and the disk space row ask niri_prebuilt_wanted too,
# to tell a download from a build.
niri_needs_build() { ! _niri_up_to_date; }

# _niri_fetch <repo> <rev> <dir> — exactly that revision, clean tree. niri keeps
# its wiki's images in Git LFS: nothing here needs them, and a machine with the
# filter set up but no git-lfs would fail the checkout.
_niri_fetch() {
  local repo="$1" rev="$2" dir="$3"
  local nolfs=(-c filter.lfs.process= -c filter.lfs.smudge=cat -c filter.lfs.clean=cat -c filter.lfs.required=false)
  step "fetching ${repo##*/} @ ${rev:0:7}"
  if [[ ! -d "$dir/.git" ]]; then
    run mkdir -p "$dir"
    run git -C "$dir" init -q
    run git -C "$dir" remote add origin "$repo"
  fi
  run git -C "$dir" fetch -q --depth 1 origin "$rev"
  run git "${nolfs[@]}" -C "$dir" checkout -q --force FETCH_HEAD
  run git -C "$dir" clean -qfdx -e target
}

# Our patches on top of upstream (patches/niri/*.patch, in order).
_niri_apply_patches() {
  local p
  for p in "$NIRI_PATCHES"/*.patch; do
    [[ -e "$p" ]] || continue
    step "patch ${p##*/}"
    run git -C "$NIRI_SRC" apply "$p"
  done
}

# _niri_prebuilt — this stamp's binary in place of a build, checked first. 1,
# with the reason said once, when compiling has to take over; the niri that is
# there is untouched until the new one has passed everything.
_niri_prebuilt() {
  local dir="$BUILD_DIR/niri-prebuilt" asset url
  asset="$(niri_release_asset)"
  url="$NIRI_RELEASES/$(niri_release_tag)/$asset"
  step "fetching the prebuilt niri"
  if [[ "$DRY_RUN" == "1" ]]; then
    dim "would download $url, check it and fall back to compiling if it cannot run here"
    _niri_install "$dir/niri" prebuilt
    return 0
  fi
  _NIRI_WHY=""
  rm -rf "$dir"
  mkdir -p "$dir"
  if _niri_cpu_ok && _niri_prebuilt_get "$dir" "$url" "$asset" && niri_binary_check "$dir/niri" "$dir/probe.kdl"; then
    _niri_install "$dir/niri" prebuilt
    rm -rf "$dir"
    return 0
  fi
  rm -rf "$dir"
  [[ -z "$_NIRI_WHY" ]] || warn 'prebuilt niri not used: %s — compiling instead (20–40 minutes)' "$_NIRI_WHY"
  return 1
}

# The binary is built for x86-64-v2; on anything older it would pass every
# check below and die on the first instruction a check did not reach.
_niri_cpu_ok() {
  local info="${VITRUM_ROOTFS:-}/proc/cpuinfo"
  [[ -r "$info" ]] || return 0
  grep -qw sse4_2 "$info" && return 0
  _NIRI_WHY="$(L 'this processor is too old for it (it needs x86-64-v2)')"
  return 1
}

# curl gives up on a stalled transfer (a minute under 1 kB/s), and a redirect
# stays on https.
_niri_curl() {
  curl -fL --proto-redir =https --retry 3 --retry-delay 2 --connect-timeout 20 \
       --speed-limit 1024 --speed-time 60 -o "$2" "$1"
}

# _niri_prebuilt_get <dir> <url> <asset> — download, verify, unpack <dir>/niri.
# The checksum comes first: it is small, and it is what says there is no binary
# for this stamp. Nothing is unpacked or run before the sum matches. A mismatch
# is an error of its own, loud, and not just one more reason to compile.
_niri_prebuilt_get() {
  local dir="$1" url="$2" asset="$3" rc=0 want got
  _niri_curl "$url.sha256" "$dir/$asset.sha256" && _niri_curl "$url" "$dir/$asset" || rc=$?
  if (( rc == 22 )); then
    _NIRI_WHY="$(L 'there is no binary for this version')"
    return 1
  elif (( rc != 0 )); then
    _NIRI_WHY="$(L 'the download failed (curl error %s)' "$rc")"
    return 1
  fi
  want="$(cut -d' ' -f1 "$dir/$asset.sha256")"
  got="$(sha256sum "$dir/$asset" | cut -d' ' -f1)"
  if [[ ! "$want" =~ ^[0-9a-f]{64}$ || "$got" != "$want" ]]; then
    err 'CHECKSUM MISMATCH: the prebuilt niri from %s is not what was published, it was deleted unused — compiling instead (20–40 minutes)' "$url"
    return 1
  fi
  if ! tar --zstd -xf "$dir/$asset" -C "$dir" niri || [[ ! -x "$dir/niri" ]]; then
    _NIRI_WHY="$(L 'the archive could not be unpacked')"
    return 1
  fi
}

# niri_binary_check <binary> <scratch file> — 0 when it can run here and is the
# niri with vitrum's glass, else the reason in _NIRI_WHY. A library or glibc
# older than the build shows in ldd, whose line is short enough to name it; the
# glass in a config niri must accept, the same probe as niri_caps
# (tools/vitrum_theme). The workflow runs this on what it is about to publish.
niri_binary_check() {
  local bin="$1" probe="$2" out line
  out="$(ldd "$bin" 2>&1)" || true
  if [[ "$out" == *"not found"* ]]; then
    line="$(grep -m1 'not found' <<<"$out")"
    line="${line##*version }"; line="${line%% not found*}"; line="${line%% =>*}"
    line="${line//[\`\'[:space:]]/}"
    _NIRI_WHY="$(L 'this system lacks %s, which it was built against (a full system update may bring it)' "$line")"
    return 1
  fi
  if ! "$bin" --version >/dev/null 2>&1 </dev/null; then
    _NIRI_WHY="$(L 'it does not start on this system')"
    return 1
  fi
  cat > "$probe" <<'KDL'
layer-rule {
    match namespace="^vitrum-probe$"
    background-effect {
        liquid-glass {
            shape-fillet 1.0
            sheen 1.0
        }
    }
}
KDL
  if ! "$bin" validate -c "$probe" >/dev/null 2>&1 </dev/null; then
    _NIRI_WHY="$(L 'it does not accept the glass options')"
    return 1
  fi
}

# What the prebuilt niri left out (lib/components.sh), now that it did not work
# out. A full run has the rest of the packages by now.
_niri_build_deps() {
  local todo=() p
  while IFS= read -r p; do
    pkg_installed "$p" || todo+=("$p")
  done < <(packages_for niri-build)
  [[ ${#todo[@]} -gt 0 ]] || return 0
  step "installing what compiling takes: ${todo[*]}"
  pkg_install "${todo[@]}"
}

# niri's systemd feature (the global environment, apps in transient scopes)
# only makes D-Bus calls to systemd, and runit has none; Void's own niri
# package is built the same way.
niri_cargo_features() {
  case "${INIT_BACKEND:-}" in
    runit) printf '%s\n' --no-default-features --features dbus,xdp-gnome-screencast ;;
  esac
}

# Where cargo puts the binary: target/ in the tree, or CARGO_TARGET_DIR.
_niri_target() { printf '%s\n' "${CARGO_TARGET_DIR:-$NIRI_SRC/target}"; }

_niri_build() {
  local jobs feats=() flags="${RUSTFLAGS:-}"; jobs="$(half_jobs)"
  mapfile -t feats < <(niri_cargo_features)
  # A target-cpu given in RUSTFLAGS wins over native: an emulated CPU (Rosetta)
  # advertises instructions it cannot run, and the build crashes.
  [[ "$flags" == *target-cpu* ]] || flags+=" -C target-cpu=native"
  step "building (20–40 minutes, $jobs jobs)"
  info "progress: tail -f $BUILD_DIR/niri-build.log"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would run: cargo build --release${feats[*]:+ ${feats[*]}}"; return 0; fi
  mkdir -p "$BUILD_DIR"
  if ! ( cd "$NIRI_SRC" && RUSTFLAGS="$flags" cargo build --release --locked --jobs "$jobs" "${feats[@]}" ) \
       > "$BUILD_DIR/niri-build.log" 2>&1; then
    tail -n 40 "$BUILD_DIR/niri-build.log" >&2
    die 'niri did not build — full log: %s (the installed niri, if any, is untouched)' "$BUILD_DIR/niri-build.log"
  fi
  ok "built"
}

# _niri_install [binary] [compiled|prebuilt] — the one way in, for both. A copy
# beside the target and a rename: the name is never half a binary, and the niri
# that is running keeps the file it started from.
_niri_install() {
  local src="${1:-$(_niri_target)/release/niri}" kind="${2:-compiled}" tmp="$VITRUM_NIRI_BIN.new"
  step "installing $VITRUM_NIRI_BIN"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would install the binary"; return 0; fi
  if ! sudo install -m755 "$src" "$tmp" || ! sudo mv -f "$tmp" "$VITRUM_NIRI_BIN"; then
    sudo rm -f "$tmp" || true
    die 'could not install %s' "$VITRUM_NIRI_BIN"
  fi
  mkdir -p "$VITRUM_STATE"
  niri_stamp > "$VITRUM_STATE/niri.rev"
  printf '%s\n' "$kind" > "$VITRUM_STATE/niri.source"
  ok "installed $("$VITRUM_NIRI_BIN" --version 2>/dev/null | head -1)"
}
