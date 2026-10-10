# shellcheck shell=bash disable=SC1090,SC1091
# prereqs_check: the start-of-run look for missing packages and fonts.
_pre() {
  export PKG_BACKEND=pacman INIT_BACKEND=systemd VITRUM_STATE="$HOME/state" BUILD_DIR="$HOME/build"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/packages.sh"
  source "$VITRUM_DIR/lib/assets.sh"; source "$VITRUM_DIR/lib/prereqs.sh"
  stub fc-cache 'echo fc-cache >> "$HOME/calls"'
  printf 'font\thttps://x/font.ttf\t%s\tfile\t%s\n' abc "$HOME/out/Font.ttf" > "$HOME/assets.tsv"
  export VITRUM_ASSETS_TABLE="$HOME/assets.tsv"
  CHECK_ONLY=0
  _package_needs() { echo required; }
  packages_for() { printf 'pkg-a\npkg-b\n'; }
  pkg_installed() { [[ "$1" == pkg-a ]] || [[ -e "$HOME/all-installed" ]]; }
  pkg_prepare() { echo prepare >> "$HOME/calls"; }
  pkg_apply_use() { :; }
  pkg_available() { :; }
  pkg_install() { echo "install $*" >> "$HOME/calls"; }
  fetch_asset() { echo "fetch $1" >> "$HOME/calls"; }
  should_run() { return 0; }
  sudo_keepalive() { echo keepalive >> "$HOME/calls"; }
}
_present() { mkdir -p "$HOME/out" "$VITRUM_STATE/assets"; echo f > "$HOME/out/Font.ttf"; echo abc > "$VITRUM_STATE/assets/font.sha256"; touch "$HOME/all-installed"; }

test_asset_missing_follows_dest_and_stamp() {
  _pre
  asset_missing font
  _present
  ! asset_missing font
  echo other > "$VITRUM_STATE/assets/font.sha256"
  asset_missing font
  echo abc > "$VITRUM_STATE/assets/font.sha256"; rm "$HOME/out/Font.ttf"
  asset_missing font
}
test_missing_package_installed_when_packages_stage_not_running() {
  _pre; _present; rm "$HOME/all-installed"
  should_run() { [[ "$1" != packages ]]; }
  prereqs_check
  assert_contains "$(cat "$HOME/calls")" "install pkg-b"
  assert_contains "$(cat "$HOME/calls")" "prepare"
}
test_missing_package_deferred_when_packages_stage_runs() {
  _pre; _present; rm "$HOME/all-installed"
  prereqs_check >"$HOME/out.txt" 2>&1; out="$(cat "$HOME/out.txt")"
  assert_contains "$out" "1 missing packages: pkg-b"
  assert_contains "$out" "packages stage installs them"
  assert_eq "${#VITRUM_WARNINGS[@]}" 0
  [[ ! -e "$HOME/calls" ]]
}
test_everything_present_prints_ok_only() {
  _pre; _present
  out="$(prereqs_check 2>&1)"
  assert_contains "$out" "packages and fonts: ok"
  [[ ! -e "$HOME/calls" ]]
}
test_missing_asset_fetched_when_fonts_stage_not_running() {
  _pre; _present; rm "$HOME/out/Font.ttf"
  should_run() { [[ "$1" != fonts ]]; }
  prereqs_check
  assert_contains "$(cat "$HOME/calls")" "fetch font"
  assert_contains "$(cat "$HOME/calls")" "fc-cache"
}
test_missing_asset_deferred_when_fonts_stage_runs() {
  _pre; _present; rm "$HOME/out/Font.ttf"
  out="$(prereqs_check 2>&1)"
  assert_contains "$out" "fonts stage fetches"
  [[ ! -e "$HOME/calls" ]]
}
test_dry_run_installs_and_fetches_nothing() {
  _pre; rm -f "$HOME/all-installed"
  DRY_RUN=1; should_run() { return 1; }
  out="$(prereqs_check 2>&1)"
  assert_contains "$out" "pkg-b"
  assert_contains "$out" "font"
  [[ ! -e "$HOME/calls" ]]
}
test_check_only_never_defers_to_stages() {
  _pre; _present; rm "$HOME/all-installed"
  CHECK_ONLY=1
  prereqs_check
  assert_contains "$(cat "$HOME/calls")" "install pkg-b"
}
test_unavailable_package_is_warned_not_fatal_and_rest_installed() {
  _pre; _present; rm "$HOME/all-installed"
  packages_for() { printf 'pkg-a\npkg-b\npkg-c\n'; }
  pkg_available() { [[ "$1" != pkg-c ]]; }
  should_run() { [[ "$1" != packages ]]; }
  rc=0; prereqs_check 2>"$HOME/err" || rc=$?
  assert_eq "$rc" 0
  assert_contains "$(cat "$HOME/calls")" "install pkg-b"
  ! grep -q "pkg-c" "$HOME/calls"
  assert_contains "$(cat "$HOME/err")" "not available in your repositories: pkg-c"
}
test_portage_unavailable_message_has_plain_dollar_r() {
  _pre; PKG_BACKEND=portage
  m="$(pkg_unavailable_message x/y)"
  assert_contains "$m" 'emaint sync -r $r; done'
  [[ "$m" != *'\$r'* ]]
}
test_install_sh_documents_and_parses_check() {
  grep -q -- '--check' "$VITRUM_DIR/install.sh"
  sed -n '2,30p' "$VITRUM_DIR/install.sh" | grep -q -- '--check'
}
