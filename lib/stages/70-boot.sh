#!/usr/bin/env bash
# Stage: boot — the vitrum login screen (SDDM) and boot splash (Plymouth).
#
# Both are optional components (--with/--no-sddm, --with/--no-plymouth) and
# only happen when the program is installed. The initramfs is regenerated only
# with --with-plymouth and a tool we know (dracut, mkinitcpio); the kernel
# command line is never edited — what to add is printed.

SDDM_THEME="${VITRUM_SYSROOT:-}/usr/share/sddm/themes/vitrum"
# zz-: SDDM reads drop-ins in order and the last [Theme] wins.
SDDM_DROPIN="${VITRUM_SYSROOT:-}/etc/sddm.conf.d/zz-vitrum.conf"
SDDM_GREETER_KDL="${VITRUM_SYSROOT:-}/etc/sddm/vitrum-greeter.kdl"
PLY_THEME="${VITRUM_SYSROOT:-}/usr/share/plymouth/themes/vitrum"

stage_boot() {
  stage "Login and boot"
  sudo_refresh   # the steps below write into /usr/share and /etc
  _boot_sddm
  _boot_plymouth
  stage_done
}

# -------------------------------------------------------------- the mark ----

# The vitrum mark as a PNG, from the SVG (rsvg-convert renders it faithfully;
# ImageMagick's own SVG reader drops the gradients).
_boot_mark() {  # _boot_mark <out.png> <size>
  local out="$1" size="$2"
  if have rsvg-convert; then rsvg-convert -w "$size" -h "$size" "$VITRUM_DIR/assets/vitrum-mark.svg" -o "$out"
  elif have magick; then magick -background none -density 300 "$VITRUM_DIR/assets/vitrum-mark.svg" -resize "${size}x${size}" "$out"
  else return 1; fi
}

# ------------------------------------------------------------------ SDDM ----

_boot_sddm() {
  [[ "${WANT_SDDM:-1}" == "1" ]] || { info "SDDM theme: not wanted (--no-sddm)"; return 0; }
  have sddm || { info "SDDM not installed — no login theme"; return 0; }
  step "SDDM theme"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would install $SDDM_THEME and select it"; return 0; fi

  run sudo rm -rf "$SDDM_THEME" "${VITRUM_SYSROOT:-}/usr/share/sddm/themes/niri-tahoe"
  # install, not cp: the greeter runs as the sddm user and must be able to read it whatever our umask.
  run sudo install -d -m 755 "$SDDM_THEME"
  run sudo install -m 644 "$VITRUM_DIR/assets/sddm/vitrum/Main.qml" "$VITRUM_DIR/assets/sddm/vitrum/metadata.desktop" "$SDDM_THEME/"
  # The shell's own glass (plain QtQuick) and its compiled shader, as they are.
  run sudo install -m 644 "$VITRUM_DIR/shell/components/Glass.qml" "$VITRUM_DIR/shell/components/glass.frag.qsb" "$SDDM_THEME/"

  # The desktop's wallpaper (an image; a video gives no background).
  local wall bg=""
  wall="$(_boot_wallpaper)"
  if [[ -n "$wall" ]]; then
    bg="background.${wall##*.}"
    run sudo install -m 644 "$wall" "$SDDM_THEME/$bg"
  fi
  _boot_sddm_conf "$bg" | sudo_write "$SDDM_THEME/theme.conf"

  # The niri-tahoe installer's selection would point at a theme that is gone.
  local old
  for old in "${VITRUM_SYSROOT:-}"/etc/sddm.conf.d/*niri-tahoe*.conf "${VITRUM_SYSROOT:-}/etc/sddm.conf.d/50-vitrum.conf"; do
    [[ -e "$old" ]] || continue
    backup_path "$old"
    run sudo rm -f "$old"
  done
  backup_path "$SDDM_DROPIN"
  local niri_bin="${VITRUM_SYSROOT:-}/usr/local/bin/niri"
  if [[ -x "$niri_bin" ]]; then
    # The greeter on niri (Wayland). SDDM's X server, restarted after a
    # Wayland session on NVIDIA, can hang in driver init — no login comes back.
    backup_path "$SDDM_GREETER_KDL"
    _boot_greeter_kdl | sudo_write "$SDDM_GREETER_KDL"
    _boot_sddm_dropin wayland | sudo_write "$SDDM_DROPIN"
  else
    _boot_sddm_dropin x11 | sudo_write "$SDDM_DROPIN"
  fi
  _boot_sddm_overrides
  dm_use_sddm
  ok "SDDM uses the vitrum theme"
}

# zz-vitrum.conf: the theme, and (with niri) the Wayland greeter.
_boot_sddm_dropin() {  # _boot_sddm_dropin wayland|x11
  printf '# Written by the vitrum installer. Last in sddm.conf.d, so these settings win among drop-ins.\n'
  # QML_XHR_ALLOW_FILE_READ: the theme reads the picked user's login folder
  # (~/.local/share/vitrum/login: wallpaper times, palette) the shell keeps.
  if [[ "$1" == wayland ]]; then
    printf '[General]\nDisplayServer=wayland\nGreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1,QML_XHR_ALLOW_FILE_READ=1\n\n'
    printf '[Wayland]\nCompositorCommand=/usr/local/bin/niri -c /etc/sddm/vitrum-greeter.kdl\n\n'
  else
    printf '[General]\nGreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1\n\n'
  fi
  printf '[Theme]\nCurrent=vitrum\n'
}

# niri for the greeter: every window fullscreen (one per screen), no
# decorations or animations to speak of, and the user's keyboard layouts so the
# password is typed in the layout it was set in.
_boot_greeter_kdl() {
  local layout="us" options=""
  local f="$XDG_CONFIG_HOME/vitrum/niri/config.kdl"
  if [[ -f "$f" ]]; then
    layout="$(sed -n 's/^[[:space:]]*layout[[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -n 1)"
    options="$(sed -n 's/^[[:space:]]*options[[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -n 1)"
  fi
  cat <<EOF
// The SDDM greeter's compositor. Written by the vitrum installer.
input {
    keyboard {
        xkb {
            layout "${layout:-us}"
            options "${options}"
        }
    }
    touchpad {
        tap
    }
}
cursor {
    hide-when-typing
}
hotkey-overlay {
    skip-at-startup
}
prefer-no-csd
screenshot-path null
layout {
    gaps 0
    focus-ring {
        off
    }
    border {
        off
    }
}
window-rule {
    open-fullscreen true
}
EOF
}

# /etc/sddm.conf is read after every drop-in, so a [Theme] Current= there
# still wins. Say so, with the line, rather than claim success.
_boot_sddm_overrides() {
  local f="${VITRUM_SYSROOT:-}/etc/sddm.conf" line
  [[ -f "$f" ]] || return 0
  line="$(awk '/^\[/{sec=$0} sec=="[Theme]" && /^[[:space:]]*Current[[:space:]]*=/{print; exit}' "$f")"
  [[ -n "$line" && "${line#*=}" != "vitrum" ]] || return 0
  warn "/etc/sddm.conf sets $line under [Theme], which overrides the vitrum theme — remove that line (or set Current=vitrum)"
}

# The current wallpaper if it is an image file, else nothing.
_boot_wallpaper() {
  local s="$XDG_CONFIG_HOME/vitrum/settings.json" p=""
  [[ -f "$s" ]] && have python3 && p="$(python3 -c 'import json,sys,os
try:
    w = json.load(open(sys.argv[1])).get("wallpaper", {})
    p = w.get("path") or next(iter((w.get("perOutput") or {}).values()), "")
    print(os.path.expanduser(p))
except Exception: pass' "$s")"
  case "${p,,}" in *.jpg|*.jpeg|*.png|*.webp) [[ -f "$p" ]] && printf '%s' "$p" ;; esac
}

# theme.conf from the dark scheme of the palette vitrum-theme wrote.
_boot_sddm_conf() {
  local bg="$1" font="Inter"
  local pal="$XDG_DATA_HOME/vitrum/palette.json"
  printf '[General]\n# Written by the vitrum installer from your palette and wallpaper.\nbackground=%s\ndim=0.32\n' "$bg"
  if [[ -f "$pal" ]] && have python3; then
    python3 - "$pal" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))["palette"]["dark"]
except Exception:
    d = {}
for key in ("bg", "surface", "text", "textDim", "accent", "onAccent", "danger"):
    if isinstance(d.get(key), str) and d[key].startswith("#"):
        print(f"{key}={d[key]}")
PY
  fi
  if [[ -f "$XDG_CONFIG_HOME/vitrum/settings.json" ]] && have python3; then
    font="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("fonts", {}).get("sans") or "Inter")
except Exception: print("Inter")' "$XDG_CONFIG_HOME/vitrum/settings.json")"
  fi
  printf 'font=%s\n' "$font"
}

# -------------------------------------------------------------- Plymouth ----

# Which tool builds this system's initramfs: only that one is ever run.
_boot_initramfs_tool() {
  local conf="${VITRUM_SYSROOT:-}/etc/kernel/install.conf" g=""
  [[ -f "$conf" ]] && g="$(sed -n 's/^[[:space:]]*initrd_generator[[:space:]]*=[[:space:]]*//p' "$conf" | tail -n 1)"
  if [[ -n "$g" ]]; then printf '%s' "$g"; return; fi
  if [[ -f "${VITRUM_SYSROOT:-}/etc/mkinitcpio.conf" ]] && have mkinitcpio; then echo mkinitcpio; return; fi
  # A dracut-built image is readable by lsinitrd; genkernel's and ugrd's are not.
  # A /boot that is a vfat mounted umask=0077 is root's alone, so read it as root.
  local img ls=(lsinitrd)
  img="${VITRUM_SYSROOT:-}/boot/initramfs-$(uname -r).img"
  [[ -r "$img" ]] || ls=(sudo -n lsinitrd)
  if have lsinitrd && "${ls[@]}" "$img" >/dev/null 2>&1; then echo dracut; return; fi
}

_boot_plymouth() {
  [[ "${WANT_PLYMOUTH:-0}" == "1" ]] || { info "boot splash: not wanted (--with-plymouth to add it)"; return 0; }
  have plymouth-set-default-theme || { info "Plymouth not installed — no boot splash"; return 0; }
  step "Plymouth theme"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would install $PLY_THEME and select it"; return 0; fi

  local b="$BUILD_DIR/plymouth"
  mkdir -p "$b"
  _boot_mark "$b/logo.png" 256 || warn "no rsvg-convert or ImageMagick — the splash shows only the spinner"
  if have magick; then
    magick -size 12x12 xc:none -fill white -draw 'circle 6,6 6,1' "$b/dot.png"
    magick -size 10x10 xc:none -fill white -draw 'circle 5,5 5,1' "$b/bullet.png"
    magick -size 440x52 xc:none -fill '#ffffff1f' -stroke '#ffffff38' -draw 'roundrectangle 1,1 438,50 25,25' "$b/capsule.png"
  fi
  run sudo rm -rf "${VITRUM_SYSROOT:-}/usr/share/plymouth/themes/niri-tahoe"
  run sudo install -d -m 755 "$PLY_THEME"
  run sudo install -m 644 "$VITRUM_DIR/assets/plymouth/vitrum/vitrum.plymouth" "$VITRUM_DIR/assets/plymouth/vitrum/vitrum.script" "$PLY_THEME/"
  local f
  for f in logo dot bullet capsule; do [[ -f "$b/$f.png" ]] && run sudo install -m 644 "$b/$f.png" "$PLY_THEME/"; done

  # Remembered once, so uninstall can go back to it.
  if [[ ! -f "$VITRUM_STATE/previous-plymouth" ]]; then
    mkdir -p "$VITRUM_STATE"
    plymouth-set-default-theme 2>/dev/null > "$VITRUM_STATE/previous-plymouth" || true
  fi

  run sudo plymouth-set-default-theme vitrum
  case "$(_boot_initramfs_tool)" in
    dracut)
      step "regenerating the initramfs (dracut)"
      # The running kernel by name: without --kver dracut takes the newest entry
      # of /lib/modules, and a stray /lib/modules/build symlink sorts last.
      run_ok sudo dracut --force --kver "$(uname -r)" || warn "dracut failed — the splash appears after your next successful initramfs rebuild" ;;
    mkinitcpio)
      if grep -qsE '^HOOKS=.*\bplymouth\b' "${VITRUM_SYSROOT:-}/etc/mkinitcpio.conf" "${VITRUM_SYSROOT:-}"/etc/mkinitcpio.conf.d/*.conf; then
        step "regenerating the initramfs (mkinitcpio)"
        run_ok sudo mkinitcpio -P || warn "mkinitcpio failed — the splash appears after your next successful rebuild"
      else
        warn "add 'plymouth' after 'udev' (or 'systemd') to HOOKS in /etc/mkinitcpio.conf, then: sudo mkinitcpio -P"
      fi ;;
    *)
      warn "the initramfs is not built by dracut or mkinitcpio here — rebuild it with Plymouth in it the way you usually do" ;;
  esac
  _boot_limine_splash || info "the splash needs 'quiet splash' on the kernel command line (GRUB_CMDLINE_LINUX_DEFAULT, or your boot entries)"
  ok "Plymouth uses the vitrum theme"
}

# Limine keeps the kernel command line in its own config: 'quiet splash' goes on
# every entry that lacks it, except the ones with nomodeset — those are the
# way back in when graphics fail, and stay as plain as they are. The file is
# root's (a vfat /boot), so it is read and written through sudo. → 1 when there
# is no Limine config here.
_boot_limine_splash() {
  local f="" c
  for c in /boot/limine.conf /boot/limine/limine.conf /boot/EFI/limine/limine.conf /efi/limine.conf; do
    if sudo test -f "${VITRUM_SYSROOT:-}$c" 2>/dev/null; then f="${VITRUM_SYSROOT:-}$c"; break; fi
  done
  [[ -n "$f" ]] || return 1
  local old new
  old="$(sudo cat "$f")" || return 1
  new="$(awk '/^[[:space:]]*cmdline:/ && !/(^|[[:space:]])splash([[:space:]]|$)/ && !/nomodeset/ { $0 = $0 " quiet splash" } { print }' <<<"$old")"
  if [[ "$new" == "$old" ]]; then ok "kernel command line: quiet splash already there ($f)"; return 0; fi
  sudo test -e "$f.vitrum-bak" || run sudo cp -p "$f" "$f.vitrum-bak"
  printf '%s\n' "$new" | sudo_write "$f"
  ok "kernel command line: quiet splash added to $f (the old one is $f.vitrum-bak)"
}
