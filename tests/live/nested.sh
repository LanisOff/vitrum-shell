#!/usr/bin/env bash
# Run the repo's shell inside a nested niri on terpinator and take screenshots.
#   tests/live/nested.sh <outdir> [step...]
# Steps:  sleep:<s>   ipc:<target> <fn> [args]   niri:<action args>   spawn:<cmd>
#         shot:<name>  settings:<json> (test HOME's settings.json)
#         app:<name> [pane]   start apps/<name> in the test HOME (log: app-<name>.log)
#         appipc:<name> <target> <fn> [args]   IPC into a running app (settings pane keyboard)
#         run:<cmd>  bg:<cmd>   a command inside the nested session (its WAYLAND_DISPLAY, NIRI_SOCKET)
#         waitwin:<app_id>   until that window exists and has the focus (30 s at most)
#         click:<x> <y> [button]   wclick:<app_id> <x> <y> [button]   move:<x> <y>   scroll:<steps>
#             output pixels (as in shot:) / pixels inside the window (as in winshot:)
#         drag:<x1> <y1> <x2> <y2> [<x> <y> | shot=<name>]…   wdrag:<app_id> <x1> <y1> …  (shot= mid-drag)
#             press, glide through the points with the button held, (shot,) let go (host/vptr.c)
#         type:<text>   key:<combo> (Return, ctrl+a, shift+Tab)   — a virtual keyboard (wtype)
#         winshot:<app_id> <name>   just that window     dump:<path> [name]   a file (~ = test HOME) into <outdir>
# The nested session gets its own HOME (copy of the real vitrum niri config and
# palette) and a test wallpaper surface (tests/live/wall), so glass has
# something to show. Screenshots come from niri itself — only the nested
# output, never the host desktop. Results: <outdir>/*.png, layers.txt, shell.log
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
host="${VITRUM_HOST:-lanis@192.168.200.12}"
out="${1:?outdir}"; shift
# NESTED_DIR: the session's folder on the host (one per concurrent session).
N="${NESTED_DIR:-/tmp/vitrum-nested}"
mkdir -p "$out"
# Remote commands go to bash on stdin: the login shell there may be fish.
echo "mkdir -p $N/shell $N/wall" | ssh "$host" bash -s || exit 1
rsync -a --delete shell/ "$host:$N/shell/" || exit 1
rsync -a tests/live/wall/ "$host:$N/wall/" || exit 1
rsync -a tests/live/host/ "$host:$N/host/" || exit 1      # the headless test host
rsync -a tests/live/fake-mpris.py "$host:$N/" || exit 1  # a pretend player (run:python3 $N/fake-mpris.py …)
rsync -a --delete apps/ "$host:$N/apps/" || exit 1      # links resolve against ../../shell
rsync -a --delete tools/ "$host:$N/tools/" || exit 1     # vitrum-theme from the repo
steps="$(printf '%s\n' "$@")"
# NESTED_SHELL_ENV: extra VAR=value words for the shell's environment (e.g. VITRUM_NIRI=/bin/false).
# NESTED_TIMEOUT: seconds the nested niri lives (default 180).
# NESTED_DBUS=1: a private D-Bus for the nested session, niri's interfaces on it.
# NESTED_NIRI: path (on the host) of another niri binary for the nested session.
# NESTED_SETTINGS: settings.json for the nested session, applied before it starts.
# NESTED_WALL: the test wallpaper (a path on the host; default: its first jpg in ~/Pictures/Wallpapers).
{ printf 'STEPS=%q\nSHELL_ENV=%q\nNESTED_TIMEOUT=%q\nNESTED_DBUS=%q\nNESTED_NIRI=%q\nNESTED_RUST_LOG=%q\nNESTED_SETTINGS=%q\n' "$steps" "${NESTED_SHELL_ENV:-}" "${NESTED_TIMEOUT:-180}" "${NESTED_DBUS:-0}" "${NESTED_NIRI:-}" "${NESTED_RUST_LOG:-}" "${NESTED_SETTINGS:-}"; printf 'NESTED_HOST=%q\nNESTED_WLR_RENDERER=%q\nNESTED_WALL=%q\nNESTED_DIR=%q\n' "${NESTED_HOST:-headless}" "${NESTED_WLR_RENDERER:-gles2}" "${NESTED_WALL:-}" "$N"; cat tests/live/nested-remote.sh; } \
  | ssh "$host" bash -s
rsync -a "$host:$N/shots/" "$out/" 2>/dev/null
rsync -a "$host:$N/layers.txt" "$host:$N/shell.log" "$host:$N/steps.log" "$host:$N/niri.log" "$host:$N/gsettings.log" "$out/" 2>/dev/null
rsync -a "$host:$N/app-*.log" "$out/" 2>/dev/null
ls "$out"
