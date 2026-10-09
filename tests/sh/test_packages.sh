# shellcheck shell=bash disable=SC1090,SC1091
_pk() { export PKG_BACKEND="$1"; source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"; }

test_packages_for_portage_skips_dash() {
  _pk portage
  out="$(packages_for required 2>"$HOME/err")"
  assert_contains "$out" "gui-apps/quickshell"
  ! grep -qx -- "-" <<<"$out"
  ! grep -q "bluez-utils" <<<"$out"
  assert_contains "$(cat "$HOME/err")" "bluez-utils is not packaged here"
}
test_packages_for_pacman_keeps_aur_prefix() {
  _pk pacman
  assert_contains "$(packages_for required 2>/dev/null)" "aur:matugen-bin"
}
test_optional_need_selected_only_when_asked() {
  _pk portage
  ! grep -q neovim <<<"$(packages_for required 2>/dev/null)"
  assert_contains "$(packages_for required nvim 2>/dev/null)" "app-editors/neovim"
}
test_portage_keywords_file_has_no_duplicates() {
  _pk portage
  kw="$(packages_portage_column keywords)"
  assert_eq "$(sort <<<"$kw" | uniq -d)" ""
  assert_contains "$kw" "gui-apps/quickshell ~amd64"
}
test_portage_env_marks_half_jobs() {
  _pk portage
  assert_contains "$(packages_portage_column env)" "net-libs/webkit-gtk vitrum-half-jobs.conf"
}
test_table_is_well_formed() {
  awk -F'\t' '!/^#/ && NF && NF!=7 {print "line "NR": "NF" columns"; bad=1} END{exit bad}' "$VITRUM_DIR/lib/packages.tsv"
}
test_every_row_has_a_name_somewhere() {
  awk -F'\t' '!/^#/ && NF && $2=="-" && $3=="-" {print "line "NR" has no package anywhere"; bad=1} END{exit bad}' "$VITRUM_DIR/lib/packages.tsv"
}
test_portage_unavailable_atoms_stop_before_emerge() {
  export PKG_BACKEND=portage INIT_BACKEND=openrc VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"
  source "$VITRUM_DIR/lib/backend/pkg-portage.sh"; source "$VITRUM_DIR/lib/backend/init-openrc.sh"
  source "$VITRUM_DIR/lib/stages/10-packages.sh"
  stub sudo '"$@"'; stub lspci; stub emerge 'echo "emerge $*" >> "$HOME/calls"'
  pkg_write_portage_files() { :; }; pkg_enable_overlays() { :; }
  # only guru atoms are unavailable
  stub portageq 'case "$*" in *quickshell*|*matugen*) exit 1;; *) echo x-1;; esac'
  out="$( (stage_packages) 2>&1 )" && { echo "should fail"; return 1; }
  assert_contains "$out" "gui-apps/quickshell"
  assert_contains "$out" "eselect repository enable"
  [[ ! -e "$HOME/calls" ]]
}

test_pacman_gets_base_devel() {
  _pk pacman
  assert_contains "$(packages_for required 2>/dev/null)" "base-devel"
  _pk portage
  ! grep -q "base-devel" <<<"$(packages_for required 2>/dev/null)"
}

# On some systems a failed --keep-going batch stops the resume on unrelated
# dependencies, so one unfetchable package left everything after it unbuilt.
test_portage_failed_batch_falls_back_to_one_by_one() {
  export PKG_BACKEND=portage VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  mkdir -p "$VITRUM_ROOTFS/var/db/pkg"
  stub sudo '"$@"'
  # The batch fails; alone, a/one and c/three install and b/two does not.
  stub emerge 'echo "emerge $*" >> "$HOME/calls"
    n=0; for a; do case "$a" in -*) ;; *) n=$((n+1)); last="$a";; esac; done
    [ "$n" -gt 1 ] && exit 1
    case "$last" in b/two) exit 1;; esac
    mkdir -p "$VITRUM_ROOTFS/var/db/pkg/$last-1"; exit 0'
  out="$( (pkg_install a/one b/two c/three) 2>&1 )" && { echo "should fail: b/two did not install"; return 1; }
  assert_contains "$out" "b/two"
  ! grep -q "a/one\|c/three" <<<"$(grep -i "not installed" <<<"$out")"
  [[ -d "$VITRUM_ROOTFS/var/db/pkg/a/one-1" && -d "$VITRUM_ROOTFS/var/db/pkg/c/three-1" ]]
}
# A USE flag of ours on an installed package that lacks it: that package is rebuilt.
test_portage_rebuilds_for_missing_use() {
  export PKG_BACKEND=portage VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  mkdir -p "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8"; echo "sound-server" > "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8/USE"
  echo "+sound-server gstreamer gstreamer-only" > "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8/IUSE"
  _emerge() { echo "emerge $*" >> "$HOME/calls"; }
  pkg_apply_use >/dev/null 2>&1
  assert_contains "$(cat "$HOME/calls")" "--changed-use"
  assert_contains "$(cat "$HOME/calls")" "media-video/pipewire"
}
test_portage_no_rebuild_when_use_present() {
  export PKG_BACKEND=portage VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  mkdir -p "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8"; echo "gstreamer sound-server" > "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8/USE"
  echo "+sound-server gstreamer" > "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8/IUSE"
  _emerge() { echo "emerge $*" >> "$HOME/calls"; }
  pkg_apply_use >/dev/null 2>&1
  ! grep -q "media-video/pipewire" "$HOME/calls" 2>/dev/null
}
# A similar flag is not the flag (gstreamer-only is not gstreamer), and a flag
# the installed version does not have never triggers a rebuild.
test_portage_use_match_is_exact() {
  export PKG_BACKEND=portage VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  mkdir -p "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8"; echo "gstreamer-only" > "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8/USE"
  echo "gstreamer gstreamer-only" > "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8/IUSE"
  _emerge() { echo "emerge $*" >> "$HOME/calls"; }
  pkg_apply_use >/dev/null 2>&1
  assert_contains "$(cat "$HOME/calls")" "media-video/pipewire"
}
test_portage_use_absent_from_iuse_is_skipped() {
  export PKG_BACKEND=portage VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  mkdir -p "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8"; echo "" > "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8/USE"
  echo "jack-sdk" > "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8/IUSE"
  _emerge() { echo "emerge $*" >> "$HOME/calls"; }
  pkg_apply_use >/dev/null 2>&1
  ! grep -q "media-video/pipewire" "$HOME/calls" 2>/dev/null
}
test_portage_failed_rebuild_warns_and_goes_on() {
  export PKG_BACKEND=portage VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  mkdir -p "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8"; echo "" > "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8/USE"
  echo "gstreamer" > "$VITRUM_ROOTFS/var/db/pkg/media-video/pipewire-1.6.8/IUSE"
  _emerge() { return 1; }
  out="$(set -e; pkg_apply_use 2>&1; echo after)"
  assert_contains "$out" "could not rebuild"
  assert_contains "$out" "after"
}
# "category/*" in the USE list covers every installed package of the category,
# and the rebuild names each one (emerge does not take "dev-qt/*").
test_portage_use_wildcard_rebuilds_each_package_by_name() {
  export PKG_BACKEND=portage VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"; source "$VITRUM_DIR/lib/backend/pkg-portage.sh"
  _USE_DEPS=("dev-qt/* opengl")
  d="$VITRUM_ROOTFS/var/db/pkg/dev-qt"
  mkdir -p "$d/qtbase-6.11.2-r2" "$d/qtsvg-6.11.2" "$d/qttranslations-6.11.2"
  echo "opengl" > "$d/qtbase-6.11.2-r2/IUSE"; echo "" > "$d/qtbase-6.11.2-r2/USE"
  echo "opengl" > "$d/qtsvg-6.11.2/IUSE";     echo "opengl" > "$d/qtsvg-6.11.2/USE"
  echo "" > "$d/qttranslations-6.11.2/IUSE";  echo "" > "$d/qttranslations-6.11.2/USE"
  _emerge() { echo "emerge $*" >> "$HOME/calls"; }
  pkg_apply_use >/dev/null 2>&1
  calls="$(cat "$HOME/calls")"
  assert_contains "$calls" " dev-qt/qtbase"
  ! grep -q "qtsvg\|qttranslations\|\*" <<<"$calls"
}
test_portage_use_has_the_dependency_flags() {
  export PKG_BACKEND=portage
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"
  use="$(packages_portage_column use)"
  assert_contains "$use" "dev-qt/* opengl vulkan wayland X qml icu"
  assert_contains "$use" "media-libs/libcanberra alsa"
  assert_contains "$use" "x11-libs/gtk+ wayland"           # Flutter apps (LocalSend) need GDK's Wayland backend
  assert_contains "$use" "gui-libs/gtk wayland"
  assert_contains "$use" "kde-frameworks/* qml X wayland"   # kguiaddons: KDE Connect's clipboard sync
  assert_contains "$use" "media-sound/cava pipewire"          # the player's visualizer reads PipeWire
  assert_contains "$use" "media-video/pipewire gstreamer sound-server pipewire-alsa bluetooth"   # pipewire-pulse, ALSA apps, headsets
}
# Installed packages are rebuilt with vitrum's USE before anything new is built:
# the new ones link against them (quickshell against a qtdeclarative with opengl).
test_portage_use_rebuild_comes_before_install() {
  export PKG_BACKEND=portage INIT_BACKEND=openrc VITRUM_ROOTFS="$HOME/rootfs"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"
  source "$VITRUM_DIR/lib/backend/pkg-portage.sh"; source "$VITRUM_DIR/lib/backend/init-openrc.sh"
  source "$VITRUM_DIR/lib/stages/10-packages.sh"
  stub sudo '"$@"'; stub lspci; stub portageq 'echo x-1'
  pkg_prepare() { :; }; svc_enable_system() { :; }
  pkg_apply_use() { echo apply_use >> "$HOME/calls"; }
  pkg_install() { echo install >> "$HOME/calls"; }
  stage_packages >/dev/null 2>&1
  assert_eq "$(head -2 "$HOME/calls" | tr '\n' ' ')" "apply_use install "
}
