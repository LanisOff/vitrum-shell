# shellcheck shell=bash disable=SC1090,SC1091
# fetch_asset: download, verify sha256, place. curl is stubbed to copy a fixture.
_fixture() {
  mkdir -p "$HOME/fx/Theme"; printf 'cursor' > "$HOME/fx/Theme/index.theme"
  tar -C "$HOME/fx" -cJf "$HOME/fx/theme.tar.xz" Theme
  printf 'fontdata' > "$HOME/fx/font.ttf"
  # curl -fL ... -o <dest> <url>: copy the fixture named by the url's basename
  stub curl 'out=""; url=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift;; http*) url="$1";; esac; shift; done; cp "$HOME/fx/${url##*/}" "$out"'
}
_sum() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d" " -f1; else shasum -a 256 "$1" | cut -d" " -f1; fi; }
_table() {
  printf 'font\thttps://x/font.ttf\t%s\tfile\t%s\n' "$1" "$HOME/out/fonts/Font.ttf" > "$HOME/assets.tsv"
  printf 'theme\thttps://x/theme.tar.xz\t%s\ttar\t%s\n' "$2" "$HOME/out/icons" >> "$HOME/assets.tsv"
  export VITRUM_ASSETS_TABLE="$HOME/assets.tsv"
}
_load() { source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/assets.sh"; }

test_fetch_file_with_right_sum() {
  _fixture; _table "$(_sum "$HOME/fx/font.ttf")" x; _load
  fetch_asset font
  assert_eq "$(cat "$HOME/out/fonts/Font.ttf")" fontdata
}
test_fetch_wrong_sum_fails_and_writes_nothing() {
  _fixture; _table 0000 x; _load
  ! (fetch_asset font) 2>/dev/null
  [[ ! -e "$HOME/out/fonts/Font.ttf" ]]
}
test_fetch_tar_unpacks_into_dest() {
  _fixture; _table x "$(_sum "$HOME/fx/theme.tar.xz")"; _load
  fetch_asset theme
  assert_eq "$(cat "$HOME/out/icons/Theme/index.theme")" cursor
}
test_fetch_skips_when_already_verified() {
  _fixture; _table "$(_sum "$HOME/fx/font.ttf")" x; _load
  fetch_asset font
  stub curl 'echo called >> "$HOME/curlcalls"'
  fetch_asset font
  [[ ! -e "$HOME/curlcalls" ]]
}
test_unknown_asset_dies() {
  _fixture; _table x x; _load
  ! (fetch_asset nope) 2>/dev/null
}
test_real_table_is_well_formed() {
  awk -F'\t' '!/^#/ && NF && (NF!=5 || length($3)!=64) {print "line "NR; bad=1} END{exit bad}' "$VITRUM_DIR/lib/assets.tsv"
}
test_stage_fonts_writes_vitrum_fontconfig_and_drops_tahoe() {
  stub fc-cache
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/assets.sh"; source "$VITRUM_DIR/lib/stages/20-fonts.sh"
  fetch_asset() { echo "$1" >> "$HOME/fetched"; }
  mkdir -p "$XDG_CONFIG_HOME/fontconfig/conf.d"; echo old > "$XDG_CONFIG_HOME/fontconfig/conf.d/50-niri-tahoe.conf"
  stage_fonts >/dev/null
  conf="$(cat "$XDG_CONFIG_HOME/fontconfig/conf.d/50-vitrum.conf")"
  assert_contains "$conf" "<family>Inter</family>"
  assert_contains "$conf" "<family>JetBrains Mono</family>"
  # Apple's emoji first, Noto's for anything it lacks.
  assert_contains "$conf" "<family>emoji</family><prefer><family>Apple Color Emoji</family><family>Noto Color Emoji</family>"
  [[ ! -e "$XDG_CONFIG_HOME/fontconfig/conf.d/50-niri-tahoe.conf" ]]
  assert_eq "$(sort "$HOME/fetched" | tr '\n' ' ')" "apple-emoji bibata material-symbols "
}
