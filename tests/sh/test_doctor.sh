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
  stub qs; stub fc-list 'echo "Inter: x"; echo "JetBrains Mono: x"; echo "Phosphor-Light: x"; echo "Phosphor-Fill: x"'
  out="$(stage_doctor 2>&1)" || { grep -E "✗|fail" <<<"$out"; return 1; }
  # the icon fonts are Phosphor's, Light and Fill
  assert_contains "$out" "font: Phosphor-Light"
  assert_contains "$out" "font: Phosphor-Fill"
  assert_contains "$out" "no shell crashes in the last 7 days"
  ! grep -q "Material" <<<"$out"
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

# Fedora's own quickshell (0.2) and matugen (3) install under the right names
# and are too old: the doctor says so.
test_doctor_names_a_too_old_quickshell_and_matugen() {
  _load; export VITRUM_NIRI_BIN="$HOME/nope"
  stub qs 'echo "quickshell 0.2.1, revision dacfa9d"'
  stub matugen 'echo "matugen 3.1.0"'
  out="$(stage_doctor 2>&1)" || true
  assert_contains "$out" "quickshell 0.2.1"
  assert_contains "$out" "0.3.1 or newer"
  assert_contains "$out" "matugen 3.1.0"
  stub qs 'echo "quickshell 0.3.2"'; stub matugen 'echo "matugen 4.2.0"'
  out="$(stage_doctor 2>&1)" || true
  ! grep -q "0.3.1 or newer" <<<"$out"
  ! grep -q "need matugen 4" <<<"$out"
}
# Crashes come from Quickshell's reports, the same on every init.
_crash() {  # _crash <id> <fixture> [seconds ago]
  local d="$XDG_CACHE_HOME/quickshell/crashes/$1" then=$(($(date +%s) - ${3:-0}))
  mkdir -p "$d"; cp "$VITRUM_DIR/tests/fixtures/crashes/$2" "$d/report.txt"
  touch -t "$(date -d "@$then" +%Y%m%d%H%M.%S 2>/dev/null || date -r "$then" +%Y%m%d%H%M.%S)" "$d/report.txt"
}
test_doctor_says_when_there_are_no_crashes() {
  _load
  out="$(_doctor_crashes 2>&1)"
  assert_contains "$out" "no shell crashes in the last 7 days"
}
# The same answers as tests/js/crashes.test.mjs gets from these fixtures.
test_doctor_reads_a_crash_like_the_shell_does() {
  _load
  assert_eq "$(_doc_crash "$VITRUM_DIR/tests/fixtures/crashes/segv.txt")" "Segmentation fault in QQuickListView::viewportMoved"
  assert_eq "$(_doc_crash "$VITRUM_DIR/tests/fixtures/crashes/abort.txt")" "Aborted in qs::service::Node::bind"
}
_stack() { printf '===== Instance Information =====\nSignal: Bus error (7)\nConfig Path: %s\n\n===== Stacktrace =====\n%s\n\n===== Log Tail =====\n#1  0x00007f in log::line()\n' "${2:-}" "$1" > "$HOME/report.txt"; }
test_doctor_crash_without_a_usable_stack_falls_back_to_the_signal() {
  _load
  _stack '(no trace available)'
  assert_eq "$(_doc_crash "$HOME/report.txt")" "Bus error (no usable stack in the report)"
  _stack '#0  0x00007f at /usr/lib/libc.so.6'
  assert_eq "$(_doc_crash "$HOME/report.txt")" "Bus error (no usable stack in the report)"
  _stack '#0  0x00007f at /usr/lib/libc.so.6
#1  0x00007f at /usr/lib/libnvidia-glcore.so.575.64'
  assert_eq "$(_doc_crash "$HOME/report.txt")" "Bus error in libnvidia-glcore.so (no symbols)"
  _stack '#0  0x00007f in foo::bar(int) at /src/foo.cpp:12:3'
  assert_eq "$(_doc_crash "$HOME/report.txt")" "Bus error in foo::bar"
}
test_doctor_lists_recent_crashes_newest_first() {
  _load
  _crash older abort.txt 7200
  _crash newer segv.txt 60
  out="$(_doctor_crashes 2>&1)"
  assert_contains "$out" "shell crashes: 2 in the last 7 days"
  assert_contains "$out" "Segmentation fault in QQuickListView::viewportMoved — $XDG_CACHE_HOME/quickshell/crashes/newer/report.txt"
  assert_contains "$out" "$(date '+%F') "
  assert_eq "$(grep -n 'Aborted in' <<<"$out" | cut -d: -f1)" 3
}
test_doctor_leaves_out_old_crashes_and_other_configs() {
  _load
  _crash old segv.txt $((8 * 86400))
  mkdir -p "$XDG_CACHE_HOME/quickshell/crashes/settings"
  sed 's#quickshell/vitrum/shell.qml#quickshell/vitrum-settings/shell.qml#' "$VITRUM_DIR/tests/fixtures/crashes/segv.txt" > "$XDG_CACHE_HOME/quickshell/crashes/settings/report.txt"
  out="$(_doctor_crashes 2>&1)"
  assert_contains "$out" "no shell crashes in the last 7 days"
}
# A crash with no run id lands next to the folders, and has no config path.
test_doctor_finds_a_crash_without_a_run_id() {
  _load
  mkdir -p "$XDG_CACHE_HOME/quickshell/crashes"
  sed 's#^Config Path: .*#Config Path: #; s#^Run ID: .*#Run ID: #' "$VITRUM_DIR/tests/fixtures/crashes/segv.txt" > "$XDG_CACHE_HOME/quickshell/crashes/report.txt"
  out="$(_doctor_crashes 2>&1)"
  assert_contains "$out" "$XDG_CACHE_HOME/quickshell/crashes/report.txt"
}
# A crash is worth one warning, not a failed doctor, and a loop stays readable.
test_doctor_crashes_are_one_warning_and_the_list_is_capped() {
  _load
  for i in $(seq 1 12); do _crash "run$i" segv.txt "$((i * 60))"; done
  _doctor_crashes >"$HOME/out" 2>&1
  out="$(cat "$HOME/out")"
  assert_eq "$_DOC_WARN" 1
  assert_eq "$_DOC_FAIL" 0
  assert_contains "$out" "shell crashes: 12 in the last 7 days"
  assert_contains "$out" "and 2 older"
  assert_eq "$(grep -c 'Segmentation fault' <<<"$out")" 10
}
# runit: no bus and no elogind linked means no login at all.
test_doctor_checks_the_runit_services() {
  _load; export VITRUM_NIRI_BIN="$HOME/nope" INIT_BACKEND=runit VITRUM_ROOTFS="$HOME/rootfs"
  mkdir -p "$VITRUM_ROOTFS/etc/runit/runsvdir/default"
  ln -s /etc/sv/dbus "$VITRUM_ROOTFS/etc/runit/runsvdir/default/dbus"
  source "$VITRUM_DIR/lib/backend/init-runit.sh"
  out="$(stage_doctor 2>&1)" || true
  assert_contains "$out" "runit: dbus"
  assert_contains "$out" "runit: elogind — not enabled"
}
