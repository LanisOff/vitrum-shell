# shellcheck shell=bash disable=SC1090,SC1091,SC2016,SC2031,SC2034,SC2329
# The prebuilt niri on Arch: the choice, the download, every way out of it and
# the workflow's script. curl, sha256sum, tar, ldd and niri itself are stubs,
# steered by files in $HOME/world.

_SUM_A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
_SUM_B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

_x86() { stub uname 'if [[ "${1:-}" == -m ]]; then echo x86_64; else echo Linux; fi'; }

# _world — an up-to-date Arch with an old niri, where everything would work.
_world() {
  PATH="$STUBS:$(dirname "$BASH"):/usr/bin:/bin:/usr/sbin:/sbin"
  export PKG_BACKEND=pacman INIT_BACKEND=systemd VITRUM_NIRI_SOURCE=prebuilt
  export VITRUM_NIRI_BIN="$HOME/bin/niri" BUILD_DIR="$HOME/build" CARGO_TARGET_DIR="$HOME/tgt"
  mkdir -p "$HOME/bin" "$HOME/world"
  _x86
  printf '#!/bin/sh\necho "niri old"\n' > "$VITRUM_NIRI_BIN"; chmod +x "$VITRUM_NIRI_BIN"
  # The one in the archive; it says when it is run, so a test can tell.
  cat > "$HOME/world/niri" <<'SH'
#!/bin/sh
echo "ran $*" >> "$HOME/calls"
case "$1" in
  --version) echo "niri 26.99 (prebuilt)"; exit "$(cat "$HOME/world/version_rc" 2>/dev/null || echo 0)" ;;
  validate)  exit "$(cat "$HOME/world/validate_rc" 2>/dev/null || echo 0)" ;;
esac
SH
  chmod +x "$HOME/world/niri"
  echo "$_SUM_A" > "$HOME/world/published_sum"
  echo "$_SUM_A" > "$HOME/world/real_sum"
  stub sudo '"$@"'
  stub git 'echo "git $*" >> "$HOME/calls"'
  # As on a system without Rust: pacman is what brings cargo.
  stub pacman 'echo "pacman $*" >> "$HOME/calls"
    case "$1" in
      -Syu) printf "#!/bin/sh\necho cargo >> \"\$HOME/calls\"; mkdir -p \"\$CARGO_TARGET_DIR/release\"; printf \"#!/bin/sh\\necho niri compiled\\n\" > \"\$CARGO_TARGET_DIR/release/niri\"; chmod +x \"\$CARGO_TARGET_DIR/release/niri\"\n" > "'"$STUBS"'/cargo"; chmod +x "'"$STUBS"'/cargo" ;;
      *) exit 1 ;;
    esac'
  stub curl 'for ((i = 1; i <= $#; i++)); do [[ "${!i}" == -o ]] && { j=$((i + 1)); out="${!j}"; }; done
    url="${!#}"; echo "curl $url" >> "$HOME/calls"
    rc="$(cat "$HOME/world/curl_rc" 2>/dev/null || echo 0)"
    (( rc == 0 )) || exit "$rc"
    case "$url" in
      *.sha256) printf "%s  name\n" "$(cat "$HOME/world/published_sum")" > "$out" ;;
      *) echo archive > "$out" ;;
    esac'
  stub sha256sum 'printf "%s  %s\n" "$(cat "$HOME/world/real_sum")" "$1"'
  stub tar 'echo "tar $*" >> "$HOME/calls"
    [[ ! -e "$HOME/world/tar_fails" ]] || exit 2
    while (( $# )); do [[ "$1" == -C ]] && dir="$2"; shift; done
    cp "$HOME/world/niri" "$dir/niri"'
  stub ldd 'cat "$HOME/world/ldd" 2>/dev/null; echo "	libc.so.6 => /usr/lib/libc.so.6"'
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"
  source "$VITRUM_DIR/lib/backend/pkg-pacman.sh"; source "$VITRUM_DIR/lib/stages/30-niri.sh"
}

_calls() { cat "$HOME/calls" 2>/dev/null || true; }

# The binary went in as a prebuilt one, and nothing was compiled for it.
_is_prebuilt() {
  assert_contains "$("$VITRUM_NIRI_BIN" --version)" "prebuilt"
  assert_eq "$(cat "$VITRUM_STATE/niri.rev")" "$(niri_stamp)"
  assert_eq "$(cat "$VITRUM_STATE/niri.source")" prebuilt
  ! grep -qE '^(git|cargo|pacman -Syu)' <<<"$(_calls)" || { _calls; return 1; }
  [[ ! -e "$BUILD_DIR/niri-prebuilt" ]] || { echo "scratch left behind"; return 1; }
}

# It fell back: the toolchain came in, it compiled, and it says so.
_is_compiled() {
  assert_contains "$("$VITRUM_NIRI_BIN" --version)" "compiled"
  assert_eq "$(cat "$VITRUM_STATE/niri.rev")" "$(niri_stamp)"
  assert_eq "$(cat "$VITRUM_STATE/niri.source")" compiled
  local c; c="$(_calls)"
  assert_contains "$c" "pacman -Syu --needed --noconfirm rust"
  assert_contains "$c" "cargo"
  [[ ! -e "$BUILD_DIR/niri-prebuilt" ]] || { echo "scratch left behind"; return 1; }
}

test_happy_path_installs_the_binary_and_compiles_nothing() {
  _world
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  _is_prebuilt
  local c; c="$(_calls)"
  assert_contains "$c" "curl https://github.com/LanisOff/vitrum-shell/releases/download/$(niri_release_tag)/$(niri_release_asset).sha256"
  assert_contains "$c" "curl https://github.com/LanisOff/vitrum-shell/releases/download/$(niri_release_tag)/$(niri_release_asset)"$'\n'
  assert_contains "$c" "ran validate -c"
  [[ "$out" != *"not used"* ]] || { echo "$out"; return 1; }
}

test_no_asset_for_this_stamp_compiles() {
  _world; echo 22 > "$HOME/world/curl_rc"
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "prebuilt niri not used: there is no binary for this version — compiling instead"
  _is_compiled
  assert_eq "$(grep -c 'not used' <<<"$out")" 1
}

test_no_network_compiles() {
  _world; echo 6 > "$HOME/world/curl_rc"
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "the download failed (curl error 6)"
  _is_compiled
}

# Loud, and the file is neither unpacked nor run.
test_checksum_mismatch_is_loud_and_nothing_is_run() {
  _world; echo "$_SUM_B" > "$HOME/world/real_sum"
  # Where the final screen reads what went wrong from.
  export VITRUM_RUN_DIR="$HOME/run"; mkdir -p "$VITRUM_RUN_DIR"
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "CHECKSUM MISMATCH"
  [[ "$out" != *"not used"* ]] || { echo "said twice: $out"; return 1; }
  ! grep -qE '^(tar|ran)' <<<"$(_calls)" || { _calls; return 1; }
  _is_compiled
  assert_contains "$(cat "$VITRUM_RUN_DIR/errors")" "CHECKSUM MISMATCH"
}
test_a_checksum_file_that_is_no_checksum_counts_as_a_mismatch() {
  _world; echo '<html>' > "$HOME/world/published_sum"; echo '<html>' > "$HOME/world/real_sum"
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "CHECKSUM MISMATCH"
  ! grep -qE '^(tar|ran)' <<<"$(_calls)" || { _calls; return 1; }
}

test_unpack_failure_compiles() {
  _world; : > "$HOME/world/tar_fails"
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "the archive could not be unpacked"
  _is_compiled
}

test_missing_library_compiles_and_names_it() {
  _world; printf '\tlibdisplay-info.so.3 => not found\n' > "$HOME/world/ldd"
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "this system lacks libdisplay-info.so.3, which it was built against"
  ! grep -q '^ran' <<<"$(_calls)" || { _calls; return 1; }
  _is_compiled
}

test_older_glibc_compiles_and_names_it() {
  _world
  printf "./niri: /usr/lib/libc.so.6: version \`GLIBC_2.44' not found (required by ./niri)\n" > "$HOME/world/ldd"
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "this system lacks GLIBC_2.44, which it was built against"
  _is_compiled
}

test_a_binary_that_does_not_start_compiles() {
  _world; echo 127 > "$HOME/world/version_rc"
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "it does not start on this system"
  _is_compiled
}

test_a_binary_without_the_glass_compiles() {
  _world; echo 1 > "$HOME/world/validate_rc"
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "it does not accept the glass options"
  _is_compiled
  assert_contains "$(_calls)" "ran validate -c"
}

test_a_processor_below_the_baseline_compiles_without_downloading() {
  _world
  export VITRUM_ROOTFS="$HOME/rootfs"; mkdir -p "$VITRUM_ROOTFS/proc"
  echo 'flags : fpu sse2 ssse3' > "$VITRUM_ROOTFS/proc/cpuinfo"
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "this processor is too old for it"
  ! grep -q '^curl' <<<"$(_calls)" || { _calls; return 1; }
  _is_compiled
  echo 'flags : fpu sse2 ssse3 sse4_1 sse4_2' > "$VITRUM_ROOTFS/proc/cpuinfo"
  _niri_cpu_ok
}

# The checks all run on the download: what fails leaves the old niri in place
# until something better is there.
test_a_failed_check_leaves_the_old_niri_alone() {
  _world; echo 1 > "$HOME/world/validate_rc"
  local rc=0; (_niri_prebuilt) >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 1
  assert_contains "$("$VITRUM_NIRI_BIN" --version)" "old"
  [[ ! -e "$VITRUM_STATE/niri.rev" ]]
}

test_the_name_is_never_half_a_binary() {
  _world
  printf '#!/bin/sh\necho new\n' > "$HOME/new"; chmod +x "$HOME/new"
  stub sudo 'echo "sudo $*" >> "$HOME/calls"; "$@"'
  # What a running niri holds: the old file, by its descriptor.
  exec 9<"$VITRUM_NIRI_BIN"
  _niri_install "$HOME/new" prebuilt >/dev/null
  assert_contains "$(_calls)" "sudo install -m755 $HOME/new $VITRUM_NIRI_BIN.new"
  assert_contains "$(_calls)" "sudo mv -f $VITRUM_NIRI_BIN.new $VITRUM_NIRI_BIN"
  assert_eq "$("$VITRUM_NIRI_BIN")" new
  assert_contains "$(cat <&9)" "niri old"
  exec 9<&-
}

test_a_failed_install_leaves_the_old_niri_and_no_scraps() {
  _world
  printf 'x\n' > "$HOME/new"
  stub sudo 'if [[ "$1" == mv ]]; then exit 1; fi; "$@"'
  local out rc=0; out="$( (_niri_install "$HOME/new" prebuilt) 2>&1)" || rc=$?
  assert_eq "$rc" 1
  assert_contains "$out" "could not install"
  assert_contains "$("$VITRUM_NIRI_BIN" --version)" "old"
  [[ ! -e "$VITRUM_NIRI_BIN.new" && ! -e "$VITRUM_STATE/niri.rev" ]]
}

test_dry_run_downloads_nothing_and_changes_nothing() {
  _world; export DRY_RUN=1; DRY_RUN=1
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  assert_contains "$out" "would download https://github.com/LanisOff/vitrum-shell/releases/download/$(niri_release_tag)/$(niri_release_asset)"
  assert_contains "$out" "would install the binary"
  [[ -z "$(_calls)" ]] || { _calls; return 1; }
  [[ ! -e "$VITRUM_STATE/niri.rev" && ! -e "$BUILD_DIR/niri-prebuilt" ]]
  assert_contains "$("$VITRUM_NIRI_BIN" --version)" "old"
}

test_other_distributions_never_download() {
  _world
  PKG_BACKEND=dnf
  stub cargo 'mkdir -p "$CARGO_TARGET_DIR/release"; printf "#!/bin/sh\necho compiled\n" > "$CARGO_TARGET_DIR/release/niri"; chmod +x "$CARGO_TARGET_DIR/release/niri"'
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  ! grep -q '^curl' <<<"$(_calls)" || { _calls; return 1; }
  [[ "$out" != *prebuilt* ]] || { echo "$out"; return 1; }
  assert_eq "$(niri_installed_kind)" compiled
}

test_arch_on_another_processor_never_downloads() {
  _world
  stub uname 'echo aarch64'
  ! niri_prebuilt_offered
}

test_compile_chosen_on_arch_never_downloads() {
  _world; VITRUM_NIRI_SOURCE=compile
  stub cargo 'mkdir -p "$CARGO_TARGET_DIR/release"; printf "#!/bin/sh\necho compiled\n" > "$CARGO_TARGET_DIR/release/niri"; chmod +x "$CARGO_TARGET_DIR/release/niri"'
  local out; out="$(stage_niri 2>&1)" || { echo "$out"; return 1; }
  ! grep -qE '^(curl|pacman)' <<<"$(_calls)" || { _calls; return 1; }
  assert_eq "$(niri_installed_kind)" compiled
}

test_a_second_run_on_an_unchanged_system_does_nothing() {
  _world
  stage_niri >/dev/null 2>&1
  : > "$HOME/calls"
  local out; out="$(stage_niri 2>&1)"
  assert_contains "$out" "up to date"
  ! grep -qv '^ran' "$HOME/calls" || { _calls; return 1; }
}

test_compiled_and_up_to_date_stays_when_prebuilt_is_chosen() {
  _world
  niri_stamp > "$HOME/stamp"; mkdir -p "$VITRUM_STATE"; cp "$HOME/stamp" "$VITRUM_STATE/niri.rev"
  echo compiled > "$VITRUM_STATE/niri.source"
  ! niri_needs_build
}
test_compile_chosen_over_a_prebuilt_niri_rebuilds() {
  _world
  niri_stamp > "$HOME/stamp"; mkdir -p "$VITRUM_STATE"; cp "$HOME/stamp" "$VITRUM_STATE/niri.rev"
  echo prebuilt > "$VITRUM_STATE/niri.source"
  ! niri_needs_build
  VITRUM_NIRI_SOURCE=compile
  niri_needs_build
}
# A system upgrade can take a library away: the stamp alone does not say it runs.
test_a_niri_that_stopped_starting_is_not_up_to_date() {
  _world
  niri_stamp > "$HOME/stamp"; mkdir -p "$VITRUM_STATE"; cp "$HOME/stamp" "$VITRUM_STATE/niri.rev"
  printf '#!/bin/sh\nexit 127\n' > "$VITRUM_NIRI_BIN"
  niri_needs_build
}
test_nothing_is_installed_from_packages_when_the_toolchain_is_there() {
  _world; stub cargo 'exit 0'
  _niri_build_deps >/dev/null
  ! grep -q '^pacman -Syu' <<<"$(_calls)" || { _calls; return 1; }
}

# The tag and the asset are what the workflow publishes and the installer asks
# for. A + would be renamed by GitHub, and the download would be a 404.
test_release_names_have_no_plus() {
  _world
  local rev="$NIRI_REV" sum; sum="$(niri_stamp)"; sum="${sum#*+p}"
  assert_eq "$(niri_release_tag)" "niri-$rev-p$sum"
  assert_eq "$(niri_release_asset)" "niri-$rev-p$sum-arch-x86_64.tar.zst"
  [[ "$(niri_release_asset)" =~ ^[A-Za-z0-9._-]+$ ]]
}

# The stamp is computed on the runner and on the user's machine: one number
# for the same patches, whatever the system. Worked out once by hand.
test_stamp_is_the_same_on_every_machine() {
  _world
  NIRI_PATCHES="$HOME/p"; mkdir -p "$NIRI_PATCHES"
  printf 'first\n' > "$NIRI_PATCHES/0001-a.patch"; printf 'second\n' > "$NIRI_PATCHES/0002-b.patch"
  NIRI_REV=abc
  assert_eq "$(niri_stamp)" "abc+p2590796206"
}

# ------------------------------------------------------------- the choice -----

_choice() {
  export PKG_BACKEND=pacman
  _x86
  source "$VITRUM_DIR/lib/common.sh"
}

test_prebuilt_is_the_default_on_arch() {
  _choice; components_defaults
  assert_eq "$VITRUM_NIRI_SOURCE" prebuilt
  niri_prebuilt_wanted
}

test_the_choice_is_remembered() {
  _choice; components_flag --no-prebuilt-niri; components_defaults; components_save
  assert_contains "$(cat "$(components_file)")" '"niri_source": "compile"'
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$(components_file)"
  VITRUM_NIRI_SOURCE=""; components_load; components_defaults
  assert_eq "$VITRUM_NIRI_SOURCE" compile
  ! niri_prebuilt_wanted
}

test_a_flag_wins_over_the_remembered_choice() {
  _choice; components_flag --no-prebuilt-niri; components_defaults; components_save
  VITRUM_NIRI_SOURCE=""; components_flag --with-prebuilt-niri; components_load; components_defaults
  assert_eq "$VITRUM_NIRI_SOURCE" prebuilt
}

test_other_distributions_store_no_choice_and_are_not_asked() {
  export PKG_BACKEND=dnf; _x86
  source "$VITRUM_DIR/lib/common.sh"
  components_defaults; components_save
  ! grep -q niri_source "$(components_file)"
  ! niri_prebuilt_wanted
  [[ "$(components_new)" != *niri_source* ]]
}

test_an_update_asks_once_on_arch() {
  _choice
  COMPONENTS_KNOWN="$(component_ids | tr '\n' ' ')"
  assert_eq "$(components_new)" niri_source
  components_defaults; components_save
  COMPONENTS_PICKS_DECIDED=""; VITRUM_NIRI_SOURCE=""; components_load
  assert_eq "$(components_new)" ""
}

test_a_flag_is_an_answer_to_that() {
  _choice
  COMPONENTS_KNOWN="$(component_ids | tr '\n' ' ')"
  components_flag --no-prebuilt-niri
  assert_eq "$(components_new)" ""
}

test_a_value_this_version_does_not_know_takes_the_default() {
  _choice; components_defaults; components_save
  sed -i.bak 's/"niri_source": "prebuilt"/"niri_source": "smoke-signals"/' "$(components_file)"
  VITRUM_NIRI_SOURCE=""; components_load; components_defaults
  assert_eq "$VITRUM_NIRI_SOURCE" prebuilt
}

test_the_toolchain_is_needed_only_for_compiling() {
  _choice; components_defaults
  [[ " $(components_needs | tr '\n' ' ') " != *" niri-build "* ]]
  VITRUM_NIRI_SOURCE=compile
  [[ " $(components_needs | tr '\n' ' ') " == *" niri-build "* ]]
  VITRUM_NIRI_SOURCE=prebuilt PKG_BACKEND=dnf
  [[ " $(components_needs | tr '\n' ' ') " == *" niri-build "* ]]
}

# rust and clang are out of required; the AUR bootstrap still needs base-devel,
# and the libraries the binary links stay.
test_packages_split() {
  _choice; source "$VITRUM_DIR/lib/packages.sh"
  local req; req=" $(packages_for required 2>/dev/null | tr '\n' ' ') "
  [[ "$req" != *" rust@cargo "* && "$req" != *" clang@clang "* ]] || { echo "$req"; return 1; }
  local p
  for p in base-devel git libinput libdisplay-info seatd pipewire pango cairo mesa libxkbcommon; do
    assert_contains "$req" " $p "
  done
  assert_eq "$(packages_for niri-build 2>/dev/null | tr '\n' ' ')" "rust@cargo clang@clang "
  # Fedora and Void still get them, with everything else they compile with.
  export PKG_BACKEND=dnf
  assert_eq "$(packages_for niri-build 2>/dev/null | tr '\n' ' ')" "cargo@cargo clang@clang "
}

# ------------------------------------------------------------ the screens -----

_screens() {
  _choice
  source "$VITRUM_DIR/lib/screens/confirm.sh"
  components_defaults
  TUI_ROWS=40 TUI_COLS=100
}

_visible() { sed $'s/\e\\[[0-9;?]*[A-Za-z]//g' <<<"$1"; }

test_the_row_is_on_the_screen_on_arch_only() {
  _screens; choose_init
  [[ " ${CHOOSE_ROWS[*]} " == *" pick:niri_source "* ]]
  local out; out="$(_visible "$(choose_render)")"
  assert_contains "$out" "(•) prebuilt  ( ) compile, 20–40 min"
  PKG_BACKEND=dnf; choose_init
  [[ " ${CHOOSE_ROWS[*]} " != *niri_source* ]]
  [[ "$(_visible "$(choose_render)")" != *prebuilt* ]]
}

test_the_row_is_switched_like_any_pick() {
  _screens; choose_init
  local i
  for i in "${!CHOOSE_ROWS[@]}"; do [[ "${CHOOSE_ROWS[i]}" == pick:niri_source ]] && CHOOSE_CURSOR=$i; done
  choose_key right
  assert_eq "$VITRUM_NIRI_SOURCE" compile
  assert_contains "$(_visible "$(choose_render)")" "( ) prebuilt  (•) compile, 20–40 min"
  assert_contains "$(choose_hint niri_source)" "checked first"
  VITRUM_LANG=ru
  assert_contains "$(choose_hint niri_source)" "Готовый скачивается"
  assert_eq "$(choose_option_label prebuilt)" "готовый"
}

test_the_update_list_shows_only_what_it_is_given() {
  _screens; choose_init niri_source
  assert_eq "${CHOOSE_ROWS[*]}" pick:niri_source
  choose_init ocr
  [[ " ${CHOOSE_ROWS[*]} " != *niri_source* && " ${CHOOSE_ROWS[*]} " != *pick:terminal* ]]
}

# The choice comes after preflight_facts, and both ways round must show.
test_the_disk_row_follows_the_choice() {
  _screens
  FACT_FREE_MB=500 FACT_NIRI_BUILD=1
  confirm_init
  [[ " ${CONFIRM_TOGGLES[*]:-} " != *ACCEPT_LOW_DISK* ]]
  VITRUM_NIRI_SOURCE=compile
  confirm_init
  [[ " ${CONFIRM_TOGGLES[*]:-} " == *ACCEPT_LOW_DISK* ]]
}

test_the_estimate_follows_the_choice() {
  _screens; source "$VITRUM_DIR/lib/progress.sh"
  niri_needs_build() { return 0; }
  assert_eq "$(progress_estimate niri)" 60
  VITRUM_NIRI_SOURCE=compile
  assert_eq "$(progress_estimate niri)" 600
  niri_needs_build() { return 1; }
  assert_eq "$(progress_estimate niri)" 5
  VITRUM_NIRI_SOURCE=prebuilt
  assert_eq "$(progress_estimate niri)" 5
}

test_preflight_has_no_disk_warning_for_a_download() {
  _screens
  source "$VITRUM_DIR/lib/stages/00-preflight.sh"
  stub sudo 'exit 0'; stub lspci 'exit 0'
  stub df 'printf "Filesystem 1M-blocks Used Available Capacity Mounted\n/dev/x 100000 99500 500 99%% /\n"'
  INIT_BACKEND=systemd
  local out; out="$(stage_preflight 2>&1)" || { echo "$out"; return 1; }
  [[ "$out" != *"only 500MB free"* ]] || { echo "$out"; return 1; }
  VITRUM_NIRI_SOURCE=compile
  out="$(stage_preflight 2>&1)"
  assert_contains "$out" "only 500MB free"
}

# ------------------------------------------------------------ the workflow -----

_binary() {
  PATH="$STUBS:$(dirname "$BASH"):/usr/bin:/bin:/usr/sbin:/sbin"
  export BUILD_DIR="$HOME/build" GITHUB_SHA=feedface GITHUB_REPOSITORY=LanisOff/vitrum-shell
  stub pacman 'echo "pacman $*" >> "$HOME/calls"'
  stub git 'echo "git $*" >> "$HOME/calls"
    mkdir -p "$BUILD_DIR/niri"; echo GPL > "$BUILD_DIR/niri/LICENSE"'
  stub cargo 'echo "cargo RUSTFLAGS=$RUSTFLAGS $*" >> "$HOME/calls"
    if [[ "$1" == vendor ]]; then
      mkdir -p vendor/serde; printf "[source.vendored-sources]\ndirectory = \"vendor\"\n"
    else
      mkdir -p target/release; printf "#!/bin/sh\necho niri\n" > target/release/niri; chmod +x target/release/niri
    fi'
  stub ldd 'exit 0'
  stub zstd 'cat'
  stub tar 'echo "tar $*" >> "$HOME/calls"
    while (( $# )); do [[ "$1" == -cf ]] && out="$2"; shift; done
    echo archive > "$out"'
  stub sha256sum "printf '%s  %s\n' $_SUM_A \"\$1\""
}

test_binary_deps_come_from_the_table() {
  _binary
  "$VITRUM_DIR/tools/niri-binary" deps
  local c; c="$(_calls)"
  assert_contains "$c" "pacman -Syu --noconfirm --needed"
  local p
  for p in base-devel " rust " " clang " " git " libinput libdisplay-info seatd pipewire pango cairo pixman mesa github-cli zstd; do
    assert_contains "$c " "$p"
  done
  [[ "$c" != *@* ]] || { echo "$c"; return 1; }
}

test_binary_build_is_a_baseline_build_of_the_same_stamp() {
  _binary
  local out; out="$("$VITRUM_DIR/tools/niri-binary" build 2>&1)" || { echo "$out"; return 1; }
  local c; c="$(grep -v vendor "$HOME/calls")"
  assert_contains "$c" "RUSTFLAGS=-C target-cpu=x86-64-v2"
  [[ "$c" != *native* ]] || { echo "$c"; return 1; }
  assert_contains "$c" "--release --locked"
  [[ "$c" != *--features* ]] || { echo "not the default features: $c"; return 1; }
  # A compile, and on every core of the runner.
  assert_contains "$c" "--jobs $(getconf _NPROCESSORS_ONLN)"
  ( source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/stages/30-niri.sh"
    [[ -s "$BUILD_DIR/niri-dist/$(niri_release_asset)" ]]
    assert_contains "$(cat "$BUILD_DIR/niri-dist/$(niri_release_asset).sha256")" "$(niri_release_asset)"
    assert_contains "$(cat "$BUILD_DIR/niri-dist/SOURCE")" "$NIRI_REV"
    assert_contains "$c" "niri LICENSE SOURCE" )
}

# The whole corresponding source, as an asset of its own with its own checksum:
# the patched tree and the crates, without the build's leftovers.
test_binary_build_packs_the_source_with_its_crates() {
  _binary
  local out; out="$("$VITRUM_DIR/tools/niri-binary" build 2>&1)" || { echo "$out"; return 1; }
  local name; name="$( source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/stages/30-niri.sh"; niri_release_tag )-source"
  [[ "$name.tar.zst" =~ ^[A-Za-z0-9._-]+$ ]]
  [[ -s "$BUILD_DIR/niri-dist/$name.tar.zst" ]]
  assert_contains "$(cat "$BUILD_DIR/niri-dist/$name.tar.zst.sha256")" "$name.tar.zst"
  # Never --offline: the build has not fetched every platform's crates.
  assert_contains "$(_calls)" "vendor --locked vendor"
  # It builds offline from what is in it.
  assert_contains "$(cat "$BUILD_DIR/niri/.cargo/config.toml")" "vendored-sources"
  local t; t="$(grep -- '--exclude=./target' "$HOME/calls")"
  assert_contains "$t" "--exclude=./.git"
  assert_contains "$t" "s,^\\.,$name,"
  assert_contains "$t" "-C $BUILD_DIR/niri ."
}

# The source comes after the checks: a binary that fails gets no release parts.
test_binary_that_fails_its_check_packs_no_source() {
  _binary
  stub ldd 'printf "\tlibx.so => not found\n"'
  "$VITRUM_DIR/tools/niri-binary" build >/dev/null 2>&1 || true
  ! grep -q 'vendor' "$HOME/calls" || { _calls; return 1; }
}

# A user of the binary never pays for the source.
test_the_installer_does_not_download_the_source() {
  _world
  stage_niri >/dev/null 2>&1
  [[ "$(_calls)" != *source.tar* ]] || { _calls; return 1; }
  ! grep -q 'source\.tar' "$VITRUM_DIR/lib/stages/30-niri.sh"
}

# The licence: where the corresponding source is, in the notes and the archive.
test_binary_notes_say_where_the_source_is() {
  _binary
  "$VITRUM_DIR/tools/niri-binary" build >/dev/null 2>&1
  local n; n="$(cat "$BUILD_DIR/niri-dist/SOURCE")"
  assert_contains "$n" "General Public License"
  assert_contains "$n" "https://github.com/YaLTeR/niri/tree/"
  assert_contains "$n" "/releases/download/niri-"
  assert_contains "$n" "-source.tar.zst"
  assert_contains "$n" "cargo build --release --locked --offline"
  assert_contains "$n" "https://github.com/LanisOff/vitrum-shell/tree/feedface/patches/niri"
  [[ -s "$BUILD_DIR/niri-pack/LICENSE" && -s "$BUILD_DIR/niri-pack/SOURCE" && -x "$BUILD_DIR/niri-pack/niri" ]]
}

test_binary_that_fails_its_check_is_not_packed() {
  _binary
  stub ldd 'printf "\tlibx.so => not found\n"'
  local out rc=0; out="$("$VITRUM_DIR/tools/niri-binary" build 2>&1)" || rc=$?
  assert_eq "$rc" 1
  assert_contains "$out" "fails its own check"
  ! grep -q '^tar' <<<"$(_calls)" || { _calls; return 1; }
}

test_binary_publish_creates_a_prerelease() {
  _binary
  "$VITRUM_DIR/tools/niri-binary" build >/dev/null 2>&1
  stub gh 'echo "gh $*" >> "$HOME/calls"; [[ "$2" != view ]]'
  "$VITRUM_DIR/tools/niri-binary" publish
  local c; c="$(grep '^gh release create' "$HOME/calls")"
  assert_contains "$c" "--prerelease"
  assert_contains "$c" "--latest=false"
  assert_contains "$c" "--target feedface"
  assert_contains "$c" "--notes-file"
  assert_contains "$c" "-arch-x86_64.tar.zst.sha256"
  assert_contains "$c" "-source.tar.zst "
  assert_contains "$c" "-source.tar.zst.sha256"
  ! grep -q 'clobber' "$HOME/calls"
}

test_binary_publish_replaces_the_assets_of_a_rebuild() {
  _binary
  "$VITRUM_DIR/tools/niri-binary" build >/dev/null 2>&1
  stub gh 'echo "gh $*" >> "$HOME/calls"'
  "$VITRUM_DIR/tools/niri-binary" publish
  assert_contains "$(grep '^gh release upload' "$HOME/calls")" "--clobber"
  assert_contains "$(grep '^gh release upload' "$HOME/calls")" "-source.tar.zst.sha256"
  grep -q '^gh release edit' "$HOME/calls"
  ! grep -q '^gh release create' "$HOME/calls"
}

test_binary_published_looks_for_this_stamp() {
  _binary
  local asset source
  asset="$( source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/stages/30-niri.sh"; niri_release_asset )"
  source="${asset%-arch-x86_64.tar.zst}-source.tar.zst"
  stub gh "printf '%s\n' '$asset' '$asset.sha256' '$source' '$source.sha256'"
  "$VITRUM_DIR/tools/niri-binary" published
  # A release without the source is not done yet.
  stub gh "printf '%s\n' '$asset' '$asset.sha256'"
  ! "$VITRUM_DIR/tools/niri-binary" published
  stub gh "printf '%s\n' 'niri-other-arch-x86_64.tar.zst.sha256'"
  ! "$VITRUM_DIR/tools/niri-binary" published
  stub gh 'exit 1'
  ! "$VITRUM_DIR/tools/niri-binary" published
}

test_workflow_triggers_and_container() {
  local f="$VITRUM_DIR/.github/workflows/niri-binary.yml" y
  y="$(cat "$f")"
  assert_contains "$y" "patches/niri/**"
  assert_contains "$y" "lib/stages/30-niri.sh"
  assert_contains "$y" "workflow_dispatch"
  assert_contains "$y" "cron:"
  assert_contains "$y" "container: archlinux:latest"
  assert_contains "$y" "contents: write"
  if command -v actionlint >/dev/null 2>&1; then actionlint "$f"; fi
}
