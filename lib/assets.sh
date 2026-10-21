# shellcheck shell=bash
# Upstream assets with pinned URLs and checksums (lib/assets.tsv).

VITRUM_ASSETS_TABLE="${VITRUM_ASSETS_TABLE:-$VITRUM_DIR/lib/assets.tsv}"

_sha256() {
  if have sha256sum; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# _asset_row <name> — sets _a_url _a_sum _a_kind _a_dest from the table.
_asset_row() {
  local row
  row="$(awk -F'\t' -v n="$1" '!/^#/ && $1 == n' "$VITRUM_ASSETS_TABLE")"
  [[ -n "$row" ]] || die 'unknown asset: %s' "$1"
  IFS=$'\t' read -r _ _a_url _a_sum _a_kind _a_dest _ <<<"$row"
  _a_dest="${_a_dest/#\~/$HOME}"
}


# assets_wanted — the assets this run needs, one per line: every one that
# stands in for no package, and the ones standing in for a row this run needs
# that the distribution does not package (Void has no JetBrains Mono, no
# distribution packages its Nerd Font on its own). Without the package table
# (PKG_BACKEND unset) only the first kind.
assets_wanted() {
  local gaps=" "
  if [[ -n "${PKG_BACKEND:-}" ]] && declare -F packages_unpackaged >/dev/null; then
    local needs=()
    mapfile -t needs < <(_package_needs)
    gaps+="$(packages_unpackaged "${needs[@]}" | tr '\n' ' ')"
  fi
  awk -F'\t' -v gaps="$gaps" '!/^#/ && NF {
    f = ($6 == "" ? "-" : $6)
    if (f == "-" || index(gaps, " " f " ")) print $1 }' "$VITRUM_ASSETS_TABLE"
}

# asset_names — the same: the assets of this run. A row standing in for a
# package of another distribution (a LADSPA plugin in /usr/local/lib on Void)
# is no asset of a run on this one.
asset_names() { assets_wanted; }

# asset_missing <name> — true when fetch_asset would fetch it: the destination
# is absent or the stamp does not carry the pinned checksum.
asset_missing() {
  local _a_url _a_sum _a_kind _a_dest
  _asset_row "$1"
  [[ ! -e "$_a_dest" || "$(cat "$VITRUM_STATE/assets/$1.sha256" 2>/dev/null)" != "$_a_sum" ]]
}

# fetch_asset <name> — download, verify, place. A verified asset is not fetched again.
fetch_asset() {
  local name="$1" _a_url _a_sum _a_kind _a_dest
  _asset_row "$name"
  local url="$_a_url" sum="$_a_sum" kind="$_a_kind" dest="$_a_dest"

  local stamp="$VITRUM_STATE/assets/$name.sha256"
  if ! asset_missing "$name"; then
    dim "$name already in place"; return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then dim "would fetch $name into $dest"; return 0; fi

  local tmp="$BUILD_DIR/assets/$name.download"
  mkdir -p "$(dirname "$tmp")"
  curl -fL --retry 3 --silent --show-error -o "$tmp" "$url" || die 'could not download %s from %s' "$name" "$url"
  local got; got="$(_sha256 "$tmp")"
  if [[ "$got" != "$sum" ]]; then
    rm -f "$tmp"
    die '%s: checksum mismatch (expected %s, got %s) — not installed' "$name" "$sum" "$got"
  fi
  # Outside $HOME (a LADSPA plugin in /usr/local/lib) it is root's to write,
  # and an archive's owners are not kept there.
  local as=() own=()
  if [[ "$dest" != "$HOME"/* ]]; then as=(sudo); own=(--no-same-owner); fi
  case "$kind" in
    file) "${as[@]}" mkdir -p "$(dirname "$dest")" && "${as[@]}" install -m644 "$tmp" "$dest" ;;
    tar)  "${as[@]}" mkdir -p "$dest" && "${as[@]}" tar "${own[@]}" -xf "$tmp" -C "$dest" ;;
    zip)  "${as[@]}" mkdir -p "$dest" && "${as[@]}" unzip -oq "$tmp" -d "$dest" ;;
    # zip:<pattern> — only the members matching it, without their folders.
    zip:*) "${as[@]}" mkdir -p "$dest" && "${as[@]}" unzip -ojq "$tmp" "${kind#zip:}" -d "$dest" ;;
    *) die 'asset %s: unknown kind %s' "$name" "$kind" ;;
  esac || { rm -f "$tmp"; die 'could not unpack %s into %s' "$name" "$dest"; }
  rm -f "$tmp"
  mkdir -p "$(dirname "$stamp")" && printf '%s\n' "$sum" > "$stamp"
  ok "$name installed"
}

# font_cache_refresh — fc-cache -f, and when it fails, its own words in the
# warning: a bare "fc-cache failed" sends someone to rerun it by hand just to
# learn why. The usual why is a cache or font directory left owned by root by
# an earlier sudo, so that gets named with the command that fixes it.
font_cache_refresh() {
  if [[ "$DRY_RUN" == "1" ]]; then dim "would run: fc-cache -f"; return 0; fi
  local out
  out="$(fc-cache -f 2>&1)" && return 0
  if [[ -n "$out" ]]; then warn 'fc-cache failed: %s' "$(head -n1 <<<"$out")"; else warn 'fc-cache failed'; fi
  local line
  while IFS= read -r line; do [[ -n "$line" ]] && dim "$line"; done < <(sed -n '2,6p' <<<"$out")
  local dir stray
  for dir in "$XDG_CACHE_HOME/fontconfig" "$XDG_DATA_HOME/fonts"; do
    # A folder that does not exist yet is nobody's: find fails there, which is no reason to stop.
    stray="$(find "$dir" ! -user "$(id -u)" -print -quit 2>/dev/null)" || stray=""
    [[ -n "$stray" ]] && info "$stray belongs to someone else — sudo chown -R $(id -un): $dir"
  done
  return 0
}
