# shellcheck shell=bash
# Upstream assets with pinned URLs and checksums (lib/assets.tsv).

VITRUM_ASSETS_TABLE="${VITRUM_ASSETS_TABLE:-$VITRUM_DIR/lib/assets.tsv}"

_sha256() {
  if have sha256sum; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# fetch_asset <name> — download, verify, place. A verified asset is not fetched again.
fetch_asset() {
  local name="$1" row url sum kind dest
  row="$(awk -F'\t' -v n="$name" '!/^#/ && $1 == n' "$VITRUM_ASSETS_TABLE")"
  [[ -n "$row" ]] || die "unknown asset: $name"
  IFS=$'\t' read -r _ url sum kind dest <<<"$row"
  dest="${dest/#\~/$HOME}"

  local stamp="$VITRUM_STATE/assets/$name.sha256"
  if [[ -e "$dest" && "$(cat "$stamp" 2>/dev/null)" == "$sum" ]]; then
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
