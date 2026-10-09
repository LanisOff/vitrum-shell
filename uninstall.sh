#!/usr/bin/env bash
#
#  vitrum — reverse install.sh.
#
#  Removes what the installer added, restores every file it backed up, and
#  leaves packages alone: removing packages you may now depend on is not this
#  script's decision.
#
#  Usage:
#    ./uninstall.sh                 remove vitrum, restore backups, keep your settings
#    ./uninstall.sh --purge         also remove ~/.config/vitrum (settings, overrides)
#    ./uninstall.sh --dry-run       show what would happen
#    ./uninstall.sh --yes           never prompt
#
set -euo pipefail

VITRUM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export VITRUM_DIR
# shellcheck source=lib/common.sh
source "$VITRUM_DIR/lib/common.sh"
# shellcheck source=lib/backend/detect.sh
source "$VITRUM_DIR/lib/backend/detect.sh"

VITRUM_SYSROOT="${VITRUM_SYSROOT:-}"
PURGE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge)   PURGE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    --help|-h) sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done
export DRY_RUN ASSUME_YES

[[ "$DRY_RUN" == "1" ]] && warn "dry run — nothing will be modified"
confirm "remove vitrum from this system?" y || die "nothing done"
# Backends are only needed to give the login screen back; removal itself must
# work everywhere.
HAVE_BACKENDS=0
if ( load_backends ) >/dev/null 2>&1; then load_backends; HAVE_BACKENDS=1; fi

_rm() {  # _rm [sudo] <path>... — remove if present
  local use_sudo=""
  [[ "$1" == sudo ]] && { use_sudo=sudo; shift; }
  local p
  for p in "$@"; do
    [[ -e "$p" || -L "$p" ]] || continue
    run $use_sudo rm -rf "$p"
    dim "removed $p"
  done
}

# Stop the shell first, so nothing restarts it while its files disappear.
if [[ "$DRY_RUN" != "1" ]] && [[ -x "$HOME/.local/bin/vitrum-shell" ]]; then
  "$HOME/.local/bin/vitrum-shell" --stop 2>/dev/null || true
fi

if [[ -f "$VITRUM_STATE/previous-dm" ]]; then
  prev="$(cat "$VITRUM_STATE/previous-dm")"
  if [[ $HAVE_BACKENDS == 1 ]]; then
    step "login screen: back to $prev"
    svc_enable_display_manager "$prev" force
  else
    warn "could not detect the init system — re-enable $prev as your login screen yourself"
  fi
fi

step "system files"
_rm sudo "$VITRUM_SYSROOT/usr/local/bin/niri" "$VITRUM_SYSROOT/usr/local/bin/vitrum-niri" "$VITRUM_SYSROOT/usr/local/bin/vitrum-session" \
         "$VITRUM_SYSROOT/usr/local/share/wayland-sessions/niri.desktop" "$VITRUM_SYSROOT/usr/share/wayland-sessions/vitrum.desktop" \
         "$VITRUM_SYSROOT/etc/systemd/user/niri.service" "$VITRUM_SYSROOT/etc/systemd/user/vitrum-niri.service" \
         "$VITRUM_SYSROOT/usr/local/libexec/vitrum" "$VITRUM_SYSROOT/usr/share/xdg-desktop-portal/portals/vitrum.portal" \
         "$VITRUM_SYSROOT/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.vitrum.service" \
         "$VITRUM_SYSROOT/usr/share/sddm/themes/vitrum" "$VITRUM_SYSROOT/etc/sddm.conf.d/zz-vitrum.conf" "$VITRUM_SYSROOT/etc/sddm.conf.d/50-vitrum.conf" \
         "$VITRUM_SYSROOT/usr/share/plymouth/themes/vitrum" "$VITRUM_SYSROOT/var/lib/vitrum"
# The boot splash the system had before (initramfs: rebuild it yourself, as for the install).
if [[ -s "$VITRUM_STATE/previous-plymouth" ]] && have plymouth-set-default-theme; then
  run sudo plymouth-set-default-theme "$(cat "$VITRUM_STATE/previous-plymouth")"
  warn "the boot splash lives in the initramfs: rebuild it (dracut --force / mkinitcpio -P) to drop the vitrum one"
fi
# Packages vitrum installed are in @world and need these keywords; removing
# them would break the next world update. Only --purge takes them.
portage_files=()
for kind in package.accept_keywords package.use package.env; do
  portage_files+=("$VITRUM_SYSROOT/etc/portage/$kind/50-vitrum" "$VITRUM_SYSROOT/etc/portage/$kind/zz-vitrum-autounmask")
done
portage_files+=("$VITRUM_SYSROOT/etc/portage/env/vitrum-half-jobs.conf")
if [[ "$PURGE" == "1" ]]; then
  _rm sudo "${portage_files[@]}"
else
  for f in "${portage_files[@]}"; do
    [[ -e "$f" ]] && { info "kept portage keywords/USE (your @world needs them) — --purge removes them"; break; }
  done
fi

step "your files"
_rm "$HOME/.local/bin/vitrum-shell" "$HOME/.local/bin/vitrum-startup" "$HOME/.local/bin/vitrum-ipc" \
    "$XDG_CONFIG_HOME/quickshell/vitrum" "$XDG_CONFIG_HOME/vitrum/niri" \
    "$XDG_CONFIG_HOME/fontconfig/conf.d/50-vitrum.conf" "$XDG_DATA_HOME/fonts/vitrum" \
    "$XDG_CACHE_HOME/vitrum-build"
# The cursor theme only if we put it there.
[[ -e "$VITRUM_STATE/assets/bibata.sha256" ]] && _rm "$XDG_DATA_HOME/icons/Bibata-Modern-Classic"

step "restoring originals"
# The manifest records, for every path vitrum ever wrote, whether it was the
# user's (saved here, put back) or new (removed).
manifest="$BACKUP_DIR/.manifest"
if [[ -f "$manifest" ]]; then
  while read -r kind rel; do
    [[ -n "$rel" ]] || continue
    if [[ "$rel" == /* ]]; then dest="$VITRUM_SYSROOT$rel"; else dest="$HOME/$rel"; fi
    # kdeglobals is shared with every KDE app: take back only vitrum's colours.
    if [[ "$rel" == ".config/kdeglobals" ]] && have python3; then
      if [[ "$DRY_RUN" == "1" ]]; then dim "would give $dest its own colours back"; continue; fi
      orig=""; [[ "$kind" == saved ]] && orig="$BACKUP_DIR/$rel"
      python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); from vitrum_theme.render import kde_restore; kde_restore(sys.argv[2], sys.argv[3] or None)' \
        "$VITRUM_DIR/tools" "$dest" "$orig" && dim "gave $dest its own colours back" || warn "could not restore the colours in $dest"
      continue
    fi
    case "$kind" in
      saved)
        if [[ "$DRY_RUN" == "1" ]]; then dim "would restore $dest"; continue; fi
        mkdir -p "$(dirname "$dest")"; rm -rf "$dest"; cp -a "$BACKUP_DIR/$rel" "$dest"; dim "restored $dest" ;;
      created)
        _rm "$dest" ;;
    esac
  done < "$manifest"
  # Restored: forget them, so a later install saves the files as they are then.
  _rm "$BACKUP_DIR"
  ok "originals restored"
else
  info "nothing to restore"
fi

if [[ "$PURGE" == "1" ]]; then
  step "purging settings"
  _rm "$VITRUM_PREFIX" "$VITRUM_STATE"
else
  _rm "$VITRUM_STATE/niri.rev"
  info "kept ~/.config/vitrum (settings, overrides) — --purge removes it"
fi

if [[ "$DRY_RUN" != "1" ]] && have fc-cache; then fc-cache -f >/dev/null 2>&1 || true; fi
ok "vitrum removed — log out and pick another session"
