#!/usr/bin/env bash
# The whole shell, live, on terpinator (run from the Mac):
#   tests/live/shell-smoke.sh [outdir]
#
#   1. rsync the repo and run `./install.sh --only shell` there; the installed
#      copy must match the repo's shell/
#   2. a nested niri with the shell: every surface opened through IPC,
#      one screenshot each
#   3. asserts: one bar and one dock, the overlay surfaces mapped, a shell log
#      with no QML errors
#   4. once more with niri hidden from the shell (VITRUM_NIRI=/bin/false): it
#      must still load cleanly
#
# Screenshots land in <outdir> (default tests/live/out/shell-smoke);
# look at every one. Waits are long: the nested output is hidden on the host and
# gets few frames, so anything animated or freshly mapped takes seconds to show.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
host="${VITRUM_HOST:-lanis@192.168.200.12}"
out="${1:-tests/live/out/shell-smoke}"
fail=0
# Remote commands go to bash on stdin: the login shell there may be fish.
rsh() { ssh "$host" bash -s; }
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=1; }

echo "== install"
rsync -a --delete --exclude .git --filter=':- .gitignore' ./ "$host:vitrum-src/" || exit 1
if rsh <<<'cd ~/vitrum-src && ./install.sh --only shell --yes </dev/null' > /tmp/vitrum-smoke-install.log 2>&1; then ok "install.sh --only shell"
else bad "install.sh --only shell (see /tmp/vitrum-smoke-install.log)"; fi
if rsh <<<'diff -rq ~/vitrum-src/shell ~/.config/quickshell/vitrum' >/dev/null; then ok "installed shell matches the repo"
else bad "installed shell differs from the repo"; fi

# QML problems Quickshell reports. DBus/network ones are the nested session's, not ours.
log_errors() {
  grep -E "ERROR|WARN" "$1" | grep -vE "DBus|Network will not work|Read of .* failed: File does not exist|Could not find an available backend" || true
}

echo "== surfaces"
rm -rf "$out"; mkdir -p "$out"
tests/live/nested.sh "$out" \
  "sleep:4" "spawn:kitty" "sleep:2" "spawn:dolphin" "sleep:8" "shot:00-desktop" \
  "ipc:launcher open" "sleep:1.5" "shot:01-launcher" "ipc:launcher close" "sleep:1" \
  "ipc:panel open calendar" "sleep:2" "shot:02-calendar" "ipc:panel close" "sleep:1" \
  "ipc:panel open control" "sleep:2" "shot:03-control" "ipc:panel close" "sleep:1" \
  "ipc:panel open resources" "sleep:2" "shot:04-resources" "ipc:panel close" "sleep:1" \
  "ipc:centre toggle" "sleep:2" "shot:05-centre" "ipc:centre toggle" "sleep:1" \
  "ipc:debug notify Smoke Hello world" "sleep:4" "shot:06-toast" \
  "ipc:osd display volume" "sleep:1" "shot:07-osd" "sleep:2" \
  "ipc:switcher next" "sleep:3" "shot:08-switcher" "ipc:switcher cancel" "sleep:1" \
  "ipc:power toggle" "sleep:1.5" "shot:09-power" "ipc:power toggle" "sleep:1" \
  "ipc:widgets add clock" "sleep:1" "ipc:widgets edit" "sleep:2" "shot:10-widgets" "ipc:widgets done" "sleep:1" \
  "niri:toggle-overview" "sleep:2" "shot:11-overview" "niri:toggle-overview" "sleep:1" \
  "ipc:capture open" "waitfile:/run/user/1000/vitrum-capture-wayland-2/frozen-*.png" "sleep:3" "shot:12-capture" "ipc:capture cancel" "sleep:1" \
  "ipc:lock lock" "sleep:7" "hostshot:13-lock" "ipc:debug state" > /dev/null

layers="$out/layers.txt"
n_bar=$(grep -c '"vitrum-bar"' "$layers" 2>/dev/null); n_dock=$(grep -c '"vitrum-dock-edge"' "$layers" 2>/dev/null)   # the dock itself unmaps while hidden
[[ "$n_bar" == 1 ]] && ok "one bar" || bad "bars: $n_bar"
[[ "$n_dock" == 1 ]] && ok "one dock" || bad "docks: $n_dock"
for ns in vitrum-launcher vitrum-overlay vitrum-osd vitrum-notifications vitrum-dialogs vitrum-widgets vitrum-capture; do
  grep -q "\"$ns\"" "$layers" && ok "$ns mapped" || bad "$ns missing"
done
errs="$(log_errors "$out/shell.log")"
[[ -z "$errs" ]] && ok "shell log clean" || { bad "shell log:"; printf '%s\n' "$errs" | head -20 | sed 's/^/          /'; }
for s in 00-desktop 01-launcher 02-calendar 03-control 04-resources 05-centre 06-toast 07-osd 08-switcher 09-power 10-widgets 11-overview 12-capture 13-lock; do
  [[ -s "$out/$s.png" ]] || bad "no screenshot $s"
done

echo "== without niri"
mkdir -p "$out/no-niri"
NESTED_SHELL_ENV="VITRUM_NIRI=/bin/false" tests/live/nested.sh "$out/no-niri" "sleep:6" "shot:no-niri" "ipc:launcher open" "sleep:1" "ipc:debug state" > /dev/null
errs="$(log_errors "$out/no-niri/shell.log")"
[[ -z "$errs" ]] && ok "shell log clean without niri" || { bad "shell log without niri:"; printf '%s\n' "$errs" | head -10 | sed 's/^/          /'; }
grep -q '"launcher":true' "$out/no-niri/steps.log" && ok "IPC answers without niri" || bad "IPC without niri"

echo
[[ $fail == 0 ]] && echo "smoke: PASS ($out)" || echo "smoke: FAIL ($out)"
exit $fail
