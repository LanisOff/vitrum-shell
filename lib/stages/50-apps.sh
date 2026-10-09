#!/usr/bin/env bash
# Stage: apps — Settings, Disk Utility, About.
#
# Each is its own Quickshell config (vitrum-settings, vitrum-disks,
# vitrum-about), so it can be opened, closed and crashed independently of the
# shell. They share the installed shell's theme, components, services, lib and
# data through symlinks — the same look, and one place to change it.

APPS=(
  "settings|Settings|preferences-system|Settings;System;"
  "disks|Disk Utility|drive-harddisk|System;Utility;"
  "about|About this computer|computer|System;"
)

stage_apps() {
  stage "Applications"
  local qsbin="qs"; have qs || qsbin="quickshell"
  local entry
  for entry in "${APPS[@]}"; do
    IFS='|' read -r name display icon cats <<<"$entry"
    _app_install "$name" "$display" "$icon" "$cats" "$qsbin"
  done
  _apps_version
  _apps_polkit
  _apps_remove_tahoe
  stage_done
}

# _app_install <dir> <Display Name> <icon> <categories> <qsbin>
_app_install() {
  local name="$1" display="$2" icon="$3" cats="$4" qsbin="$5"
  local dest="$XDG_CONFIG_HOME/quickshell/vitrum-$name" shell="$XDG_CONFIG_HOME/quickshell/vitrum" d

  step "$display"
  # The repo's links point into the repo; they are replaced below. Removing
  # them first keeps rsync from tripping over a link that became a directory.
  if [[ "$DRY_RUN" != "1" ]]; then
    for d in theme components services lib data common; do rm -rf "${dest:?}/$d"; done
  fi
  install_tree "$VITRUM_DIR/apps/$name" "$dest"
  if [[ "$DRY_RUN" != "1" ]]; then
    rm -rf "${dest:?}/common"
    cp -a "$VITRUM_DIR/apps/common" "$dest/common"
    for d in theme components services lib data; do ln -sfn "$shell/$d" "$dest/$d"; done
  fi

  # A Quickshell config gets no argv: --pane becomes the environment.
  write_file "$HOME/.local/bin/vitrum-$name" <<EOF
#!/usr/bin/env bash
# vitrum-$name — $display. Written by the vitrum installer.
while [ \$# -gt 0 ]; do
  case "\$1" in
    --pane) export VITRUM_PANE="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
exec $qsbin -p "\${XDG_CONFIG_HOME:-\$HOME/.config}/quickshell/vitrum-$name/shell.qml"
EOF
  [[ "$DRY_RUN" == "1" ]] || chmod +x "$HOME/.local/bin/vitrum-$name"

  write_file "$XDG_DATA_HOME/applications/vitrum-$name.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$display
Exec=$HOME/.local/bin/vitrum-$name
Icon=$icon
Terminal=false
Categories=$cats
StartupNotify=true
StartupWMClass=vitrum-$name
EOF
}

# What About shows as the vitrum version.
_apps_version() {
  local v
  v="$(git -C "$VITRUM_DIR" describe --tags --always --dirty 2>/dev/null || cat "$VITRUM_DIR/VERSION" 2>/dev/null || echo unknown)"
  [[ "$DRY_RUN" == "1" ]] && return 0
  mkdir -p "$XDG_DATA_HOME/vitrum" && printf '%s\n' "$v" > "$XDG_DATA_HOME/vitrum/version"
}

# ----------------------------------------------------------------- polkit ----

_apps_polkit() {
  step "polkit rule for Disk Utility"
  # Disk Utility drives udisks2. Mounting and ejecting need no password in an
  # active local session for wheel members; anything destructive always asks.
  sudo_write /etc/polkit-1/rules.d/49-vitrum-disks.rules <<'EOF'
// vitrum: an active local session (wheel) mounts, unmounts and ejects drives
// without a prompt. Formatting, partitioning and encryption always authenticate.
polkit.addRule(function(action, subject) {
    if (!subject.local || !subject.active) return polkit.Result.NOT_HANDLED;
    var safe = [
        "org.freedesktop.udisks2.filesystem-mount",
        "org.freedesktop.udisks2.filesystem-mount-system",
        "org.freedesktop.udisks2.filesystem-unmount-others",
        "org.freedesktop.udisks2.eject-media",
        "org.freedesktop.udisks2.power-off-drive",
        "org.freedesktop.udisks2.ata-smart-selftest",
        "org.freedesktop.udisks2.ata-check-power"
    ];
    if (safe.indexOf(action.id) >= 0 && subject.isInGroup("wheel"))
        return polkit.Result.YES;
    if (action.id.indexOf("org.freedesktop.udisks2.modify-device") === 0 ||
        action.id.indexOf("org.freedesktop.udisks2.open-device")   === 0)
        return polkit.Result.AUTH_ADMIN;
    return polkit.Result.NOT_HANDLED;
});
EOF
  if [[ -e /etc/polkit-1/rules.d/49-niri-tahoe-disks.rules ]]; then run sudo rm -f /etc/polkit-1/rules.d/49-niri-tahoe-disks.rules; fi
}

# The niri-tahoe apps and the Nemo "Finder" entries would sit next to ours.
_apps_remove_tahoe() {
  local f
  for f in "$HOME"/.local/bin/niri-tahoe-{settings,diskutility,about} \
           "$XDG_DATA_HOME"/applications/niri-tahoe-{settings,diskutility,about}.desktop \
           "$XDG_DATA_HOME/applications/finder.desktop" \
           "$XDG_CONFIG_HOME"/quickshell/niri-tahoe-{settings,diskutility,about}; do
    [[ -e "$f" || -L "$f" ]] || continue
    backup_path "$f"
    run rm -rf "$f"
  done
}
