#!/usr/bin/env bash
# Run the repo's shell inside a nested niri on terpinator and take screenshots.
#   tests/live/nested.sh <outdir> [step...]
# Steps:  sleep:<s>   ipc:<target> <fn> [args]   niri:<action args>   spawn:<cmd>
#         shot:<name>  settings:<json> (test HOME's settings.json)
#         app:<name> [pane]   start apps/<name> in the test HOME (log: app-<name>.log)
# The nested session gets its own HOME (copy of the real vitrum niri config and
# palette) and a test wallpaper surface (tests/live/wall), so glass has
# something to show. Screenshots come from niri itself — only the nested
# output, never the host desktop. Results: <outdir>/*.png, layers.txt, shell.log
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
host="${VITRUM_HOST:-lanis@192.168.200.12}"
out="${1:?outdir}"; shift
mkdir -p "$out"
# Remote commands go to bash on stdin: the login shell there may be fish.
echo 'mkdir -p /tmp/vitrum-nested/shell /tmp/vitrum-nested/wall' | ssh "$host" bash -s || exit 1
rsync -a --delete shell/ "$host:/tmp/vitrum-nested/shell/" || exit 1
rsync -a tests/live/wall/ "$host:/tmp/vitrum-nested/wall/" || exit 1
rsync -a tests/live/host/ "$host:/tmp/vitrum-nested/host/" || exit 1      # the headless test host
rsync -a tests/live/fake-mpris.py "$host:/tmp/vitrum-nested/" || exit 1  # a pretend player (run:python3 /tmp/vitrum-nested/fake-mpris.py …)
rsync -a --delete apps/ "$host:/tmp/vitrum-nested/apps/" || exit 1      # links resolve against ../../shell
rsync -a --delete tools/ "$host:/tmp/vitrum-nested/tools/" || exit 1     # vitrum-theme from the repo
steps="$(printf '%s\n' "$@")"
# NESTED_SHELL_ENV: extra VAR=value words for the shell's environment (e.g. VITRUM_NIRI=/bin/false).
# NESTED_TIMEOUT: seconds the nested niri lives (default 180).
# NESTED_DBUS=1: a private D-Bus for the nested session, niri's interfaces on it.
# NESTED_NIRI: path (on the host) of another niri binary for the nested session.
# NESTED_SETTINGS: settings.json for the nested session, applied before it starts.
{ printf 'STEPS=%q\nSHELL_ENV=%q\nNESTED_TIMEOUT=%q\nNESTED_DBUS=%q\nNESTED_NIRI=%q\nNESTED_RUST_LOG=%q\nNESTED_SETTINGS=%q\n' "$steps" "${NESTED_SHELL_ENV:-}" "${NESTED_TIMEOUT:-180}" "${NESTED_DBUS:-0}" "${NESTED_NIRI:-}" "${NESTED_RUST_LOG:-}" "${NESTED_SETTINGS:-}"; printf 'NESTED_HOST=%q\n' "${NESTED_HOST:-headless}"; cat tests/live/nested-remote.sh; } \
  | ssh "$host" bash -s
rsync -a "$host:/tmp/vitrum-nested/shots/" "$out/" 2>/dev/null
rsync -a "$host:/tmp/vitrum-nested/layers.txt" "$host:/tmp/vitrum-nested/shell.log" "$host:/tmp/vitrum-nested/steps.log" "$host:/tmp/vitrum-nested/niri.log" "$out/" 2>/dev/null
rsync -a "$host:/tmp/vitrum-nested/app-*.log" "$out/" 2>/dev/null
ls "$out"
