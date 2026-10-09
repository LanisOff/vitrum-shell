# shellcheck shell=bash disable=SC1090,SC1091
# Backend detection and the four backends. Real system dirs are never read:
# VITRUM_ROOTFS points detection at a fake root, PATH is reduced to stubs + coreutils.
_clean_path() { PATH="$STUBS:/usr/bin:/bin"; }
_load() { source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/detect.sh"; }

test_detects_portage_openrc() {
  _clean_path; stub emerge; mkdir -p "$HOME/rootfs/run/openrc"; export VITRUM_ROOTFS="$HOME/rootfs"; _load
  assert_eq "$(detect_pkg_backend)" portage
  assert_eq "$(detect_init_backend)" openrc
}
test_detects_portage_systemd() {
  _clean_path; stub emerge; mkdir -p "$HOME/rootfs/run/systemd/system"; export VITRUM_ROOTFS="$HOME/rootfs"; _load
  assert_eq "$(detect_init_backend)" systemd
}
test_detects_pacman_systemd() {
  _clean_path; stub pacman; mkdir -p "$HOME/rootfs/run/systemd/system"; export VITRUM_ROOTFS="$HOME/rootfs"; _load
  assert_eq "$(detect_pkg_backend)" pacman
  assert_eq "$(detect_init_backend)" systemd
}
test_rejects_pacman_openrc() {
  _clean_path; stub pacman; mkdir -p "$HOME/rootfs/run/openrc"; export VITRUM_ROOTFS="$HOME/rootfs"; _load
  out="$( (load_backends) 2>&1 )" && { echo "load_backends should fail"; return 1; }
  assert_contains "$out" "unsupported system"
}
test_rejects_unknown_distro() {
  _clean_path; mkdir -p "$HOME/rootfs/run/systemd/system"; export VITRUM_ROOTFS="$HOME/rootfs"; _load
  ! (load_backends) 2>/dev/null
}
test_load_backends_sources_functions() {
  _clean_path; stub emerge; mkdir -p "$HOME/rootfs/run/openrc"; export VITRUM_ROOTFS="$HOME/rootfs"; _load
  load_backends
  assert_eq "$PKG_BACKEND+$INIT_BACKEND" "portage+openrc"
  declare -F pkg_install >/dev/null && declare -F svc_enable_system >/dev/null
}
test_openrc_session_line_uses_dbus_run_session() {
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-openrc.sh"
  assert_contains "$(session_exec_line)" "dbus-run-session"
}
test_systemd_session_line_starts_the_user_unit() {
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-systemd.sh"
  l="$(session_exec_line)"
  assert_contains "$l" "systemctl --user import-environment"
  assert_contains "$l" "systemctl --user --wait start niri.service"
}
test_systemd_session_unit_written() {
  stub sudo '"$@"'; export VITRUM_SYSROOT="$HOME/sys"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-systemd.sh"
  session_unit_install
  u="$(cat "$VITRUM_SYSROOT/etc/systemd/user/niri.service")"
  assert_contains "$u" "ExecStart=/usr/local/bin/niri --session"
  assert_contains "$u" "BindsTo=graphical-session.target"
}
test_openrc_session_unit_is_noop() {
  export VITRUM_SYSROOT="$HOME/sys"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-openrc.sh"
  session_unit_install
  [[ ! -e "$VITRUM_SYSROOT/etc/systemd" ]]
}
test_systemd_enables_user_audio_when_off() {
  stub systemctl 'echo "systemctl $*" >> "$HOME/calls"; [[ "$*" == *is-enabled* ]] && exit 1; exit 0'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-systemd.sh"
  audio_enable_user
  assert_contains "$(cat "$HOME/calls")" "systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service"
}
test_portage_install_calls_emerge_noreplace() {
  stub emerge 'echo "emerge $*" >> "$HOME/calls"'
  stub sudo '"$@"'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  pkg_install app-misc/jq
  assert_contains "$(cat "$HOME/calls")" "--noreplace"
  assert_contains "$(cat "$HOME/calls")" "--keep-going"     # one failed download must not stop the rest
  assert_contains "$(cat "$HOME/calls")" "app-misc/jq"
}
test_pacman_install_uses_needed_and_splits_aur() {
  stub pacman 'echo "pacman $*" >> "$HOME/calls"'
  stub paru 'echo "paru $*" >> "$HOME/calls"'
  stub sudo '"$@"'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-pacman.sh"
  pkg_install jq aur:matugen-bin
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" "pacman -Syu --needed --noconfirm jq"
  assert_contains "$calls" "paru -Syu --needed --noconfirm matugen-bin"
}
test_pacman_aur_without_helper_bootstraps_paru() {
  _clean_path; stub pacman; stub sudo '"$@"'; stub git 'echo "git $*" >> "$HOME/calls"'
  export DRY_RUN=1
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-pacman.sh"
  out="$(pkg_install aur:matugen-bin 2>&1)"
  assert_contains "$out" "paru-bin.git"
  assert_contains "$out" "would run: paru -Syu --needed --noconfirm matugen-bin"
}
test_openrc_enable_missing_service_warns_not_dies() {
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-openrc.sh"
  VITRUM_ROOTFS="$HOME/none" svc_enable_system definitely-not-a-service 2>/dev/null
}
test_portage_never_passes_ROOT_to_emerge() {
  # emerge reads ROOT as the target filesystem root; a leaked ROOT installs into the wrong tree.
  stub emerge 'echo "ROOT=[${ROOT:-}]" >> "$HOME/calls"'
  stub sudo '"$@"'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  export ROOT=/somewhere/else
  pkg_install app-misc/jq
  assert_eq "$(cat "$HOME/calls")" "ROOT=[]"
}
test_portage_alternatives_any_installed_counts() {
  mkdir -p "$HOME/rootfs/var/db/pkg/dev-lang/rust-1.97.1"; export VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  pkg_installed "dev-lang/rust-bin|dev-lang/rust"
}
test_portage_alternatives_install_first() {
  stub emerge 'echo "$*" >> "$HOME/calls"'; stub sudo '"$@"'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  pkg_install "dev-lang/rust-bin|dev-lang/rust" app-misc/jq
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" "dev-lang/rust-bin app-misc/jq"
  ! grep -q "|" <<<"$calls"
}
test_portage_enables_and_syncs_missing_overlays() {
  stub portageq 'echo "gentoo guru"'
  stub eselect 'echo "eselect $*" >> "$HOME/calls"'
  stub emaint 'echo "emaint $*" >> "$HOME/calls"'
  stub emerge 'echo "emerge $*" >> "$HOME/calls"'
  stub git; stub sudo '"$@"'
  mkdir -p "$HOME/rootfs/var/db/pkg/app-eselect/eselect-repository-15"; export VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  pkg_enable_overlays >/dev/null
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" "eselect repository enable gentoo-zh hyproverlay"
  assert_contains "$calls" "emaint sync -r gentoo-zh"
  assert_contains "$calls" "emaint sync -r hyproverlay"           # emaint keeps only the last -r
  ! grep -q "emerge" <<<"$calls"                                  # eselect-repository and git are already there
}
test_portage_overlays_already_enabled_does_nothing() {
  stub portageq 'case "$1" in get_repos) echo "gentoo guru gentoo-zh hyproverlay cachyos";; *) echo "/repos/$3";; esac'
  export VITRUM_ROOTFS="$HOME/rootfs"
  for r in guru gentoo-zh hyproverlay; do mkdir -p "$HOME/rootfs/repos/$r/profiles"; done
  stub eselect 'echo "eselect $*" >> "$HOME/calls"'; stub emaint 'echo "emaint $*" >> "$HOME/calls"'; stub sudo '"$@"'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  pkg_enable_overlays
  [[ ! -e "$HOME/calls" ]]
}
test_portage_enabled_but_never_synced_overlay_is_synced() {
  # a sync that failed leaves the repos.conf entry and no directory
  stub portageq 'case "$1" in get_repos) echo "gentoo guru gentoo-zh hyproverlay";; *) echo "/repos/$3";; esac'
  stub eselect 'echo "eselect $*" >> "$HOME/calls"'; stub emaint 'echo "emaint $*" >> "$HOME/calls"'
  stub git; stub sudo '"$@"'
  export VITRUM_ROOTFS="$HOME/rootfs"; mkdir -p "$HOME/rootfs/repos/hyproverlay/profiles"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  pkg_enable_overlays >/dev/null
  calls="$(cat "$HOME/calls")"
  ! grep -q "eselect" <<<"$calls"
  assert_contains "$calls" "emaint sync -r guru"
  assert_contains "$calls" "emaint sync -r gentoo-zh"
  ! grep -q "hyproverlay" <<<"$calls"
}
test_portage_overlays_installs_eselect_repository_first() {
  stub portageq 'echo "gentoo"'
  stub eselect 'echo "eselect $*" >> "$HOME/calls"'; stub emaint; stub git
  stub emerge 'echo "emerge $*" >> "$HOME/calls"'; stub sudo '"$@"'
  export VITRUM_ROOTFS="$HOME/empty"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  pkg_enable_overlays >/dev/null
  assert_contains "$(head -1 "$HOME/calls")" "app-eselect/eselect-repository"
  assert_contains "$(tail -1 "$HOME/calls")" "eselect repository enable guru gentoo-zh hyproverlay"
}
test_command_marker_counts_as_installed() {
  stub clang; export VITRUM_ROOTFS="$HOME/empty"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  pkg_installed "llvm-core/clang@clang"
}
test_command_marker_stripped_on_install() {
  stub emerge 'echo "$*" >> "$HOME/calls"'; stub sudo '"$@"'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  pkg_install "llvm-core/clang@clang"
  assert_contains "$(cat "$HOME/calls")" " llvm-core/clang"
  ! grep -q "@" "$HOME/calls"
}
test_pacman_command_marker() {
  stub pacman 'exit 1'; stub cargo
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-pacman.sh"
  pkg_installed "rust@cargo"
}
test_openrc_display_manager_sets_conf_and_runlevel() {
  stub sudo '"$@"'; stub rc-update 'echo "rc-update $*" >> "$HOME/calls"'
  export VITRUM_ROOTFS="$HOME/rootfs"; mkdir -p "$VITRUM_ROOTFS/etc/conf.d"
  printf 'CHECKVT=7\nDISPLAYMANAGER="xdm"\n' > "$VITRUM_ROOTFS/etc/conf.d/display-manager"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-openrc.sh"
  svc_enable_display_manager sddm
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/conf.d/display-manager")" 'DISPLAYMANAGER="sddm"'
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/conf.d/display-manager")" 'CHECKVT=7'
  assert_contains "$(cat "$HOME/calls")" "rc-update add display-manager default"
}
test_systemd_display_manager_enables_unit() {
  stub sudo '"$@"'; stub systemctl 'echo "systemctl $*" >> "$HOME/calls"'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-systemd.sh"
  svc_enable_display_manager sddm
  assert_contains "$(cat "$HOME/calls")" "systemctl enable sddm.service"
}
test_portage_available_ignores_keywords() {
  stub portageq 'echo "$ACCEPT_KEYWORDS" > "$HOME/kw"; echo cat/pkg-1'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  pkg_available "gui-apps/satty"
  assert_eq "$(cat "$HOME/kw")" "**"
}
_portage_world() {
  stub sudo '"$@"'; export VITRUM_ROOTFS="$HOME/rootfs"
  export PKG_BACKEND=portage
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
}
test_portage_files_in_directory_layout() {
  _portage_world
  mkdir -p "$VITRUM_ROOTFS/etc/portage/package.use" "$VITRUM_ROOTFS/etc/portage/package.accept_keywords" "$VITRUM_ROOTFS/etc/portage/package.env"
  echo "user stuff" > "$VITRUM_ROOTFS/etc/portage/package.use/zz-autounmask"
  echo "old" > "$VITRUM_ROOTFS/etc/portage/package.use/vitrum"     # written by an early vitrum
  pkg_write_portage_files; pkg_write_portage_files
  [[ ! -e "$VITRUM_ROOTFS/etc/portage/package.use/vitrum" ]]
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/portage/package.accept_keywords/50-vitrum")" "gui-apps/quickshell ~amd64"
  [[ -f "$VITRUM_ROOTFS/etc/portage/package.use/zz-vitrum-autounmask" ]]
  echo "dep changes" > "$VITRUM_ROOTFS/etc/portage/package.use/zz-vitrum-autounmask"
  pkg_write_portage_files
  assert_eq "$(cat "$VITRUM_ROOTFS/etc/portage/package.use/zz-vitrum-autounmask")" "dep changes"
  assert_eq "$(cat "$VITRUM_ROOTFS/etc/portage/package.use/zz-autounmask")" "user stuff"
}
test_portage_files_in_single_file_layout() {
  _portage_world
  mkdir -p "$VITRUM_ROOTFS/etc/portage"
  printf 'app-misc/foo bar\n' > "$VITRUM_ROOTFS/etc/portage/package.accept_keywords"
  pkg_write_portage_files; pkg_write_portage_files
  f="$(cat "$VITRUM_ROOTFS/etc/portage/package.accept_keywords")"
  assert_contains "$f" "app-misc/foo bar"
  assert_eq "$(grep -c '^# vitrum begin' <<<"$f")" 1
  assert_eq "$(grep -c 'gui-apps/quickshell ~amd64' <<<"$f")" 1
}

test_pacman_never_syncs_without_upgrading() {
  stub pacman 'echo "pacman $*" >> "$HOME/calls"'; stub sudo '"$@"'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-pacman.sh"
  pkg_prepare; pkg_install jq
  ! grep -qE "pacman -Sy( |$)" "$HOME/calls"
}
# Nothing starts the system bus or the seat on OpenRC: without them SDDM and niri do not come up.
test_openrc_packages_stage_enables_elogind_at_boot_and_dbus() {
  export PKG_BACKEND=portage INIT_BACKEND=openrc VITRUM_ROOTFS="$HOME/rootfs"
  mkdir -p "$VITRUM_ROOTFS/etc/init.d"
  for s in elogind dbus bluetooth; do printf '#!/bin/sh\n' > "$VITRUM_ROOTFS/etc/init.d/$s"; chmod +x "$VITRUM_ROOTFS/etc/init.d/$s"; done
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"
  source "$VITRUM_DIR/lib/backend/pkg-portage.sh"; source "$VITRUM_DIR/lib/backend/init-openrc.sh"
  source "$VITRUM_DIR/lib/stages/10-packages.sh"
  stub sudo '"$@"'; stub lspci; stub portageq 'echo x-1'
  stub rc-update 'echo "rc-update $*" >> "$HOME/calls"'; stub rc-service
  pkg_prepare() { :; }; pkg_apply_use() { :; }; pkg_install() { :; }
  stage_packages >/dev/null 2>&1
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" "rc-update add elogind boot"
  assert_contains "$calls" "rc-update add dbus default"
  assert_contains "$calls" "rc-update add bluetooth default"
}
# Devices udev saw before libinput's and elogind's rules existed are passed over
# by libinput: the greeter got the mouse and not the keyboard.
test_packages_stage_replays_input_devices_to_udev() {
  export PKG_BACKEND=portage INIT_BACKEND=openrc VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"
  source "$VITRUM_DIR/lib/backend/pkg-portage.sh"; source "$VITRUM_DIR/lib/backend/init-openrc.sh"
  source "$VITRUM_DIR/lib/stages/10-packages.sh"
  stub sudo '"$@"'; stub lspci; stub portageq 'echo x-1'; stub rc-update; stub rc-service
  stub udevadm 'echo "udevadm $*" >> "$HOME/calls"'
  pkg_prepare() { :; }; pkg_apply_use() { :; }; pkg_install() { :; }
  stage_packages >/dev/null 2>&1
  assert_contains "$(cat "$HOME/calls")" "udevadm trigger --action=change --subsystem-match=input"
}
# The network panel needs NetworkManager; dhcpcd would fight it. The switch
# waits for the next boot: nothing is stopped or started under the install.
test_openrc_network_moves_to_networkmanager_next_boot() {
  export PKG_BACKEND=portage INIT_BACKEND=openrc VITRUM_ROOTFS="$HOME/rootfs"
  mkdir -p "$VITRUM_ROOTFS/etc/init.d"; printf '#!/bin/sh\n' > "$VITRUM_ROOTFS/etc/init.d/NetworkManager"; chmod +x "$VITRUM_ROOTFS/etc/init.d/NetworkManager"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"
  source "$VITRUM_DIR/lib/backend/pkg-portage.sh"; source "$VITRUM_DIR/lib/backend/init-openrc.sh"
  source "$VITRUM_DIR/lib/stages/10-packages.sh"
  stub sudo '"$@"'; stub rc-service 'echo "rc-service $*" >> "$HOME/calls"'
  stub rc-update 'echo "rc-update $*" >> "$HOME/calls"; [[ "$1" == show ]] && echo "  dhcpcd | default"; exit 0'
  svc_use_networkmanager >/dev/null 2>&1
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" "rc-update add NetworkManager default"
  assert_contains "$calls" "rc-update del dhcpcd default"
  ! grep -q "rc-service" <<<"$calls"
}
# The plain profile gets the base USE once, for every package, first in the file.
test_portage_base_use_only_on_a_non_desktop_profile() {
  _portage_world
  mkdir -p "$VITRUM_ROOTFS/etc/portage/package.use" "$VITRUM_ROOTFS/etc/portage/package.accept_keywords" "$VITRUM_ROOTFS/etc/portage/package.env" "$HOME/prof/23.0/desktop"
  ln -sfn "$HOME/prof/23.0" "$VITRUM_ROOTFS/etc/portage/make.profile"
  pkg_write_portage_files
  assert_eq "$(head -1 "$VITRUM_ROOTFS/etc/portage/package.use/50-vitrum")" "*/* X wayland opengl vulkan alsa dbus udev"
  ln -sfn "$HOME/prof/23.0/desktop" "$VITRUM_ROOTFS/etc/portage/make.profile"
  pkg_write_portage_files
  ! grep -q '^\*/\*' "$VITRUM_ROOTFS/etc/portage/package.use/50-vitrum"
}
test_base_use_is_not_a_rebuild_of_everything() {
  _portage_world
  mkdir -p "$VITRUM_ROOTFS/var/db/pkg/app-misc/foo-1"; echo "X" > "$VITRUM_ROOTFS/var/db/pkg/app-misc/foo-1/IUSE"; : > "$VITRUM_ROOTFS/var/db/pkg/app-misc/foo-1/USE"
  packages_portage_column() { printf '%s\n' "*/* X wayland"; }
  _emerge() { echo "emerge $*" >> "$HOME/calls"; }
  pkg_apply_use >/dev/null 2>&1
  [[ ! -e "$HOME/calls" ]]
}
