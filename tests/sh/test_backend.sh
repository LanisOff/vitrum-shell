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
  # /usr/bin stays on PATH for the coreutils, and on Arch or Gentoo it holds
  # the real pacman or emerge: neither is there for this test.
  have() { [[ "$1" != pacman && "$1" != emerge ]] && command -v "$1" >/dev/null 2>&1; }
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
# No helper and none in the repositories (plain Arch): paru from source, not
# paru-bin — a prebuilt one breaks whenever pacman's library moves.
test_pacman_aur_without_helper_builds_paru_from_source() {
  _clean_path; stub pacman 'case "$1" in -Si) exit 1;; esac'; stub sudo '"$@"'; stub git 'echo "git $*" >> "$HOME/calls"'
  export DRY_RUN=1
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-pacman.sh"
  out="$(pkg_install aur:matugen-bin 2>&1)"
  assert_contains "$out" "aur.archlinux.org/paru.git"
  ! grep -q "paru-bin" <<<"$out"
  assert_contains "$out" "would run: paru -Syu --needed --noconfirm matugen-bin"
}
# The distribution ships one (CachyOS: paru, EndeavourOS: yay): that, built for its pacman.
test_pacman_aur_helper_from_the_repositories() {
  _clean_path; stub sudo '"$@"'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-pacman.sh"
  stub pacman 'echo "pacman $*" >> "$HOME/calls"; case "$1 $2" in "-Si paru") exit 1;; "-Si yay") exit 0;; -Qq*) exit 1;; "-S --needed") printf "#!/usr/bin/env bash\necho \"yay \$*\" >> \"\$HOME/calls\"\n" > "$(dirname "$0")/yay"; chmod +x "$(dirname "$0")/yay";; esac'
  pkg_install aur:matugen-bin >/dev/null 2>&1
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" "pacman -S --needed --noconfirm yay"
  assert_contains "$calls" "yay -Syu --needed --noconfirm matugen-bin"
}
# paru-bin built for an older pacman is there but dies on start (libalpm.so.15):
# it is replaced by the repositories' paru, never used.
test_pacman_broken_paru_is_replaced() {
  _clean_path; stub sudo '"$@"'
  stub paru 'case "$1" in --version) echo "libalpm.so.15: cannot open" >&2; exit 127;; esac; echo "BROKEN paru $*" >> "$HOME/calls"'
  stub pacman 'echo "pacman $*" >> "$HOME/calls"; case "$1 $2" in "-Si paru") exit 0;; "-Qq paru-bin") exit 0;; -Qq*) exit 1;; "-S --needed") printf "#!/usr/bin/env bash\necho \"paru \$*\" >> \"\$HOME/calls\"\n" > "$(dirname "$0")/paru";; esac'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-pacman.sh"
  pkg_install aur:matugen-bin >/dev/null 2>&1
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" "pacman -Rdd --noconfirm paru-bin"
  assert_contains "$calls" "pacman -S --needed --noconfirm paru"
  assert_contains "$calls" "paru -Syu --needed --noconfirm matugen-bin"
  ! grep -q "BROKEN" <<<"$calls"
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

# ------------------------------------------------------- Fedora and Void -----

_os_release() {  # _os_release <ID> [ID_LIKE] — in the fake root
  mkdir -p "$HOME/rootfs/etc"; export VITRUM_ROOTFS="$HOME/rootfs"
  printf 'ID=%s\nVERSION_ID=44\n' "$1" > "$VITRUM_ROOTFS/etc/os-release"
  [[ -n "${2:-}" ]] && printf 'ID_LIKE="%s"\n' "$2" >> "$VITRUM_ROOTFS/etc/os-release"
  return 0
}
test_detects_dnf_systemd_on_fedora() {
  _clean_path; stub dnf; _os_release fedora; mkdir -p "$VITRUM_ROOTFS/run/systemd/system"; _load
  assert_eq "$(detect_pkg_backend)+$(detect_init_backend)" "dnf+systemd"
}
test_detects_dnf_on_a_fedora_derivative() {
  _clean_path; stub dnf; _os_release nobara "rhel fedora"; _load
  assert_eq "$(detect_pkg_backend)" dnf
}
# dnf is packaged elsewhere too (openSUSE, Mageia): it is not Fedora by itself.
test_dnf_without_fedora_is_not_dnf() {
  _clean_path; stub dnf; _os_release opensuse-tumbleweed "suse opensuse"; _load
  have() { [[ "$1" != pacman && "$1" != emerge && "$1" != xbps-install ]] && command -v "$1" >/dev/null 2>&1; }
  assert_eq "$(detect_pkg_backend)" none
}
# A container runs no systemd: Fedora has no other init, so it is systemd.
test_fedora_without_a_running_systemd_is_systemd() {
  _clean_path; _os_release fedora; _load
  assert_eq "$(detect_init_backend)" systemd
}
test_detects_xbps_runit_from_run_runit() {
  _clean_path; stub xbps-install; mkdir -p "$HOME/rootfs/run/runit"; export VITRUM_ROOTFS="$HOME/rootfs"; _load
  assert_eq "$(detect_pkg_backend)+$(detect_init_backend)" "xbps+runit"
}
test_detects_runit_as_pid_1() {
  _clean_path; mkdir -p "$HOME/rootfs/proc/1"; echo runit > "$HOME/rootfs/proc/1/comm"; export VITRUM_ROOTFS="$HOME/rootfs"; _load
  assert_eq "$(detect_init_backend)" runit
}
# In a container runit is not PID 1 and /run/runit is absent: Void says runit.
test_detects_runit_from_os_release_on_void() {
  _clean_path; _os_release void; _load
  assert_eq "$(detect_init_backend)" runit
}
test_load_backends_fedora_and_void() {
  _clean_path; stub dnf; _os_release fedora; _load
  load_backends
  assert_eq "$PKG_BACKEND+$INIT_BACKEND" "dnf+systemd"
  declare -F _dnf_enable_coprs >/dev/null
  rm -f "$STUBS/dnf"; stub xbps-install; _os_release void
  load_backends
  assert_eq "$PKG_BACKEND+$INIT_BACKEND" "xbps+runit"
  declare -F svc_use_networkmanager >/dev/null && declare -F _runit_svdir >/dev/null
}
test_rejects_xbps_with_systemd() {
  _clean_path; stub xbps-install; _os_release void; mkdir -p "$VITRUM_ROOTFS/run/systemd/system"; _load
  out="$( (load_backends) 2>&1 )" && { echo "load_backends should fail"; return 1; }
  assert_contains "$out" "unsupported system: packages=xbps init=systemd"
  assert_contains "$out" "Void with runit"
}
# Every backend defines what the stages call.
test_new_backends_define_the_full_function_set() {
  source "$VITRUM_DIR/lib/common.sh"
  local f fn
  for f in pkg-dnf pkg-xbps; do
    ( source "$VITRUM_DIR/lib/backend/$f.sh"
      for fn in pkg_installed pkg_available pkg_install pkg_prepare pkg_apply_use pkg_write_portage_files; do
        declare -F "$fn" >/dev/null || { echo "$f lacks $fn"; exit 1; }
      done ) || return 1
  done
  ( source "$VITRUM_DIR/lib/backend/init-runit.sh"
    for fn in svc_exists svc_enable_system svc_use_networkmanager svc_enable_display_manager session_exec_line \
              session_unit_install audio_bootstrap_line audio_enable_user dm_current; do
      declare -F "$fn" >/dev/null || { echo "init-runit lacks $fn"; exit 1; }
    done )
}

# dnf: rpm says what is installed; COPR rows count only from a COPR.
_dnf() {
  _clean_path; stub sudo '"$@"'
  stub dnf 'echo "dnf $*" >> "$HOME/calls"; [[ "$*" == *repoquery* ]] && { echo "dnf repoquery" >> "$HOME/queries"; printf "%s\n" "jq x86_64" "quickshell x86_64" "matugen x86_64" "ffmpeg x86_64" "srconly src"; }; exit 0'
  stub rpm 'case "$1" in -E) echo 44;; -q) [[ "$2" == --qf ]] && { n="$4"; v="$(grep "^$n " "$HOME/rpmdb" 2>/dev/null | cut -d" " -f2-)"; [[ -n "$v" ]] && { printf "%s" "$v"; exit 0; }; exit 1; }; grep -q "^$2\( \|$\)" "$HOME/rpmdb" 2>/dev/null;; esac'
  export PKG_BACKEND=dnf; _os_release fedora
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"; source "$VITRUM_DIR/lib/backend/pkg-dnf.sh"
}
test_dnf_names_from_the_table_syntax() {
  _dnf
  assert_eq "$(_dnf_name copr:errornointernet/quickshell:quickshell)" quickshell
  assert_eq "$(_dnf_copr copr:errornointernet/quickshell:quickshell)" errornointernet/quickshell
  assert_eq "$(_dnf_name 'wget1-wget|wget2-wget@wget')" wget1-wget
  assert_eq "$(_dnf_name rpmfusion:ffmpeg)" ffmpeg
  assert_eq "$(_dnf_copr rpmfusion:ffmpeg)" ""
}
test_dnf_install_strips_prefixes_and_installs_the_first_alternative() {
  _dnf
  pkg_install jq 'wget1-wget|wget2-wget@wget' copr:atim/starship:starship
  assert_contains "$(cat "$HOME/calls")" "dnf install -y jq wget1-wget starship"
  ! grep -q "copr:\|@\||" "$HOME/calls"
}
# Fedora's matugen 3 and quickshell 0.2 are too old: installed under the COPR's
# name they do not count, and the COPR build replaces them.
test_dnf_copr_row_needs_the_copr_build() {
  _dnf
  echo "matugen Fedora Project" > "$HOME/rpmdb"
  ! pkg_installed copr:avengemedia/danklinux:matugen
  echo "matugen Fedora Copr - user avengemedia" > "$HOME/rpmdb"
  pkg_installed copr:avengemedia/danklinux:matugen
  echo "matugen Fedora Project" > "$HOME/rpmdb"
  pkg_install copr:avengemedia/danklinux:matugen >/dev/null
  assert_contains "$(cat "$HOME/calls")" "dnf upgrade -y matugen"
}
test_dnf_swaps_ffmpeg_free_and_tuned_ppd() {
  _dnf
  printf 'ffmpeg-free\ntuned-ppd\n' > "$HOME/rpmdb"
  pkg_install rpmfusion:ffmpeg power-profiles-daemon jq >/dev/null
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" "dnf swap -y --allowerasing ffmpeg-free ffmpeg"
  assert_contains "$calls" "dnf swap -y --allowerasing tuned-ppd power-profiles-daemon"
  assert_contains "$calls" "dnf install -y jq"
  # the swaps come first: the batch then links against RPM Fusion's libraries
  assert_contains "$(head -1 "$HOME/calls")" "swap"
}
test_dnf_ffmpeg_without_ffmpeg_free_still_allows_erasing() {
  _dnf
  pkg_install rpmfusion:ffmpeg >/dev/null
  assert_contains "$(cat "$HOME/calls")" "dnf install -y --allowerasing ffmpeg"
}
# Only the repositories the rows of this run need, for what is not installed.
test_dnf_prepare_enables_only_needed_repositories() {
  _dnf; stub lspci
  _package_needs() { echo required; }
  packages_for() { printf '%s\n' jq copr:errornointernet/quickshell:quickshell copr:mineiro/hyprland:satty copr:mineiro/hyprland:awww copr:atim/starship:starship rpmfusion:ffmpeg; }
  echo "starship Fedora Copr - user atim" > "$HOME/rpmdb"
  pkg_prepare >"$HOME/out" 2>&1
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" "dnf copr enable -y errornointernet/quickshell"
  assert_eq "$(grep -c "copr enable -y mineiro/hyprland" <<<"$calls")" 1
  ! grep -q "atim/starship" <<<"$calls"
  assert_contains "$calls" "rpmfusion-free-release-44.noarch.rpm"
  ! grep -q "nonfree" <<<"$calls"
  assert_contains "$(cat "$HOME/out")" "third-party COPR repositories"
  assert_contains "$(cat "$HOME/out")" "RPM Fusion (free)"
}
test_dnf_prepare_skips_enabled_coprs_and_adds_nonfree_for_nvidia() {
  _dnf
  _package_needs() { printf '%s\n' required nvidia; }
  packages_for() { printf '%s\n' copr:errornointernet/quickshell:quickshell; }
  mkdir -p "$VITRUM_ROOTFS/etc/yum.repos.d"
  printf '[x]\nenabled=1\n' > "$VITRUM_ROOTFS/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:errornointernet:quickshell.repo"
  pkg_prepare >/dev/null 2>&1
  calls="$(cat "$HOME/calls")"
  ! grep -q "copr enable" <<<"$calls"
  assert_contains "$calls" "rpmfusion-free-release-44"
  assert_contains "$calls" "rpmfusion-nonfree-release-44"
}
test_dnf_refuses_fedora_older_than_43() {
  _dnf; _package_needs() { echo required; }; packages_for() { :; }
  printf 'ID=fedora\nVERSION_ID=41\n' > "$VITRUM_ROOTFS/etc/os-release"
  out="$( (pkg_prepare) 2>&1 )" && { echo "should refuse"; return 1; }
  assert_contains "$out" "Fedora 41 is too old"
}
# One repoquery for the whole list, not one per package.
test_dnf_available_reads_the_repositories_once() {
  _dnf
  out="$(pkg_unavailable jq quickshell nosuch matugen srconly)"
  assert_eq "$out" $'nosuch\nsrconly'     # a source package is not installable
  assert_eq "$(wc -l < "$HOME/queries" | tr -d ' ')" 1
}
test_dnf_dry_run_takes_copr_packages_as_available() {
  _dnf; export DRY_RUN=1
  pkg_available copr:dejan/lazygit:lazygit
  ! pkg_available not-a-package
}

_xbps() {
  _clean_path; stub sudo '"$@"'
  stub xbps-install 'echo "xbps-install $*" >> "$HOME/calls"; exit "${XBPS_RC:-0}"'
  stub xbps-query 'if [[ "$1" == -R ]]; then grep -qx "$2" "$HOME/repo" 2>/dev/null; else grep -qx "$1" "$HOME/installed" 2>/dev/null; fi'
  stub xbps-uhelper 'echo "${XBPS_ARCH:-x86_64}"'
  export PKG_BACKEND=xbps
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"; source "$VITRUM_DIR/lib/backend/pkg-xbps.sh"
}
test_xbps_installed_and_available() {
  _xbps; echo fish-shell > "$HOME/installed"; printf 'fish-shell\nquickshell\n' > "$HOME/repo"
  pkg_installed fish-shell
  ! pkg_installed quickshell
  pkg_installed "nope|fish-shell"
  stub cargo; pkg_installed "cargo@cargo"
  pkg_available quickshell
  ! pkg_available nerd-fonts-ttf
}
test_xbps_install_names_and_already_installed_is_fine() {
  _xbps
  pkg_install "cargo@cargo" fish-shell
  assert_contains "$(cat "$HOME/calls")" "xbps-install -y cargo fish-shell"
  XBPS_RC=17 pkg_install fish-shell
  out="$( (XBPS_RC=19; export XBPS_RC; pkg_install fish-shell) 2>&1 )" && { echo "should fail"; return 1; }
  assert_contains "$out" "status 19"
}
test_xbps_prepare_syncs_and_nonfree_only_for_nvidia() {
  _xbps; _package_needs() { echo required; }
  pkg_prepare >/dev/null
  assert_contains "$(cat "$HOME/calls")" "xbps-install -Sy"
  ! grep -q nonfree "$HOME/calls"
  _package_needs() { printf '%s\n' required nvidia; }
  pkg_prepare >/dev/null
  assert_contains "$(cat "$HOME/calls")" "xbps-install -y void-repo-nonfree"
}
test_xbps_updates_itself_first_when_due() {
  _xbps; _package_needs() { echo required; }
  stub xbps-install 'echo "xbps-install $*" >> "$HOME/calls"; [[ "$1" == -un ]] && echo "xbps-0.60.8_1 update x86_64 https://repo"; exit 0'
  pkg_prepare >/dev/null
  assert_contains "$(cat "$HOME/calls")" "xbps-install -uy xbps"
}
test_xbps_refuses_musl() {
  _xbps; _package_needs() { echo required; }; export XBPS_ARCH=x86_64-musl
  out="$( (pkg_prepare) 2>&1 )" && { echo "should refuse"; return 1; }
  assert_contains "$out" "musl"
}

# runit: a fake root with /etc/sv and the runlevel directory.
_runit() {  # _runit [running]
  stub sudo '"$@"'; stub sv 'echo "sv $*" >> "$HOME/calls"'; stub sleep
  export VITRUM_ROOTFS="$HOME/rootfs" VITRUM_SYSROOT="$HOME/rootfs" INIT_BACKEND=runit
  local s
  for s in dbus elogind polkitd bluetoothd NetworkManager dhcpcd sddm gdm cronie power-profiles-daemon; do mkdir -p "$VITRUM_ROOTFS/etc/sv/$s"; done
  mkdir -p "$VITRUM_ROOTFS/etc/runit/runsvdir/default"
  ln -s default "$VITRUM_ROOTFS/etc/runit/runsvdir/current"
  if [[ "${1:-}" == running ]]; then
    mkdir -p "$VITRUM_ROOTFS/run/runit/runsvdir"
    mkdir -p "$VITRUM_ROOTFS/var"
    ln -s ../etc/runit/runsvdir/current "$VITRUM_ROOTFS/var/service"
  fi
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-runit.sh"
}
_rl() { echo "$VITRUM_ROOTFS/etc/runit/runsvdir/default"; }
test_runit_enable_links_the_service_and_is_idempotent() {
  _runit
  out="$(svc_enable_system bluetoothd 2>&1)"
  assert_eq "$(readlink "$(_rl)/bluetoothd")" /etc/sv/bluetoothd
  svc_enable_system bluetoothd >/dev/null 2>&1
  assert_eq "$(readlink "$(_rl)/bluetoothd")" /etc/sv/bluetoothd
  # runit is not running (a container): nothing is asked of sv, and that is said.
  [[ ! -e "$HOME/calls" ]]
  assert_contains "$out" "starts on the next boot"
}
test_runit_enable_starts_it_when_runit_runs() {
  _runit running
  svc_enable_system dbus >/dev/null 2>&1
  [[ -L "$VITRUM_ROOTFS/var/service/dbus" ]]
  assert_contains "$(cat "$HOME/calls")" "sv up dbus"
}
test_runit_missing_service_is_skipped() {
  _runit
  svc_enable_system no-such-service >/dev/null 2>&1
  [[ ! -e "$(_rl)/no-such-service" ]]
}
test_runit_session_line_and_no_unit() {
  _runit
  assert_contains "$(session_exec_line)" "dbus-run-session /usr/local/bin/niri --session"
  session_unit_install
  [[ ! -e "$VITRUM_SYSROOT/etc/systemd" ]]
}
test_runit_audio_starts_pipewire_and_the_rest() {
  _runit
  l="$(audio_bootstrap_line)"
  assert_contains "$l" 'spawn-at-startup "sh" "-c" "pipewire & '
  assert_contains "$l" "pipewire-pulse & "
  assert_contains "$l" "wireplumber & "
  # Void's handbook links: PipeWire starts the others itself.
  mkdir -p "$VITRUM_SYSROOT/etc/pipewire/pipewire.conf.d"
  touch "$VITRUM_SYSROOT/etc/pipewire/pipewire.conf.d/10-wireplumber.conf" "$VITRUM_SYSROOT/etc/pipewire/pipewire.conf.d/20-pipewire-pulse.conf"
  assert_eq "$(audio_bootstrap_line)" 'spawn-at-startup "pipewire"'
  # turnstile user services run it already.
  mkdir -p "$HOME/.config/service/pipewire"
  assert_eq "$(audio_bootstrap_line)" ""
}
# dhcpcd runs the network of the install: NetworkManager takes over at the next boot.
test_runit_networkmanager_waits_for_the_next_boot() {
  _runit running
  ln -s /etc/sv/dhcpcd "$(_rl)/dhcpcd"
  out="$(svc_use_networkmanager 2>&1)"; svc_use_networkmanager >/dev/null 2>&1
  [[ -L "$(_rl)/dhcpcd" && ! -e "$(_rl)/NetworkManager" ]]
  rc="$(cat "$VITRUM_ROOTFS/etc/rc.local")"
  assert_contains "$rc" "rm -f /etc/runit/runsvdir/current/dhcpcd"
  assert_contains "$rc" "ln -sfn /etc/sv/NetworkManager /etc/runit/runsvdir/current/NetworkManager"
  assert_eq "$(grep -c "rm -f /etc/runit/runsvdir/current/dhcpcd" <<<"$rc")" 1
  assert_eq "$(grep -c "^# vitrum begin" <<<"$rc")" 1
  [[ -x "$VITRUM_ROOTFS/etc/rc.local" ]]
  assert_contains "$out" "next boot"
  ! grep -q "sv " "$HOME/calls" 2>/dev/null
}
test_runit_rc_local_block_keeps_the_rest_and_removes_itself() {
  _runit running
  printf '#!/bin/sh\nmodprobe something\nexit 0\n' > "$VITRUM_ROOTFS/etc/rc.local"; chmod +x "$VITRUM_ROOTFS/etc/rc.local"
  ln -s /etc/sv/dhcpcd "$(_rl)/dhcpcd"
  svc_use_networkmanager >/dev/null 2>&1
  rc="$VITRUM_ROOTFS/etc/rc.local"
  # After the shebang, before the user's exit 0, which would never reach it at the end.
  assert_eq "$(sed -n 2p "$rc")" "$_RUNIT_BOOT_BEGIN"
  assert_eq "$(tail -2 "$rc")" $'modprobe something\nexit 0'
  # The block's own last line, run on the file: only the block goes.
  grep '^vitrum_rc=' "$rc" | sed "s#/etc/rc.local#$rc#g" > "$HOME/selfdel.sh"
  sh "$HOME/selfdel.sh"
  assert_eq "$(cat "$rc")" $'#!/bin/sh\nmodprobe something\nexit 0'
}
# A begin marker whose end is gone is not a block: what follows it is the user's.
test_runit_rc_local_lone_begin_marker_keeps_the_user_lines() {
  _runit running
  printf '#!/bin/sh\n%s\nmy-command --at-boot\n' "$_RUNIT_BOOT_BEGIN" > "$VITRUM_ROOTFS/etc/rc.local"
  [[ -z "$(_runit_boot_lines)" ]]
  ln -s /etc/sv/dhcpcd "$(_rl)/dhcpcd"
  svc_use_networkmanager >/dev/null 2>&1
  rc="$VITRUM_ROOTFS/etc/rc.local"
  assert_contains "$(cat "$rc")" "my-command --at-boot"
  assert_eq "$(_runit_boot_lines | tr '\n' ' ')" "rm -f /etc/runit/runsvdir/current/dhcpcd ln -sfn /etc/sv/NetworkManager /etc/runit/runsvdir/current/NetworkManager "
  grep '^vitrum_rc=' "$rc" | sed "s#/etc/rc.local#$rc#g" > "$HOME/selfdel.sh"; sh "$HOME/selfdel.sh"
  assert_contains "$(cat "$rc")" "my-command --at-boot"
  ! grep -q "NetworkManager" "$rc"
}
test_runit_rc_local_created_when_missing_and_executable_noted() {
  _runit running
  ln -s /etc/sv/dhcpcd "$(_rl)/dhcpcd"
  out="$(svc_use_networkmanager 2>&1)"
  rc="$VITRUM_ROOTFS/etc/rc.local"
  [[ -x "$rc" ]]
  assert_eq "$(head -1 "$rc")" "#!/bin/sh"
  ! grep -q "was not executable" <<<"$out"
  # A user rc.local that was not executable: its own lines will run at boot now.
  printf '#!/bin/sh\necho mine\n' > "$HOME/rc"; cp "$HOME/rc" "$rc"; chmod 644 "$rc"
  out="$(_runit_at_next_boot "rm -f /etc/runit/runsvdir/current/x" 2>&1)"
  assert_contains "$out" "was not executable"
  [[ -x "$rc" ]]
}
test_runit_networkmanager_now_without_competitors() {
  _runit running
  svc_use_networkmanager >/dev/null 2>&1
  [[ -L "$VITRUM_ROOTFS/var/service/NetworkManager" ]]
  [[ ! -e "$VITRUM_ROOTFS/etc/rc.local" ]]
}
test_runit_networkmanager_in_a_chroot_switches_at_once() {
  _runit
  ln -s /etc/sv/dhcpcd "$(_rl)/dhcpcd"
  svc_use_networkmanager >/dev/null 2>&1
  [[ ! -e "$(_rl)/dhcpcd" && -L "$(_rl)/NetworkManager" ]]
}
# Nothing starts the bus, the seat or polkit on runit: the packages stage links them.
test_runit_packages_stage_enables_the_void_services() {
  _runit
  export PKG_BACKEND=xbps
  source "$VITRUM_DIR/lib/packages.sh"; source "$VITRUM_DIR/lib/backend/pkg-xbps.sh"; source "$VITRUM_DIR/lib/stages/10-packages.sh"
  stub lspci; stub xbps-query 'exit 0'
  pkg_prepare() { :; }; pkg_install() { :; }; _package_needs() { echo required; }
  stage_packages >/dev/null 2>&1
  local s
  for s in dbus elogind polkitd bluetoothd power-profiles-daemon cronie NetworkManager; do
    [[ -L "$(_rl)/$s" ]] || { echo "$s not linked"; return 1; }
  done
}
# grep -q quits at the match; systemctl, still writing, got SIGPIPE, and under
# pipefail the unit counted as absent.
test_systemd_svc_exists_survives_pipefail() {
  stub systemctl 'echo "UNIT FILE STATE PRESET"; echo "$2 enabled enabled"; for i in $(seq 1 20000); do echo "padding line $i"; done'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-systemd.sh"
  set -o pipefail
  svc_exists NetworkManager
}

# Every Void network client is seen, also per interface; iwd stays and becomes
# NetworkManager's Wi-Fi backend.
test_runit_network_clients_by_glob_and_iwd_stays() {
  _runit running
  for x in dhcpcd-eth0 connmand iwd; do mkdir -p "$VITRUM_ROOTFS/etc/sv/$x"; ln -s "/etc/sv/$x" "$(_rl)/$x"; done
  assert_eq "$(_runit_network_clients | tr '\n' ' ')" "dhcpcd-eth0 iwd connmand "
  out="$(svc_use_networkmanager 2>&1)"
  q="$(_runit_boot_lines)"
  assert_contains "$q" "rm -f /etc/runit/runsvdir/current/dhcpcd-eth0"
  assert_contains "$q" "rm -f /etc/runit/runsvdir/current/connmand"
  ! grep -q "current/iwd" <<<"$q"
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/NetworkManager/conf.d/wifi_backend.conf")" "wifi.backend=iwd"
  assert_contains "$out" "iwd stays"
}
# wpa_supplicant's service goes only when D-Bus can start it for NetworkManager,
# and the user is told the Wi-Fi networks must be joined again.
test_runit_wpa_supplicant_goes_only_with_a_backend_left() {
  _runit running
  mkdir -p "$VITRUM_ROOTFS/etc/sv/wpa_supplicant"; ln -s /etc/sv/wpa_supplicant "$(_rl)/wpa_supplicant"
  out="$(svc_use_networkmanager 2>&1)"
  ! grep -q "current/wpa_supplicant" <<<"$(_runit_boot_lines)"
  assert_contains "$out" "no Wi-Fi backend"
  rm -f "$VITRUM_ROOTFS/etc/rc.local"
  mkdir -p "$VITRUM_ROOTFS/usr/share/dbus-1/system-services"; : > "$VITRUM_ROOTFS$_RUNIT_WPA_DBUS"
  out="$(svc_use_networkmanager 2>&1)"
  assert_contains "$(_runit_boot_lines)" "rm -f /etc/runit/runsvdir/current/wpa_supplicant"
  assert_contains "$out" "join them again"
}
test_runit_knows_more_login_screens() {
  _runit running
  mkdir -p "$VITRUM_ROOTFS/etc/sv/ly"; ln -s /etc/sv/ly "$(_rl)/ly"
  assert_eq "$(dm_current)" ly
}

# COPRs: only the table's packages (and what they need that only the COPR has).
_dnf_copr_world() {
  _dnf; stub dnf5
  mkdir -p "$VITRUM_ROOTFS/etc/yum.repos.d"
  stub dnf 'echo "dnf $*" >> "$HOME/calls"
    case "$*" in
      *"repo list"*) printf "repo id  repo name\nfedora  Fedora\nupdates  Updates\ncopr:copr.fedorainfracloud.org:errornointernet:quickshell  Q\n" ;;
      *providers-of*) [[ -e "$HOME/query-fails" ]] && exit 1
                      printf "glibc fedora\ncpptrace copr:copr.fedorainfracloud.org:errornointernet:quickshell\nqt6-qtbase updates\n" ;;
      *--installed*) cat "$HOME/installed-from" 2>/dev/null ;;
    esac; exit 0'
}
_copr_repo() { printf '[copr:copr.fedorainfracloud.org:%s:%s]\nname=x\nenabled=1\n' "${1%%/*}" "${1#*/}" > "$VITRUM_ROOTFS/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${1%%/*}:${1#*/}.repo"; }
_ours() { mkdir -p "$VITRUM_STATE"; printf '%s\n' "$@" >> "$VITRUM_STATE/coprs-enabled"; }
test_dnf_copr_takes_only_the_table_packages() {
  _dnf_copr_world; _copr_repo errornointernet/quickshell; _ours errornointernet/quickshell
  out="$(_dnf_copr_limit errornointernet/quickshell 2>&1)"
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" "dnf config-manager setopt copr:copr.fedorainfracloud.org:errornointernet:quickshell.includepkgs=quickshell,cpptrace"
  # the dependency query sees the COPR unfiltered, beside the non-COPR repositories only
  assert_contains "$calls" "--setopt=copr:copr.fedorainfracloud.org:errornointernet:quickshell.includepkgs= --repo=fedora --repo=updates --repo=copr:copr.fedorainfracloud.org:errornointernet:quickshell"
  assert_contains "$out" "only quickshell, cpptrace come from it"
}
# Asked again every run; the same set is no change.
test_dnf_copr_limit_unchanged_is_not_written_again() {
  _dnf_copr_world; _copr_repo errornointernet/quickshell; _ours errornointernet/quickshell
  mkdir -p "$VITRUM_ROOTFS/etc/dnf/repos.override.d"
  printf '[copr:copr.fedorainfracloud.org:errornointernet:quickshell]\nincludepkgs=cpptrace,quickshell\n' > "$VITRUM_ROOTFS/etc/dnf/repos.override.d/99-config_manager.repo"
  _dnf_copr_limit errornointernet/quickshell >/dev/null 2>&1
  assert_contains "$(cat "$HOME/calls")" "providers-of"
  ! grep -q "setopt copr" "$HOME/calls"
}
# A new COPR-only dependency is let in on the next run.
test_dnf_copr_limit_follows_a_new_dependency() {
  _dnf_copr_world; _copr_repo errornointernet/quickshell; _ours errornointernet/quickshell
  mkdir -p "$VITRUM_ROOTFS/etc/dnf/repos.override.d"
  printf '[copr:copr.fedorainfracloud.org:errornointernet:quickshell]\nincludepkgs=quickshell\n' > "$VITRUM_ROOTFS/etc/dnf/repos.override.d/99-config_manager.repo"
  _dnf_copr_limit errornointernet/quickshell >/dev/null 2>&1
  assert_contains "$(cat "$HOME/calls")" "includepkgs=quickshell,cpptrace"
}
# The query failed: the list is not written, let alone shrunk.
test_dnf_copr_limit_keeps_the_list_when_dnf_cannot_say() {
  _dnf_copr_world; _copr_repo errornointernet/quickshell; _ours errornointernet/quickshell; touch "$HOME/query-fails"
  mkdir -p "$VITRUM_ROOTFS/etc/dnf/repos.override.d"
  printf '[copr:copr.fedorainfracloud.org:errornointernet:quickshell]\nincludepkgs=quickshell,cpptrace,breakpad\n' > "$VITRUM_ROOTFS/etc/dnf/repos.override.d/99-config_manager.repo"
  out="$(_dnf_copr_limit errornointernet/quickshell 2>&1)"
  ! grep -q "setopt copr" "$HOME/calls"
  assert_contains "$out" "stays as it is (quickshell,cpptrace,breakpad)"
}
# What is installed from the COPR stays reachable through it.
test_dnf_copr_limit_keeps_what_came_from_it() {
  _dnf_copr_world; _copr_repo mineiro/hyprland; _ours mineiro/hyprland
  printf 'hyprutils copr:copr.fedorainfracloud.org:mineiro:hyprland\nbash fedora\n' > "$HOME/installed-from"
  _dnf_copr_limit mineiro/hyprland >/dev/null 2>&1
  assert_contains "$(cat "$HOME/calls")" "mineiro:hyprland.includepkgs=awww,satty,hyprutils"
}
# A COPR the user enabled before vitrum is theirs: no limit, a note.
test_dnf_copr_enabled_by_the_user_is_left_alone() {
  _dnf_copr_world; _copr_repo sdegler/hyprland
  out="$(_dnf_copr_limit sdegler/hyprland 2>&1)"
  ! grep -q "setopt\|repoquery" "$HOME/calls" 2>/dev/null
  assert_contains "$out" "you had it enabled before vitrum — left as it is (vitrum takes mpvpaper from it)"
}
# Enabling records the COPR as vitrum's (not in a dry run).
test_dnf_enabling_a_copr_records_it() {
  _dnf_copr_world
  _dnf_enable_coprs atim/starship >/dev/null 2>&1
  assert_eq "$(cat "$VITRUM_STATE/coprs-enabled")" atim/starship
  _dnf_enable_coprs atim/starship >/dev/null 2>&1
  assert_eq "$(grep -c . "$VITRUM_STATE/coprs-enabled")" 1
  rm -f "$VITRUM_STATE/coprs-enabled"; export DRY_RUN=1
  _dnf_enable_coprs dejan/lazygit >/dev/null 2>&1
  [[ ! -e "$VITRUM_STATE/coprs-enabled" ]]
}
# A COPR vitrum enabled in an earlier run, for a part not chosen now, is limited too.
test_dnf_prepare_limits_coprs_from_earlier_runs() {
  _dnf_copr_world; _copr_repo dejan/lazygit; _ours dejan/lazygit; _copr_repo sdegler/hyprland
  _package_needs() { echo required; }; packages_for() { :; }
  pkg_prepare >/dev/null 2>&1
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" "copr:copr.fedorainfracloud.org:dejan:lazygit.includepkgs=lazygit"
  ! grep -q "sdegler:hyprland.includepkgs" <<<"$calls"                      # the user's
  ! grep -q "errornointernet:quickshell.includepkgs=quickshell" <<<"$calls"   # not enabled here
}
test_dnf4_copr_limit_goes_into_the_repo_file() {
  _dnf_copr_world; rm -f "$STUBS/dnf5"; _copr_repo atim/starship; _ours atim/starship
  f="$VITRUM_ROOTFS/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:atim:starship.repo"
  printf '[copr:copr.fedorainfracloud.org:atim:starship-dep]\nenabled=1\n' >> "$f"
  _dnf_copr_limit atim/starship >/dev/null 2>&1
  assert_eq "$(awk '/^\[/{s=$0} /^includepkgs=/{print s " " $0}' "$f")" "[copr:copr.fedorainfracloud.org:atim:starship] includepkgs=starship"
  _dnf_copr_limit atim/starship >/dev/null 2>&1
  assert_eq "$(grep -c '^includepkgs=' "$f")" 1
}
# tuned-ppd swapped out: tuned itself is turned off, and what dnf removed is said.
test_dnf_swap_turns_tuned_off_and_says_what_went() {
  _dnf
  printf 'tuned-ppd\ntuned\n' > "$HOME/rpmdb"
  stub rpm 'case "$1" in -qa) cat "$HOME/rpmdb";; -q) grep -qx "$2" "$HOME/rpmdb";; esac'
  stub dnf 'echo "dnf $*" >> "$HOME/calls"; [[ "$1" == swap ]] && { grep -v tuned-ppd "$HOME/rpmdb" > "$HOME/x"; echo power-profiles-daemon >> "$HOME/x"; mv "$HOME/x" "$HOME/rpmdb"; }; exit 0'
  stub systemctl 'echo "systemctl $*" >> "$HOME/calls"; [[ "$*" == *is-enabled* ]] && exit 0; exit 0'
  out="$(pkg_install power-profiles-daemon 2>&1)"
  assert_contains "$(cat "$HOME/calls")" "systemctl disable --now tuned.service"
  assert_contains "$out" "dnf removed to make room: tuned-ppd"
}

# rc.local runs as runit runs it, bash and all: the block's commands run, every
# line of the user's runs exactly once, and the block is gone afterwards.
# Rewritten in place, bash went on at its old offset and skipped them.
test_runit_rc_local_runs_whole_under_bash() {
  _runit running
  rc="$VITRUM_ROOTFS/etc/rc.local"
  { printf '#!/bin/bash\n'; for i in $(seq 1 120); do printf 'echo "user line %s" >> "%s/ran"\n' "$i" "$HOME"; done; } > "$rc"
  chmod 755 "$rc"
  ln -s /etc/sv/dhcpcd "$(_rl)/dhcpcd"
  svc_use_networkmanager >/dev/null 2>&1
  # As at boot, with this fake root standing in for /.
  sed -i.bak "s#/etc/#$VITRUM_ROOTFS/etc/#g" "$rc" && rm -f "$rc.bak"
  "$rc"
  [[ -L "$(_rl)/NetworkManager" && ! -e "$(_rl)/dhcpcd" ]]
  assert_eq "$(wc -l < "$HOME/ran" | tr -d ' ')" 120
  assert_eq "$(sort -u "$HOME/ran" | wc -l | tr -d ' ')" 120
  ! grep -q "vitrum begin" "$rc"
  assert_eq "$(sed -n 2p "$rc")" "echo \"user line 1\" >> \"$HOME/ran\""
  [[ -x "$rc" ]]
}
# An /etc/rc.local that points to a file not there yet: made where it points.
test_runit_rc_local_dangling_symlink() {
  _runit running
  ln -s rc.d/rc.local "$VITRUM_ROOTFS/etc/rc.local"
  ln -s /etc/sv/dhcpcd "$(_rl)/dhcpcd"
  ( svc_use_networkmanager >/dev/null 2>&1 ) || { echo "died"; return 1; }
  [[ -L "$VITRUM_ROOTFS/etc/rc.local" ]]
  assert_contains "$(cat "$VITRUM_ROOTFS/etc/rc.d/rc.local")" "rm -f /etc/runit/runsvdir/current/dhcpcd"
}
