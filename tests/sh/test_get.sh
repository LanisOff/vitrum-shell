# shellcheck shell=bash disable=SC1090,SC1091,SC2016
# get.sh: the one-line start. git, the installer and sudo are stubs.
_get_stubs() {
  stub git 'echo "$PWD git $*" >> "$HOME/calls"
if [[ "$1" == clone ]]; then
  dest="${@: -1}"; mkdir -p "$dest/.git"
  printf "#!/usr/bin/env bash\n%s\n" "echo \"\$*\" > \"\$HOME/ran\"; [[ -t 0 ]] && echo tty >> \"\$HOME/ran\" || echo notty >> \"\$HOME/ran\"" > "$dest/install.sh"
  chmod +x "$dest/install.sh"
fi'
}
_get_checkout() {
  mkdir -p "$1/.git"
  printf '#!/usr/bin/env bash\necho "$PWD $*" > "$HOME/ran"\n' > "$1/install.sh"; chmod +x "$1/install.sh"
}

test_existing_install_uses_its_checkout() {
  _get_stubs
  _get_checkout "$HOME/work/vitrum"
  mkdir -p "$XDG_DATA_HOME/vitrum"; echo "$HOME/work/vitrum" > "$XDG_DATA_HOME/vitrum/source"
  bash "$VITRUM_DIR/get.sh" --fresh
  assert_contains "$(cat "$HOME/calls")" "git -C $HOME/work/vitrum pull --ff-only"
  assert_contains "$(cat "$HOME/ran")" "--fresh"
  [[ ! -e "$XDG_DATA_HOME/vitrum-src" ]]
}

# Local changes in the checkout are not pulled over, as vitrum update would
# not: get.sh says so and installs from it as it is.
test_local_changes_are_not_pulled_over() {
  stub git 'echo "$PWD git $*" >> "$HOME/calls"; [[ "$*" == *status* ]] && echo " M lib/x.sh"; exit 0'
  local d
  for d in "$HOME/work/vitrum" "$XDG_DATA_HOME/vitrum-src"; do
    rm -rf "$HOME/calls" "$HOME/ran" "$XDG_DATA_HOME/vitrum"
    _get_checkout "$d"
    if [[ "$d" == "$HOME/work/vitrum" ]]; then
      mkdir -p "$XDG_DATA_HOME/vitrum"; echo "$d" > "$XDG_DATA_HOME/vitrum/source"
    fi
    local out; out="$(bash "$VITRUM_DIR/get.sh" --yes 2>&1)"
    assert_contains "$out" "$d has local changes" || return 1
    ! grep -q "pull" "$HOME/calls" || { echo "pulled over local changes in $d"; return 1; }
    assert_contains "$(cat "$HOME/ran")" "--yes" || return 1
  done
}

test_fresh_clones_beside_the_state() {
  _get_stubs
  bash "$VITRUM_DIR/get.sh" --yes
  assert_contains "$(cat "$HOME/calls")" "clone --depth 1 --branch main https://github.com/LanisOff/vitrum-shell $XDG_DATA_HOME/vitrum-src"
  assert_contains "$(cat "$HOME/ran")" "--yes"
}

test_second_run_pulls_the_clone() {
  _get_stubs
  _get_checkout "$XDG_DATA_HOME/vitrum-src"
  bash "$VITRUM_DIR/get.sh"
  assert_contains "$(cat "$HOME/calls")" "git -C $XDG_DATA_HOME/vitrum-src pull --ff-only"
}

test_a_failed_pull_goes_on() {
  stub git 'exit 1'
  _get_checkout "$XDG_DATA_HOME/vitrum-src"
  bash "$VITRUM_DIR/get.sh" --yes 2>/dev/null
  assert_contains "$(cat "$HOME/ran")" "--yes"
}

# _get_without_git <package manager>... — a PATH with no git at all, and the
# named managers as stubs. The sudo stub logs every command and makes git
# appear once a command installing it goes through; it fails the one command
# named in $HOME/sudo-fails, the way stale package lists would.
_get_without_git() {
  local bin="$HOME/bin" t
  mkdir -p "$bin"
  for t in bash env mkdir cat dirname head chmod awk; do ln -s "$(command -v "$t")" "$bin/$t"; done
  cat > "$bin/sudo" <<'STUB'
#!/usr/bin/env bash
echo "sudo $*" >> "$HOME/calls"
[[ -f "$HOME/sudo-fails" && "$*" == "$(cat "$HOME/sudo-fails")" ]] && exit 1
case " $* " in
  *" git "|*" dev-vcs/git ") printf '#!/usr/bin/env bash\nexit 0\n' > "$HOME/bin/git"; chmod +x "$HOME/bin/git" ;;
esac
exit 0
STUB
  chmod +x "$bin/sudo"
  for t in "$@"; do printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/$t"; chmod +x "$bin/$t"; done
  _get_checkout "$XDG_DATA_HOME/vitrum-src"
}

# A refresh alone would be a partial upgrade: git comes from the lists as they
# are, and no -Sy is ever run on its own.
test_installs_git_with_pacman() {
  _get_without_git pacman
  PATH="$HOME/bin" bash "$VITRUM_DIR/get.sh" >/dev/null
  assert_eq "$(cat "$HOME/calls")" "sudo pacman -S --needed --noconfirm git"
  [[ -x "$HOME/bin/git" ]]
}

# Lists too old (or missing) to find git: the whole system is upgraded with it.
test_pacman_with_stale_lists_upgrades_with_git() {
  _get_without_git pacman
  echo "pacman -S --needed --noconfirm git" > "$HOME/sudo-fails"
  PATH="$HOME/bin" bash "$VITRUM_DIR/get.sh" >/dev/null
  assert_eq "$(cat "$HOME/calls")" "$(printf 'sudo pacman -S --needed --noconfirm git\nsudo pacman -Syu --needed --noconfirm git')"
  ! grep -q -- "-Sy " "$HOME/calls" || { echo "a bare -Sy"; return 1; }
}

test_installs_git_with_emerge() {
  _get_without_git emerge
  PATH="$HOME/bin" bash "$VITRUM_DIR/get.sh" >/dev/null
  assert_eq "$(cat "$HOME/calls")" "sudo emerge --noreplace dev-vcs/git"
}

test_installs_git_with_dnf() {
  _get_without_git dnf
  PATH="$HOME/bin" bash "$VITRUM_DIR/get.sh" >/dev/null
  assert_eq "$(cat "$HOME/calls")" "sudo dnf install -y git"
}

# The index is synced (accepting the key on a first sync), then git.
test_installs_git_with_xbps() {
  _get_without_git xbps-install
  PATH="$HOME/bin" bash "$VITRUM_DIR/get.sh" >/dev/null
  assert_eq "$(cat "$HOME/calls")" "$(printf 'sudo xbps-install -Sy\nsudo xbps-install -y git')"
}

# xbps installs nothing while a newer xbps waits: that one goes first.
test_xbps_updates_itself_before_git() {
  _get_without_git xbps-install
  printf '#!/usr/bin/env bash\n[[ "$*" == -un ]] && echo "xbps-0.60.8_1 update x86_64 https://repo-default.voidlinux.org/current 1 2"\nexit 0\n' > "$HOME/bin/xbps-install"
  PATH="$HOME/bin" bash "$VITRUM_DIR/get.sh" >/dev/null
  assert_eq "$(cat "$HOME/calls")" "$(printf 'sudo xbps-install -Sy\nsudo xbps-install -uy xbps\nsudo xbps-install -y git')"
}

# An update waiting for another package is not xbps's own.
test_xbps_other_updates_do_not_update_xbps() {
  _get_without_git xbps-install
  printf '#!/usr/bin/env bash\n[[ "$*" == -un ]] && echo "xbps-triggers-0.130_1 update noarch https://repo-default.voidlinux.org/current 1 2"\nexit 0\n' > "$HOME/bin/xbps-install"
  PATH="$HOME/bin" bash "$VITRUM_DIR/get.sh" >/dev/null
  ! grep -q -- "-uy xbps" "$HOME/calls" || { cat "$HOME/calls"; return 1; }
}

test_no_git_and_no_package_manager_dies() {
  local bin="$HOME/bin" t out rc=0
  mkdir -p "$bin"
  for t in bash env mkdir cat dirname head chmod; do ln -s "$(command -v "$t")" "$bin/$t"; done
  out=$(PATH="$bin" bash "$VITRUM_DIR/get.sh" 2>&1) || rc=$?
  assert_eq "$rc" 1
  assert_contains "$out" "vitrum needs git; install it and run this again"
}

test_no_tty_still_runs() {
  if ! command -v setsid >/dev/null; then
    echo "SKIP: test_no_tty_still_runs needs setsid" >&2
    return 0
  fi
  _get_stubs
  _get_checkout "$XDG_DATA_HOME/vitrum-src"
  printf '#!/usr/bin/env bash\n[[ -t 0 ]] && echo tty > "$HOME/ran" || echo notty > "$HOME/ran"\n' > "$XDG_DATA_HOME/vitrum-src/install.sh"
  # setsid drops the controlling terminal; --wait makes it finish with the child.
  # A deadline loop bounds the run, as macOS has no timeout.
  local pid i rc=0
  setsid --wait bash "$VITRUM_DIR/get.sh" </dev/null >/dev/null 2>&1 &
  pid=$!
  for ((i = 0; i < 100; i++)); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid"; echo "get.sh hung without a tty"; return 1; fi
  wait "$pid" || rc=$?
  assert_eq "$rc" 0
  assert_eq "$(cat "$HOME/ran")" notty
}

# A minimal system (Void especially) may have no sudo: get.sh says how to get
# it with this system's package manager, rather than "sudo: command not found".
test_no_sudo_says_how_to_get_it() {
  local m want out rc
  for m in xbps-install:"xbps-install -Sy sudo" dnf:"dnf install sudo" pacman:"pacman -S sudo" emerge:"emerge app-admin/sudo"; do
    rm -rf "${HOME:?}/bin" "$HOME/calls"
    _get_without_git "${m%%:*}"
    rm "$HOME/bin/sudo"
    want="${m#*:}" rc=0
    out=$(PATH="$HOME/bin" bash "$VITRUM_DIR/get.sh" 2>&1) || rc=$?
    assert_eq "$rc" 1 || return 1
    assert_contains "$out" "vitrum needs sudo" || return 1
    assert_contains "$out" "As root, install it with: $want" || return 1
    assert_contains "$out" "usermod -aG wheel" || return 1
    [[ "$out" != *"command not found"* ]] || { echo "$out"; return 1; }
  done
}
