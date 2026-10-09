#!/usr/bin/env bash
# Settings, Disk Utility and About, live on terpinator (run from the Mac):
#   tests/live/apps-smoke.sh [outdir]
#
#   1. rsync the repo; ./install.sh --only shell then --only apps; the
#      installed apps link to the installed shell and carry apps/common
#   2. a nested session: each app opened, Settings on every pane, Disk
#      Utility on the root partition (must say it does not change it);
#      one screenshot each, and no QML errors in any app's log
#
# Look at every screenshot.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
host="${VITRUM_HOST:-lanis@192.168.200.12}"
out="${1:-tests/live/out/apps-smoke}"
fail=0
# Remote commands go to bash on stdin: the login shell there may be fish.
rsh() { ssh "$host" bash -s; }
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=1; }

echo "== install"
rsync -a --delete --exclude .git --filter=':- .gitignore' ./ "$host:vitrum-src/" || exit 1
if rsh <<<'cd ~/vitrum-src && ./install.sh --only shell --yes </dev/null && PATH=$HOME/.vitrum-test/bin:$PATH ./install.sh --only apps --yes </dev/null' > /tmp/vitrum-apps-install.log 2>&1
then ok "install.sh --only shell, --only apps"; else bad "install (see /tmp/vitrum-apps-install.log)"; fi
check="$(rsh <<<'q=$HOME/.config/quickshell; for a in settings disks about; do
  [ -x "$HOME/.local/bin/vitrum-$a" ] || echo "no launcher vitrum-$a"
  [ -f "$HOME/.local/share/applications/vitrum-$a.desktop" ] || echo "no desktop entry vitrum-$a"
  for d in theme components services lib data; do [ "$(readlink "$q/vitrum-$a/$d")" = "$q/vitrum/$d" ] || echo "vitrum-$a/$d does not link to the shell"; done
  diff -rq ~/vitrum-src/apps/common "$q/vitrum-$a/common" >/dev/null || echo "vitrum-$a/common differs"
  (cd ~/vitrum-src/apps/$a && find . -type f) | while read -r f; do cmp -s ~/vitrum-src/apps/$a/$f "$q/vitrum-$a/$f" || echo "vitrum-$a/$f differs"; done
done')"
[[ -z "$check" ]] && ok "installed apps are complete and linked" || { bad "installed apps:"; printf '%s\n' "$check" | sed 's/^/          /'; }

errors() { grep -E "ERROR|WARN" "$1" 2>/dev/null | grep -vE "DBus|Network will not work|File does not exist|available backend" || true; }

echo "== apps"
rm -rf "$out"; mkdir -p "$out"
steps=("sleep:5" "app:settings appearance" "sleep:12" "niri:maximize-column" "sleep:4")
for p in appearance materials type wallpaper motion bar dock widgets notifications windows search capture sound network bluetooth displays keyboard power time advanced; do
  steps+=("appipc:settings settings pane $p" "sleep:3" "shot:settings-$p")
done
steps+=("appipc:settings settings current")
# A new window opens in a new column; the view needs time to scroll to it here.
steps+=("app:disks" "sleep:12" "niri:focus-column-last" "niri:maximize-column" "sleep:8" "shot:disks")
root_part="$(rsh <<<'s=$(findmnt -n -o SOURCE --target /); s=${s%%[*}; basename "$s"')"
steps+=("appipc:disks disks select $root_part" "sleep:3" "shot:disks-root" "appipc:disks disks sheet erase" "sleep:2" "shot:disks-root-sheet")
steps+=("app:about" "sleep:12" "niri:focus-column-last" "niri:maximize-column" "sleep:8" "shot:about")
NESTED_TIMEOUT=600 tests/live/nested.sh "$out" "${steps[@]}" > /dev/null

n=$(ls "$out"/settings-*.png 2>/dev/null | wc -l | tr -d ' ')
[[ "$n" == 20 ]] && ok "20 Settings panes" || bad "Settings panes shot: $n of 20"
for s in disks disks-root disks-root-sheet about; do [[ -s "$out/$s.png" ]] || bad "no screenshot $s"; done
grep -q "^advanced$" "$out/steps.log" && ok "Settings answers over IPC" || bad "Settings IPC"
for a in settings disks about; do
  e="$(errors "$out/app-$a.log")"
  [[ -f "$out/app-$a.log" && -z "$e" ]] && ok "$a log clean" || { bad "$a log:"; printf '%s\n' "$e" | head -10 | sed 's/^/          /'; }
done

echo
[[ $fail == 0 ]] && echo "apps smoke: PASS ($out)" || echo "apps smoke: FAIL ($out)"
exit $fail
