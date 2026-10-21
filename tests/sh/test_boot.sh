# shellcheck shell=bash disable=SC1090,SC1091
_load_boot() {
  export PKG_BACKEND="${1:-portage}" VITRUM_SYSROOT="$HOME/sys" BUILD_DIR="$HOME/build"
  mkdir -p "$BUILD_DIR"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/dm.sh"; source "$VITRUM_DIR/lib/stages/70-boot.sh"
  dm_use_sddm() { echo "dm_use_sddm" >> "$HOME/calls"; }
  stub sudo '"$@"'
  sudo_refresh() { :; }
  # Image tools: write a file where they are asked to.
  stub rsvg-convert 'for a; do o="$a"; done; : > "$o"'
  stub magick 'for a; do o="$a"; done; : > "$o"'
  mkdir -p "$XDG_DATA_HOME/vitrum" "$XDG_CONFIG_HOME/vitrum"
  printf '{"source":"preset","palette":{"dark":{"bg":"#101112","surface":"#202122","text":"#eeeeee","textDim":"#aaaaaa","accent":"#123456","onAccent":"#ffffff","danger":"#ff0000"}}}' \
    > "$XDG_DATA_HOME/vitrum/palette.json"
}
_theme() { echo "$VITRUM_SYSROOT/usr/share/sddm/themes/vitrum"; }

test_sddm_theme_installed_selected_and_coloured() {
  _load_boot; stub sddm; WANT_SDDM=1; WANT_PLYMOUTH=0
  stage_boot >/dev/null
  [[ -f "$(_theme)/Main.qml" && -f "$(_theme)/metadata.desktop" ]]
  # The shell's glass, as it is, and its compiled shader.
  [[ -f "$(_theme)/Glass.qml" && -f "$(_theme)/glass.frag.qsb" ]]
  # The greeter reads the user's login folder (login.json) with XMLHttpRequest.
  assert_contains "$(cat "$VITRUM_SYSROOT/etc/sddm.conf.d/zz-vitrum.conf")" "QML_XHR_ALLOW_FILE_READ=1"
  c="$(cat "$(_theme)/theme.conf")"
  assert_contains "$c" "accent=#123456"
  assert_contains "$c" "bg=#101112"
  assert_contains "$c" "background="
  assert_contains "$(cat "$VITRUM_SYSROOT/etc/sddm.conf.d/zz-vitrum.conf")" "Current=vitrum"
  assert_contains "$(cat "$HOME/calls")" "dm_use_sddm"
}
test_sddm_background_is_the_wallpaper() {
  _load_boot; stub sddm; WANT_SDDM=1; WANT_PLYMOUTH=0
  printf 'x' > "$HOME/wall.jpg"
  printf '{"wallpaper":{"path":"%s"}}' "$HOME/wall.jpg" > "$XDG_CONFIG_HOME/vitrum/settings.json"
  stage_boot >/dev/null
  [[ -f "$(_theme)/background.jpg" ]]
  assert_contains "$(cat "$(_theme)/theme.conf")" "background=background.jpg"
}
test_sddm_skipped_when_absent_or_declined() {
  _load_boot; WANT_SDDM=1; WANT_PLYMOUTH=0
  stage_boot >/dev/null
  [[ ! -e "$(_theme)" ]]
  _load_boot; stub sddm; WANT_SDDM=0; WANT_PLYMOUTH=0
  stage_boot >/dev/null
  [[ ! -e "$(_theme)" && ! -e "$VITRUM_SYSROOT/etc/sddm.conf.d/zz-vitrum.conf" ]]
}
test_sddm_niri_tahoe_theme_removed() {
  _load_boot; stub sddm; WANT_SDDM=1; WANT_PLYMOUTH=0
  mkdir -p "$VITRUM_SYSROOT/usr/share/sddm/themes/niri-tahoe"
  stage_boot >/dev/null
  [[ ! -e "$VITRUM_SYSROOT/usr/share/sddm/themes/niri-tahoe" ]]
}
test_plymouth_skipped_without_plymouth() {
  _load_boot; WANT_SDDM=0; WANT_PLYMOUTH=1
  stage_boot >/dev/null
  [[ ! -e "$VITRUM_SYSROOT/usr/share/plymouth/themes/vitrum" ]]
}
test_plymouth_theme_set_but_initramfs_only_with_the_flag() {
  _load_boot; WANT_SDDM=0; WANT_PLYMOUTH=0
  stub plymouth-set-default-theme 'echo "set $*" >> "$HOME/calls"; [ "$1" = "" ] && echo spinner; exit 0'
  stub dracut 'echo "dracut $*" >> "$HOME/calls"'
  stage_boot >/dev/null
  [[ ! -e "$VITRUM_SYSROOT/usr/share/plymouth/themes/vitrum" ]]   # not wanted: nothing at all
  _load_boot; WANT_SDDM=0; WANT_PLYMOUTH=1
  stub plymouth-set-default-theme 'echo "set $*" >> "$HOME/calls"; [ -z "$1" ] && echo spinner; exit 0'
  stub dracut 'echo "dracut $*" >> "$HOME/calls"'; stub uname 'echo 7.2.9'
  _boot_initramfs_tool() { echo dracut; }
  stage_boot >/dev/null
  t="$VITRUM_SYSROOT/usr/share/plymouth/themes/vitrum"
  [[ -f "$t/vitrum.script" && -f "$t/vitrum.plymouth" && -f "$t/logo.png" && -f "$t/light5.png" && -f "$t/track.png" && -f "$t/fill.png" && ! -e "$t/light6.png" ]]
  assert_contains "$(cat "$HOME/calls")" "set vitrum"
  assert_contains "$(cat "$HOME/calls")" "dracut --force --kver 7.2.9"     # not the newest /lib/modules entry
  assert_eq "$(cat "$VITRUM_STATE/previous-plymouth")" "spinner"
}
test_boot_stage_says_nothing_apple() {
  _load_boot; stub sddm; WANT_SDDM=1; WANT_PLYMOUTH=0
  out="$(stage_boot 2>&1)"
  ! grep -qi "apple\|mac\b\|SF Pro" <<<"$out"
  ! grep -rqi "apple" "$(_theme)"
}

test_sddm_warns_about_a_theme_set_in_sddm_conf() {
  _load_boot; stub sddm; WANT_SDDM=1; WANT_PLYMOUTH=0
  mkdir -p "$VITRUM_SYSROOT/etc"; printf '[Theme]\nCurrent=breeze\n' > "$VITRUM_SYSROOT/etc/sddm.conf"
  out="$(stage_boot 2>&1)"
  assert_contains "$out" "/etc/sddm.conf"
  assert_contains "$out" "Current=breeze"
}
test_sddm_niri_tahoe_dropins_removed() {
  _load_boot; stub sddm; WANT_SDDM=1; WANT_PLYMOUTH=0
  mkdir -p "$VITRUM_SYSROOT/etc/sddm.conf.d"
  printf '[Theme]\nCurrent=niri-tahoe\n' > "$VITRUM_SYSROOT/etc/sddm.conf.d/99-niri-tahoe.conf"
  stage_boot >/dev/null 2>&1
  [[ ! -e "$VITRUM_SYSROOT/etc/sddm.conf.d/99-niri-tahoe.conf" ]]
}
test_dracut_only_when_it_builds_the_initramfs() {
  _load_boot; WANT_SDDM=0; WANT_PLYMOUTH=1
  stub plymouth-set-default-theme 'exit 0'
  stub dracut 'echo "dracut $*" >> "$HOME/calls"'
  _boot_initramfs_tool() { echo genkernel; }
  out="$(stage_boot 2>&1)"
  ! grep -q "dracut" "$HOME/calls" 2>/dev/null
  assert_contains "$out" "initramfs"
}
test_a_failing_dracut_warns_and_the_install_goes_on() {
  _load_boot; WANT_SDDM=0; WANT_PLYMOUTH=1
  stub plymouth-set-default-theme 'exit 0'
  stub dracut 'exit 1'
  _boot_initramfs_tool() { echo dracut; }
  ( stage_boot >/dev/null 2>&1 ) || { echo "stage died"; return 1; }
}
# After a Wayland session on NVIDIA, SDDM's restart of X hung in driver init
# and the login never came back: with niri there the greeter runs on it
# (Wayland), with the user's keyboard layouts.
test_sddm_greeter_runs_on_niri() {
  _load_boot; stub sddm; WANT_SDDM=1; WANT_PLYMOUTH=0
  mkdir -p "$VITRUM_SYSROOT/usr/local/bin"; printf '#!/bin/sh\n' > "$VITRUM_SYSROOT/usr/local/bin/niri"; chmod +x "$VITRUM_SYSROOT/usr/local/bin/niri"
  mkdir -p "$XDG_CONFIG_HOME/vitrum/niri"
  printf 'input {\n    keyboard {\n        xkb {\n            layout "us,ru"\n            options "grp:alt_shift_toggle"\n        }\n    }\n}\n' > "$XDG_CONFIG_HOME/vitrum/niri/config.kdl"
  stage_boot >/dev/null
  c="$(cat "$VITRUM_SYSROOT/etc/sddm.conf.d/zz-vitrum.conf")"
  assert_contains "$c" "DisplayServer=wayland"
  assert_contains "$c" "CompositorCommand=/usr/local/bin/niri -c /etc/sddm/vitrum-greeter.kdl"
  g="$(cat "$VITRUM_SYSROOT/etc/sddm/vitrum-greeter.kdl")"
  assert_contains "$g" 'layout "us,ru"'
  assert_contains "$g" 'options "grp:alt_shift_toggle"'
  assert_contains "$g" "open-fullscreen true"
}
test_sddm_stays_on_x11_without_niri() {
  _load_boot; stub sddm; WANT_SDDM=1; WANT_PLYMOUTH=0
  stage_boot >/dev/null
  c="$(cat "$VITRUM_SYSROOT/etc/sddm.conf.d/zz-vitrum.conf")"
  assert_contains "$c" "Current=vitrum"
  ! grep -q "DisplayServer=wayland" <<<"$c"
}
# /boot on a vfat mounted umask=0077 is root's alone: the dracut image is read
# through sudo instead of being taken for "no known initramfs tool".
test_initramfs_tool_reads_root_only_boot_with_sudo() {
  _load_boot; stub uname 'echo 7.2.9'
  stub sudo 'echo "sudo $*" >> "$HOME/calls"; [[ "$1" == -n ]] && shift; "$@"'
  stub lsinitrd '[[ -r "$1" || -n "${SUDO_OK:-}" ]]'
  mkdir -p "$VITRUM_SYSROOT/boot"; : > "$VITRUM_SYSROOT/boot/initramfs-7.2.9.img"; chmod 000 "$VITRUM_SYSROOT/boot/initramfs-7.2.9.img"
  export SUDO_OK=1
  assert_eq "$(_boot_initramfs_tool)" dracut
  assert_contains "$(cat "$HOME/calls")" "sudo -n lsinitrd"
}
test_initramfs_tool_readable_image_needs_no_sudo() {
  _load_boot; stub uname 'echo 7.2.9'
  stub sudo 'echo "sudo $*" >> "$HOME/calls"; exit 1'
  stub lsinitrd 'exit 0'
  mkdir -p "$VITRUM_SYSROOT/boot"; : > "$VITRUM_SYSROOT/boot/initramfs-7.2.9.img"
  assert_eq "$(_boot_initramfs_tool)" dracut
  [[ ! -e "$HOME/calls" ]]
}
# Limine: quiet splash on the normal entries; the nomodeset rescue entry stays plain.
test_limine_gets_quiet_splash_but_not_the_rescue_entry() {
  _load_boot; stub uname 'echo 7.2.9'
  mkdir -p "$VITRUM_SYSROOT/boot"
  printf '%s\n' 'timeout: 5' '/Gentoo' '    cmdline: root=UUID=x rw nvidia-drm.modeset=1' '/Safe' '    cmdline: root=UUID=x rw nomodeset' > "$VITRUM_SYSROOT/boot/limine.conf"
  _boot_limine_splash >/dev/null 2>&1
  c="$(cat "$VITRUM_SYSROOT/boot/limine.conf")"
  assert_contains "$c" "cmdline: root=UUID=x rw nvidia-drm.modeset=1 quiet splash"
  assert_contains "$c" "cmdline: root=UUID=x rw nomodeset"
  ! grep -q "nomodeset quiet" <<<"$c"
  [[ -f "$VITRUM_SYSROOT/boot/limine.conf.vitrum-bak" ]]
  _boot_limine_splash >/dev/null 2>&1
  assert_eq "$(grep -c "quiet splash" "$VITRUM_SYSROOT/boot/limine.conf")" 1
}
test_no_limine_config_is_not_an_error() {
  _load_boot; ( _boot_limine_splash >/dev/null 2>&1 ) && { echo "should report no config"; return 1; }; true
}

# Void: the splash goes on GRUB's default command line, then grub.cfg is written again.
test_void_grub_gets_quiet_splash() {
  _load_boot xbps
  mkdir -p "$VITRUM_SYSROOT/etc/default" "$VITRUM_SYSROOT/boot/grub"; : > "$VITRUM_SYSROOT/boot/grub/grub.cfg"
  printf '%s\n' 'GRUB_DEFAULT=0' 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4"' 'GRUB_CMDLINE_LINUX=""' > "$VITRUM_SYSROOT/etc/default/grub"
  stub grub-mkconfig 'echo "grub-mkconfig $*" >> "$HOME/calls"'
  _boot_cmdline_splash >/dev/null 2>&1
  g="$(cat "$VITRUM_SYSROOT/etc/default/grub")"
  assert_contains "$g" 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 quiet splash"'
  assert_contains "$g" 'GRUB_CMDLINE_LINUX=""'
  assert_contains "$(cat "$HOME/calls")" "grub-mkconfig -o $VITRUM_SYSROOT/boot/grub/grub.cfg"
  [[ -f "$VITRUM_SYSROOT/etc/default/grub.vitrum-bak" ]]
  rm "$HOME/calls"
  _boot_cmdline_splash >/dev/null 2>&1
  assert_eq "$(grep -c splash "$VITRUM_SYSROOT/etc/default/grub")" 1
  [[ ! -e "$HOME/calls" ]]
}
test_void_grub_keeps_an_existing_quiet() {
  _load_boot xbps
  mkdir -p "$VITRUM_SYSROOT/etc/default"
  printf '%s\n' 'GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3"' > "$VITRUM_SYSROOT/etc/default/grub"
  _boot_cmdline_splash >/dev/null 2>&1
  assert_eq "$(cat "$VITRUM_SYSROOT/etc/default/grub")" 'GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 splash"'
}
# Fedora: grubby, for every entry; rhgb already asks for the splash.
test_fedora_grubby_adds_the_splash_only_when_missing() {
  _load_boot dnf
  stub grubby 'if [[ "$1" == --info=ALL ]]; then cat "$HOME/entries"; else echo "grubby $*" >> "$HOME/calls"; fi'
  printf 'index=0\nkernel="/boot/vmlinuz-a"\nargs="ro rootflags=subvol=root rhgb quiet"\nindex=1\nkernel="/boot/vmlinuz-b"\nargs="ro rhgb quiet"\n' > "$HOME/entries"
  _boot_cmdline_splash >/dev/null 2>&1
  [[ ! -e "$HOME/calls" ]]
  printf 'index=0\nkernel="/boot/vmlinuz-a"\nargs="ro rootflags=subvol=root"\n' > "$HOME/entries"
  _boot_cmdline_splash >/dev/null 2>&1
  assert_contains "$(cat "$HOME/calls")" 'grubby --update-kernel=/boot/vmlinuz-a --args=quiet splash'
}
test_arch_and_gentoo_have_no_cmdline_tool_here() {
  _load_boot pacman
  ! _boot_cmdline_splash
}

# grubby: the normal kernels get the splash, the rescue entry stays plain.
test_fedora_grubby_leaves_the_rescue_entry_alone() {
  _load_boot dnf
  stub grubby 'if [[ "$1" == --info=ALL ]]; then cat "$HOME/entries"; else echo "grubby $*" >> "$HOME/calls"; fi'
  printf '%s\n' 'index=0' 'kernel="/boot/vmlinuz-6.19.4-300.fc44.x86_64"' 'args="ro root=UUID=x"' 'title="Fedora Linux (6.19.4)"' \
    'index=1' 'kernel="/boot/vmlinuz-0-rescue-abc"' 'args="ro root=UUID=x"' 'title="Fedora Linux (0-rescue-abc)"' \
    'index=2' 'kernel="/boot/vmlinuz-6.18.9-300.fc44.x86_64"' 'args="ro rhgb quiet"' 'title="Fedora Linux (6.18.9)"' > "$HOME/entries"
  _boot_cmdline_splash >/dev/null 2>&1
  assert_eq "$(cat "$HOME/calls")" 'grubby --update-kernel=/boot/vmlinuz-6.19.4-300.fc44.x86_64 --args=quiet splash'
}
test_void_grub_single_quotes_and_bare_values() {
  _load_boot xbps
  mkdir -p "$VITRUM_SYSROOT/etc/default"
  printf '%s\n' "GRUB_CMDLINE_LINUX_DEFAULT='loglevel=4 nvidia-drm.modeset=1'" > "$VITRUM_SYSROOT/etc/default/grub"
  _boot_cmdline_splash >/dev/null 2>&1
  assert_eq "$(cat "$VITRUM_SYSROOT/etc/default/grub")" "GRUB_CMDLINE_LINUX_DEFAULT='loglevel=4 nvidia-drm.modeset=1 quiet splash'"
  printf '%s\n' 'GRUB_CMDLINE_LINUX_DEFAULT=loglevel=4' > "$VITRUM_SYSROOT/etc/default/grub"
  _boot_cmdline_splash >/dev/null 2>&1
  assert_eq "$(cat "$VITRUM_SYSROOT/etc/default/grub")" 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 quiet splash"'
  _boot_cmdline_splash >/dev/null 2>&1
  assert_eq "$(grep -c splash "$VITRUM_SYSROOT/etc/default/grub")" 1
}
