# shellcheck shell=bash disable=SC1090,SC1091
_load() {
  export PKG_BACKEND=portage INIT_BACKEND=openrc
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"
  source "$VITRUM_DIR/lib/backend/pkg-portage.sh"; source "$VITRUM_DIR/lib/stages/90-doctor.sh"
}
test_doctor_reports_missing_compositor_and_fails() {
  _load; export VITRUM_NIRI_BIN="$HOME/nope"
  out="$(stage_doctor 2>&1)" && { echo "doctor should fail"; return 1; }
  assert_contains "$out" "niri"
}
test_doctor_passes_on_complete_install() {
  _load
  export VITRUM_ROOTFS="$HOME/rootfs" VITRUM_SYSROOT="$HOME/sys"
  # every table package "installed"
  while IFS= read -r a; do a="${a%@*}"; a="${a%%|*}"; mkdir -p "$VITRUM_ROOTFS/var/db/pkg/$a-1.0"; done < <(packages_for required 2>/dev/null)
  mkdir -p "$HOME/bin"; printf '#!/bin/sh\necho "niri 26.04"\n' > "$HOME/bin/niri"; chmod +x "$HOME/bin/niri"
  export VITRUM_NIRI_BIN="$HOME/bin/niri"
  source "$VITRUM_DIR/lib/stages/30-niri.sh"
  mkdir -p "$VITRUM_STATE"; niri_stamp > "$VITRUM_STATE/niri.rev"
  mkdir -p "$VITRUM_SYSROOT/usr/local/bin" "$VITRUM_SYSROOT/usr/local/share/wayland-sessions" "$XDG_CONFIG_HOME/vitrum/niri" "$XDG_CONFIG_HOME/quickshell/vitrum" "$HOME/.local/share/icons/Bibata-Modern-Classic" "$HOME/.local/bin"
  touch "$VITRUM_SYSROOT/usr/local/bin/vitrum-session" "$VITRUM_SYSROOT/usr/local/share/wayland-sessions/niri.desktop" "$XDG_CONFIG_HOME/vitrum/niri/config.kdl" "$XDG_CONFIG_HOME/quickshell/vitrum/shell.qml" "$HOME/.local/bin/vitrum-startup" "$HOME/.local/bin/vitrum-shell"
  stub qs; stub fc-list 'echo "Inter: x"; echo "JetBrains Mono: x"; echo "Material Symbols Rounded: x"'
  stage_doctor >/dev/null 2>&1 || { stage_doctor 2>&1 | grep -E "✗|fail" ; return 1; }
}
# A hand-built kernel can lack any of these; each is named with what it costs.
test_doctor_names_missing_kernel_options() {
  _load; source "$VITRUM_DIR/lib/kernel.sh"
  export VITRUM_ROOTFS="$HOME/rootfs"; stub uname 'echo 7.2.9'
  mkdir -p "$VITRUM_ROOTFS/boot"
  printf 'CONFIG_DRM_SIMPLEDRM=y\nCONFIG_FRAMEBUFFER_CONSOLE=y\nCONFIG_SND_HDA_CODEC_REALTEK=m\nCONFIG_TUN=m\n# CONFIG_NF_TABLES is not set\n' > "$VITRUM_ROOTFS/boot/config-7.2.9"
  out="$(_doctor_kernel 2>&1)"
  assert_contains "$out" "CONFIG_NF_TABLES is off"
  assert_contains "$out" "VPN auto-routing"
  ! grep -q "CONFIG_TUN is off" <<<"$out"
  ! grep -q "CONFIG_DRM_SIMPLEDRM is off" <<<"$out"   # one of the alternatives is enough
}
test_doctor_kernel_without_config_only_warns() {
  _load; export VITRUM_ROOTFS="$HOME/empty"; stub uname 'echo 7.2.9'
  out="$(_doctor_kernel 2>&1)"
  assert_contains "$out" "not checked"
}
