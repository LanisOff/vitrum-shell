#!/usr/bin/env bash
# Stage: theming — GTK, Qt (Kvantum, qt6ct/qt5ct), the cursor, Dolphin.
#
# Colours are vitrum-theme's job (the terminal stage renders GTK's vitrum.css
# and the Kvantum theme, and every palette change re-renders them). This stage
# sets what points at them: GTK's settings.ini and gsettings, qt6ct/qt5ct
# with the Kvantum style, Kvantum's theme selection, the default cursor, and a
# few Dolphin defaults. Icon theme, cursor and fonts come from settings.json.

stage_theming() {
  stage "Theming"
  local icons cursor font
  icons="$(_theme_setting icons.theme Papirus-Dark)"
  cursor="$(_theme_setting cursor.theme Bibata-Modern-Classic)"
  font="$(_theme_setting fonts.sans Inter)"
  _theme_gtk "$icons" "$cursor" "$font"
  _theme_qt "$icons" "$font"
  _theme_cursor "$cursor"
  _theme_dolphin
  _theme_xdg_dirs
  stage_done
}

# A value from ~/.config/vitrum/settings.json, or the default.
_theme_setting() {
  local key="$1" def="$2" f="$XDG_CONFIG_HOME/vitrum/settings.json" v=""
  if [[ -f "$f" ]] && have python3; then
    v="$(python3 - "$f" "$key" <<'PY'
import json, sys
try:
    cur = json.load(open(sys.argv[1]))
    for part in sys.argv[2].split("."):
        cur = cur[part]
    print(cur if isinstance(cur, str) else "false" if cur is False else "")
except Exception:
    pass
PY
)"
  fi
  printf '%s' "${v:-$def}"
}

# GTK's settings.ini; an empty theme name leaves the line out (GTK's default).
_theme_gtk_ini() {
  local theme="$1" icons="$2" cursor="$3" font="$4"
  echo "[Settings]"
  [[ -n "$theme" ]] && echo "gtk-theme-name=$theme"
  cat <<INI
gtk-icon-theme-name=$icons
gtk-cursor-theme-name=$cursor
gtk-cursor-theme-size=24
gtk-font-name=$font 11
gtk-enable-animations=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-decoration-layout=:close
gtk-overlay-scrolling=true
INI
}

_theme_gtk() {
  local icons="$1" cursor="$2" font="$3"
  step "GTK 3 / 4"
  # adw-gtk3 takes the palette's colours (vitrum.css); GTK 4's own theme does
  # not. vitrum-theme switches it to the light variant with the scheme.
  # toolkits.gtk off ("Colour GTK apps" in Settings): your GTK theme stays —
  # the name already in each settings.ini is kept, gsettings' is not touched.
  local gtk_theme=Adwaita gtk_on=1 v
  [[ "$(_theme_setting toolkits.gtk "")" == false ]] && gtk_on=0
  [[ -d /usr/share/themes/adw-gtk3-dark ]] && gtk_theme=adw-gtk3-dark
  for v in 3 4; do
    local f="$XDG_CONFIG_HOME/gtk-$v.0/settings.ini" name="$gtk_theme"
    if [[ $gtk_on == 0 ]]; then
      name=""
      [[ -f "$f" ]] && name="$(sed -n 's/^gtk-theme-name=//p' "$f" | head -1)"
    fi
    _theme_gtk_ini "$name" "$icons" "$cursor" "$font" | write_file "$f"
  done
  # Wayland GTK apps read gsettings rather than settings.ini. The light/dark
  # color-scheme is vitrum-theme's (it follows the desktop's scheme).
  # Installing from a tty or over ssh there is no session bus, dconf cannot be
  # reached and every set fails quietly: GTK apps stayed on Adwaita icons.
  if have gsettings && [[ "$DRY_RUN" != "1" ]]; then
    local i=org.gnome.desktop.interface
    [[ $gtk_on == 1 ]] && { _gsettings set $i gtk-theme "$gtk_theme" 2>/dev/null || true; }
    _gsettings set $i icon-theme "$icons" 2>/dev/null || true
    _gsettings set $i cursor-theme "$cursor" 2>/dev/null || true
    _gsettings set $i cursor-size 24 2>/dev/null || true
    _gsettings set $i font-name "$font 11" 2>/dev/null || true
    _gsettings set $i font-antialiasing rgba 2>/dev/null || true
    _gsettings set $i font-hinting slight 2>/dev/null || true
    _gsettings set org.gnome.desktop.wm.preferences button-layout ":close" 2>/dev/null || true
  fi
}

# gsettings with a session bus of its own when there is none to talk to.
_gsettings() {
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && have dbus-run-session; then
    dbus-run-session -- gsettings "$@"
  else
    gsettings "$@"
  fi
}

_theme_qt() {
  local icons="$1" font="$2"
  step "Qt (Kvantum)"
  local qfont="\"$font,11,-1,5,50,0,0,0,0,0\"" mono="\"JetBrains Mono,11,-1,5,50,0,0,0,0,0\""
  write_file "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" <<EOF
[Appearance]
style=kvantum
icon_theme=$icons
standard_dialogs=xdgdesktopportal
custom_palette=false

[Fonts]
fixed=$mono
general=$qfont

[Interface]
double_click_interval=400
cursor_flash_time=1000
menus_have_icons=true
toolbutton_style=4
wheel_scroll_lines=3
EOF
  write_file "$XDG_CONFIG_HOME/qt5ct/qt5ct.conf" <<EOF
[Appearance]
style=kvantum
icon_theme=$icons
standard_dialogs=xdgdesktopportal

[Fonts]
fixed=$mono
general=$qfont
EOF
  # The theme itself (Kvantum/vitrum) is rendered by vitrum-theme.
  # vitrumcompact (vitrum-theme writes it too) for dense apps whose layouts were
  # drawn for small frames: vitrum's roomier ones made Throne's shift about.
  write_file "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" <<'EOF'
[General]
theme=vitrum

[Applications]
vitrumcompact=Throne
EOF
  have kvantummanager || dim "Kvantum is not installed — Qt apps use Fusion until it is"
  # The niri-tahoe Kvantum theme.
  if [[ -d "$XDG_CONFIG_HOME/Kvantum/NiriTahoe" ]]; then backup_path "$XDG_CONFIG_HOME/Kvantum/NiriTahoe"; run rm -rf "$XDG_CONFIG_HOME/Kvantum/NiriTahoe"; fi
}

_theme_cursor() {
  local cursor="$1"
  step "cursor"
  write_file "$XDG_DATA_HOME/icons/default/index.theme" <<EOF
[Icon Theme]
Name=Default
Comment=Default cursor theme (written by the vitrum installer)
Inherits=$cursor
EOF
}

# Dolphin is the file manager: a few defaults the first time, your file after.
_theme_dolphin() {
  local rc="$XDG_CONFIG_HOME/dolphinrc"
  [[ -f "$rc" ]] && { dim "keeping your dolphinrc"; return 0; }
  step "Dolphin defaults"
  write_file "$rc" <<'EOF'
[General]
BrowseThroughArchives=true
ShowFullPathInTitlebar=true
RememberOpenedTabs=false
ShowSelectionToggle=true

[DetailsMode]
PreviewSize=22

[IconsMode]
PreviewSize=64

[KFileDialog Settings]
Places Location Limit=0

[MainWindow]
MenuBar=Disabled
ToolBarsMovable=Disabled

[PreviewSettings]
Plugins=appimagethumbnail,audiothumbnail,blenderthumbnail,comicbookthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,fontthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,opendocumentthumbnail,svgthumbnail,ffmpegthumbs
EOF
}

_theme_xdg_dirs() {
  [[ "$DRY_RUN" == "1" ]] && return 0
  if have xdg-user-dirs-update; then xdg-user-dirs-update 2>/dev/null || true; fi
  mkdir -p "$HOME"/{Desktop,Documents,Downloads,Pictures/Screenshots,Pictures/Wallpapers,Music,Videos/Recordings} 2>/dev/null || true
}
