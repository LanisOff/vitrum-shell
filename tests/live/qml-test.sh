#!/usr/bin/env bash
# Run QML tests on a machine with Quickshell (terpinator), headless.
#   tests/live/qml-test.sh [host] [test...]     default host lanis@192.168.200.12, all tests/qml/*.qml
# Each test is a ShellRoot that prints lines "PASS <name>" / "FAIL <name>: <why>" and "DONE".
# It runs as the entry point of a copy of shell/, with HOME pointed at a temp dir
# (seeded from tests/qml/<test>.home/ if present).
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
host="${1:-lanis@192.168.200.12}"; shift || true
tests=("$@"); [[ ${#tests[@]} -eq 0 ]] && tests=(tests/qml/*.qml)
echo 'mkdir -p /tmp/vitrum-qmltest/shell /tmp/vitrum-qmltest/tests' | ssh "$host" bash -s || exit 1
rsync -a --delete shell/ "$host:/tmp/vitrum-qmltest/shell/" || exit 1
rsync -a --delete tests/qml/ "$host:/tmp/vitrum-qmltest/tests/" || exit 1
fail=0
for t in "${tests[@]}"; do
  name="$(basename "$t" .qml)"
  out="$(printf '%s\n' "set -u; T=/tmp/vitrum-qmltest; rm -rf \$T/run && cp -r \$T/shell \$T/run && cp \$T/tests/$name.qml \$T/run/shell.qml \
    && H=\$(mktemp -d) && { [ -d \$T/tests/$name.home ] && cp -r \$T/tests/$name.home/. \$H/ || true; } \
    && cd \$T/run && HOME=\$H XDG_CONFIG_HOME=\$H/.config XDG_DATA_HOME=\$H/.local/share PATH=/bin:/usr/bin QT_QPA_PLATFORM=offscreen timeout 25 qs -p \$T/run/shell.qml 2>&1" | ssh "$host" bash -s)"
  pass=$(grep -c ' PASS ' <<<"$out"); bad=$(grep -E ' FAIL |TypeError|ReferenceError|is not a type|is not installed|SyntaxError' <<<"$out")
  if [[ -n "$bad" || $(grep -c ' DONE' <<<"$out") -eq 0 ]]; then
    fail=1; printf 'FAIL %s\n%s\n' "$name" "$(grep -vE 'DEBUG.*(PASS)' <<<"$out" | tail -15)"
  else
    printf 'ok   %s (%s checks)\n' "$name" "$pass"
  fi
done
exit $fail
