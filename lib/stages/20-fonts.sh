#!/usr/bin/env bash
# Stage: fonts — the UI and icon fonts, the cursor, and fontconfig aliases.
#
# Inter, JetBrains Mono (plain and Nerd), Noto and Noto Color Emoji come from
# the distribution (packages stage). Material Symbols Rounded, Apple's colour
# emoji (samuelngs/apple-emoji-ttf) and the Bibata cursor are not packaged on
# Gentoo, so they are fetched with pinned checksums on every distribution
# (lib/assets.tsv) — one path, no surprises. Noto stays as the emoji fallback.

stage_fonts() {
  stage "Fonts"

  step "icon font, emoji and cursor"
  fetch_asset material-symbols
  fetch_asset apple-emoji
  fetch_asset bibata

  _fonts_configure

  step "rebuilding the font cache"
  run_ok fc-cache -f >/dev/null 2>&1 || warn "fc-cache failed"
  stage_done
}

# Generic families point at the vitrum faces, so GTK, Qt and the terminal agree
# with the shell. The shell itself names its faces through settings.
_fonts_configure() {
  local dir="$XDG_CONFIG_HOME/fontconfig/conf.d"
  if [[ -e "$dir/50-niri-tahoe.conf" ]]; then
    backup_path "$dir/50-niri-tahoe.conf"
    run rm -f "$dir/50-niri-tahoe.conf"
  fi
  write_file "$dir/50-vitrum.conf" <<'XML'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- Written by the vitrum installer. -->
<fontconfig>
  <alias binding="same"><family>sans-serif</family><prefer><family>Inter</family><family>Noto Sans</family><family>Apple Color Emoji</family><family>Noto Color Emoji</family></prefer></alias>
  <alias binding="same"><family>serif</family><prefer><family>Noto Serif</family><family>Apple Color Emoji</family><family>Noto Color Emoji</family></prefer></alias>
  <alias binding="same"><family>monospace</family><prefer><family>JetBrains Mono</family><family>JetBrainsMono Nerd Font</family><family>Apple Color Emoji</family><family>Noto Color Emoji</family></prefer></alias>
  <alias binding="same"><family>emoji</family><prefer><family>Apple Color Emoji</family><family>Noto Color Emoji</family></prefer></alias>
  <!-- Inter: tabular figures and the disambiguated forms by default -->
  <match target="font">
    <test name="family"><string>Inter</string></test>
    <edit name="fontfeatures" mode="append"><string>tnum on</string><string>cv11 on</string></edit>
  </match>
</fontconfig>
XML
  ok "fontconfig: sans-serif → Inter, monospace → JetBrains Mono, emoji → Apple Color Emoji"
}
