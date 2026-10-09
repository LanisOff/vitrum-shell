#!/usr/bin/env bash
# Does the shell load, and stay quiet? Starts it in a nested niri for a few
# seconds and prints every QML error or JS exception it logged. Exit 1 if any.
# lib/check-qml.py catches imports; this catches what only loading finds
# (duplicate properties, read-only assignments, redeclared identifiers…).
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
out="tests/live/out/load-check"
NESTED_TIMEOUT=20 tests/live/nested.sh "$out" 'sleep:7' >/dev/null 2>&1
bad="$(grep -a -E 'ERROR|TypeError|ReferenceError|Cannot assign|Unable to assign|is not a function|Binding loop' "$out/shell.log" | grep -v 'quickshell.network' || true)"
if [[ -n "$bad" ]]; then printf '%s\n' "$bad"; exit 1; fi
grep -aq "Configuration Loaded" "$out/shell.log" || { echo "the shell did not load"; tail -5 "$out/shell.log"; exit 1; }
echo "shell loads cleanly"
