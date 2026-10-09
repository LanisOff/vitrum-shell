#!/usr/bin/env bash
# Builds a headless test host on terpinator: wlroots' tinywl, with toplevels
# sized to a 1080p output. Nested niri runs inside it, so tests need no
# visible session (and keep working while the real one is locked).
#   build.sh <dir>     → <dir>/tinywl
set -euo pipefail
dir="${1:?dir}"; mkdir -p "$dir"; cd "$dir"
[ -x tinywl ] && exit 0
wlr="$(pkg-config --list-all | awk '/^wlroots-/{print $1}' | sort -V | tail -1)"
ver="$(pkg-config --modversion "$wlr")"
curl -fsSL -o tinywl.c "https://gitlab.freedesktop.org/wlroots/wlroots/-/raw/$ver/tinywl/tinywl.c"
python3 - <<'PY'
s = open("tinywl.c").read()
s = s.replace("wlr_xdg_toplevel_set_size(toplevel->xdg_toplevel, 0, 0)",
              "wlr_xdg_toplevel_set_size(toplevel->xdg_toplevel, 1920, 1080)")
old = """	if (mode != NULL) {
		wlr_output_state_set_mode(&state, mode);
	}"""
assert old in s
s = s.replace(old, old + """ else {
		wlr_output_state_set_custom_mode(&state, 1920, 1080, 60000);
	}""")
open("tinywl.c", "w").write(s)
PY
wayland-scanner server-header "$(pkg-config --variable=pkgdatadir wayland-protocols)/stable/xdg-shell/xdg-shell.xml" xdg-shell-protocol.h
cc -O2 -DWLR_USE_UNSTABLE -I. tinywl.c -o tinywl $(pkg-config --cflags --libs "$wlr" wayland-server xkbcommon)
