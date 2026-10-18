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
  [[ -n "$row" ]] || die "unknown asset: $1"
  IFS=$'\t' read -r _ _a_url _a_sum _a_kind _a_dest <<<"$row"
  _a_dest="${_a_dest/#\~/$HOME}"
}

# asset_names — every asset in the table, one per line.
asset_names() { awk -F'\t' '!/^#/ && NF { print $1 }' "$VITRUM_ASSETS_TABLE"; }

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
  curl -fL --retry 3 --silent --show-error -o "$tmp" "$url" || die "could not download $name from $url"
  local got; got="$(_sha256 "$tmp")"
  if [[ "$got" != "$sum" ]]; then
    rm -f "$tmp"
    die "$name: checksum mismatch (expected $sum, got $got) — not installed"
  fi
  case "$kind" in
    file) mkdir -p "$(dirname "$dest")" && install -m644 "$tmp" "$dest" ;;
    tar)  mkdir -p "$dest" && tar -xf "$tmp" -C "$dest" ;;
    *) die "asset $name: unknown kind $kind" ;;
  esac
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
  warn "fc-cache failed${out:+: $(head -n1 <<<"$out")}"
  local line
  while IFS= read -r line; do [[ -n "$line" ]] && dim "$line"; done < <(sed -n '2,6p' <<<"$out")
  local dir stray
  for dir in "$XDG_CACHE_HOME/fontconfig" "$XDG_DATA_HOME/fonts"; do
    stray="$(find "$dir" ! -user "$(id -u)" -print -quit 2>/dev/null)"
    [[ -n "$stray" ]] && info "$stray belongs to someone else — sudo chown -R $(id -un): $dir"
  done
  return 0
}
