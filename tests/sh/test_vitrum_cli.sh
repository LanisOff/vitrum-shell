# shellcheck shell=bash disable=SC1090,SC1091
# tools/vitrum: update, snapshots and rollback.
V="$VITRUM_DIR/tools/vitrum"

test_snapshot_and_rollback_restore_configs() {
  mkdir -p "$HOME/.config/vitrum" "$HOME/.config/kitty"
  echo '{"a":1}' > "$HOME/.config/vitrum/settings.json"; echo "font_size 11" > "$HOME/.config/kitty/kitty.conf"
  "$V" snapshot first >/dev/null
  echo '{"a":2}' > "$HOME/.config/vitrum/settings.json"; echo "font_size 14" > "$HOME/.config/kitty/kitty.conf"
  stub vitrum-theme; stub vitrum-shell
  "$V" rollback >/dev/null
  assert_eq "$(cat "$HOME/.config/vitrum/settings.json")" '{"a":1}'
  assert_eq "$(cat "$HOME/.config/kitty/kitty.conf")" "font_size 11"
}
test_rollback_keeps_a_snapshot_of_what_it_replaced() {
  mkdir -p "$HOME/.config/vitrum"; echo one > "$HOME/.config/vitrum/x"
  "$V" snapshot >/dev/null; echo two > "$HOME/.config/vitrum/x"
  stub vitrum-theme; stub vitrum-shell
  "$V" rollback >/dev/null
  assert_contains "$("$V" snapshots)" "before-rollback"
}
test_snapshots_are_pruned_to_ten() {
  mkdir -p "$HOME/.config/vitrum"; echo x > "$HOME/.config/vitrum/x"
  for i in $(seq 1 13); do VITRUM_SNAPSHOT_STAMP="2026010${i}-000000" "$V" snapshot >/dev/null; done
  assert_eq "$(ls "$XDG_DATA_HOME/vitrum/snapshots" | wc -l | tr -d ' ')" "10"
}
# The installer's bookkeeping stays out, and
# snapshots are readable by you alone.
test_snapshots_hold_configs_only_and_are_private() {
  mkdir -p "$XDG_DATA_HOME/vitrum" "$HOME/.config/vitrum"
  echo r > "$XDG_DATA_HOME/vitrum/niri.rev"; echo c > "$HOME/.config/vitrum/settings.json"
  "$V" snapshot >/dev/null
  f="$(ls "$XDG_DATA_HOME/vitrum/snapshots"/*.tar.gz | tail -1)"
  ! tar -tzf "$f" | grep -q "local/share"
  tar -tzf "$f" | grep -q "settings.json"
  [[ "$(stat -c %a "$f" 2>/dev/null || stat -f %Lp "$f")" == "600" ]]
  [[ "$(stat -c %a "$XDG_DATA_HOME/vitrum/snapshots" 2>/dev/null || stat -f %Lp "$XDG_DATA_HOME/vitrum/snapshots")" == "700" ]]
}
# A checkout with no origin (copied, not cloned) follows the vitrum repository.
_lonely() {
  mkdir -p "$XDG_DATA_HOME/vitrum"; git init -q -b main "$HOME/lonely"; cd "$HOME/lonely" || return 1
  git config user.email t@t; git config user.name t
  printf '#!/usr/bin/env bash\necho "install.sh $*" >> "$HOME/installs"\n' > install.sh; chmod +x install.sh; git add -A; git commit -qm one
  echo "$HOME/lonely" > "$XDG_DATA_HOME/vitrum/source"
}
test_update_unreachable_repository_says_so() {
  _lonely
  out="$(VITRUM_REPO="$HOME/nowhere" "$V" update 2>&1)" && return 1
  assert_contains "$out" "could not reach $HOME/nowhere"
  [[ ! -e "$HOME/installs" ]]
}
test_update_adds_the_vitrum_repository_as_origin() {
  _lonely
  git clone -q "$HOME/lonely" "$HOME/upstream"; cd "$HOME/upstream" && git config user.email t@t && git config user.name t
  echo more >> install.sh && git commit -qam two
  out="$(VITRUM_REPO="$HOME/upstream" "$V" update 2>&1)"
  assert_eq "$(git -C "$HOME/lonely" remote get-url origin)" "$HOME/upstream"
  assert_contains "$out" "two"
  assert_contains "$(cat "$HOME/installs")" "install.sh --update"
}
test_behind_counts_and_lists_new_commits() {
  _origin
  cd "$HOME/origin" && for n in two three; do echo $n >> install.sh; git commit -qam "$n"; done
  echo dirty >> "$HOME/src/install.sh"       # local edits do not stop a check
  out="$("$V" behind --json)"
  assert_contains "$out" '"behind": 2'
  assert_contains "$out" '"subject": "three"'
  assert_eq "$(git -C "$HOME/src" log --oneline | wc -l | tr -d ' ')" "1"   # nothing pulled
}
test_behind_up_to_date_and_unreachable() {
  _origin
  assert_contains "$("$V" behind --json)" '"behind": 0'
  _lonely
  out="$(VITRUM_REPO="$HOME/nowhere" "$V" behind --json)"
  assert_contains "$out" '"behind": 0'
  assert_contains "$out" '"error"'
}
test_rollback_without_snapshots_says_so() {
  out="$("$V" rollback 2>&1)" && return 1
  assert_contains "$out" "no snapshots"
}

# update: pulls the checkout the installer ran from, then reinstalls.
_origin() {
  git init -q "$HOME/origin"; cd "$HOME/origin" || return 1
  git config user.email t@t; git config user.name t
  printf '#!/usr/bin/env bash\necho "install.sh $*" >> "$HOME/installs"\n' > install.sh; chmod +x install.sh
  git add -A; git commit -qm one
  git clone -q "$HOME/origin" "$HOME/src"
  mkdir -p "$XDG_DATA_HOME/vitrum"; echo "$HOME/src" > "$XDG_DATA_HOME/vitrum/source"
}
test_update_pulls_and_reinstalls() {
  _origin
  cd "$HOME/origin" && echo more >> install.sh && git commit -qam two
  out="$("$V" update 2>&1)"
  assert_contains "$out" "two"
  assert_contains "$(cat "$HOME/installs")" "install.sh --update"
  # The installer decides whether to ask; update no longer says --yes for it.
  ! grep -q -- "--yes" "$HOME/installs" || { echo "update passed --yes"; return 1; }
  assert_contains "$(git -C "$HOME/src" log --oneline | head -1)" "two"
}
test_update_choose_passes_through() {
  _origin
  cd "$HOME/origin" && echo more >> install.sh && git commit -qam two
  "$V" update --choose >/dev/null 2>&1
  assert_contains "$(cat "$HOME/installs")" "install.sh --update --choose"
}
test_update_refuses_local_changes() {
  _origin
  echo dirty >> "$HOME/src/install.sh"
  out="$("$V" update 2>&1)" && return 1
  assert_contains "$out" "local changes"
  [[ ! -e "$HOME/installs" ]]
}
# _installed_at <checkout> — install.json naming the checkout's HEAD, as a
# complete install of it leaves it.
_installed_at() {
  printf '{\n  "version": "0.4.0",\n  "revision": "%s",\n  "complete": true\n}\n' \
    "$(git -C "$1" rev-parse HEAD)" > "$XDG_DATA_HOME/vitrum/install.json"
}
test_update_up_to_date_still_reinstalls_nothing() {
  _origin; _installed_at "$HOME/src"
  out="$("$V" update 2>&1)"
  assert_contains "$out" "up to date"
  # only the prerequisite check, never a full reinstall
  [[ ! -e "$HOME/installs" ]] || ! grep -qv -- "--check" "$HOME/installs"
}
test_update_without_git_reinstalls_the_copy() {
  mkdir -p "$HOME/copy" "$XDG_DATA_HOME/vitrum"
  printf '#!/usr/bin/env bash\necho "install.sh $*" >> "$HOME/installs"\n' > "$HOME/copy/install.sh"; chmod +x "$HOME/copy/install.sh"
  echo "$HOME/copy" > "$XDG_DATA_HOME/vitrum/source"
  out="$("$V" update 2>&1)"
  assert_contains "$out" "not a git checkout"
  assert_contains "$(cat "$HOME/installs")" "install.sh --update"
}
test_doctor_runs_the_installers_check() {
  mkdir -p "$HOME/copy" "$XDG_DATA_HOME/vitrum"
  printf '#!/usr/bin/env bash\necho "doctor $*"\n' > "$HOME/copy/install.sh"; chmod +x "$HOME/copy/install.sh"
  echo "$HOME/copy" > "$XDG_DATA_HOME/vitrum/source"
  assert_contains "$("$V" doctor 2>&1)" "doctor --doctor"
}
test_snapshot_unless_within_skips_a_recent_one() {
  mkdir -p "$HOME/.config/vitrum"; echo x > "$HOME/.config/vitrum/x"
  "$V" snapshot before-update --unless-within 600 >/dev/null
  out="$("$V" snapshot before-update --unless-within 600)"
  assert_contains "$out" "just made"
  assert_eq "$(ls "$XDG_DATA_HOME/vitrum/snapshots" | wc -l | tr -d ' ')" "1"
}
test_update_without_news_still_checks_prerequisites() {
  _lonely; _installed_at "$HOME/lonely"
  git clone -q "$HOME/lonely" "$HOME/upstream"
  out="$(VITRUM_REPO="$HOME/upstream" "$V" update 2>&1)"
  assert_contains "$out" "up to date"
  assert_contains "$(cat "$HOME/installs")" "install.sh --yes --check"
}

# Pulled earlier but never installed (Esc, Cancel, a skipped stage): nothing
# new to pull, and still the installer runs, as an update.
test_update_installs_a_pull_that_was_never_installed() {
  _origin
  printf '{\n  "version": "0.3.2",\n  "revision": "0000000000000000000000000000000000000000"\n}\n' > "$XDG_DATA_HOME/vitrum/install.json"
  out="$("$V" update 2>&1)"
  assert_contains "$out" "not finished"
  assert_contains "$(cat "$HOME/installs")" "install.sh --update"
  ! grep -q -- "--check" "$HOME/installs" || { echo "only the check"; return 1; }
  # Recorded by an older installer, without a revision: the same.
  rm -f "$HOME/installs"
  printf '{"version": "0.3.2"}\n' > "$XDG_DATA_HOME/vitrum/install.json"
  "$V" update >/dev/null 2>&1
  assert_contains "$(cat "$HOME/installs")" "install.sh --update"
}

# --choose with nothing new still brings the choice screen up.
test_update_choose_when_up_to_date() {
  _origin; _installed_at "$HOME/src"
  "$V" update --choose >/dev/null 2>&1
  assert_eq "$(cat "$HOME/installs")" "install.sh --update --choose"
}

# Only the tests name their snapshots.
test_snapshot_stamp_needs_vitrum_test() {
  mkdir -p "$HOME/.config/vitrum"; echo x > "$HOME/.config/vitrum/x"
  VITRUM_SNAPSHOT_STAMP=20260101-000000 env -u VITRUM_TEST "$V" snapshot >/dev/null
  [[ ! -e "$XDG_DATA_HOME/vitrum/snapshots/20260101-000000.tar.gz" ]] || { echo "the stamp was honoured outside the tests"; return 1; }
}
