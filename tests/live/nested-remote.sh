# Runs on terpinator (fed to bash -s by nested.sh). STEPS holds the steps, one per line.
set -u
export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1
# NESTED_DIR: this session's own folder, so several nested sessions can run at once.
N="${NESTED_DIR:-/tmp/vitrum-nested}"
H="$N/home"
[ -n "$N" ] || exit 1
C="$H/.config/vitrum/niri"     # the nested niri reads the test HOME's config, so settings → vitrum-theme → niri works
# NESTED_NIRI: another niri binary (a fresh build) for the nested session; it
# comes first in PATH there, so vitrum-theme probes it too.
BIN="$N/bin"; rm -rf "$BIN"; mkdir -p "$BIN"
[ -n "${NESTED_NIRI:-}" ] && ln -sf "$NESTED_NIRI" "$BIN/niri"
# vitrum-ipc (Settings → Keyboard's "Show", binds) must reach the nested shell,
# not the user's: the installed one asks for `qs -c vitrum` first.
printf '#!/bin/sh\nexec qs ipc --pid "$(pgrep -n -f "qs -p %s/shell/shell.qml")" call "$@"\n' "$N" > "$BIN/vitrum-ipc"; chmod +x "$BIN/vitrum-ipc"
# The nested session shares the user's session bus and tmux server (unless
# NESTED_DBUS=1): vitrum-theme's `gsettings set` (cursor, icon and GTK theme,
# light/dark) would change the user's real desktop, and its `tmux source-file`
# would load the test palette into their tmux. Reads pass; writes only go to
# $N/gsettings.log.
printf '#!/bin/sh\ncase "$1" in set|reset|reset-recursively) echo "gsettings $*" >> "%s/gsettings.log"; exit 0 ;; esac\nexec /usr/bin/gsettings "$@"\n' "$N" > "$BIN/gsettings"
printf '#!/bin/sh\necho "tmux $*" >> "%s/gsettings.log"; exit 1\n' "$N" > "$BIN/tmux"
chmod +x "$BIN/gsettings" "$BIN/tmux"
TPATH="$BIN:$N/tools:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
pkill -f "niri -c $C/config.kdl" 2>/dev/null; pkill -f "qs -p $N/" 2>/dev/null; sleep 0.5
rm -rf "$H" "$N/shots" "$N/steps.log" "$N/gsettings.log" "$N"/app-*.log
mkdir -p "$H/.config/vitrum" "$H/.local/share/vitrum" "$N/shots"
cp -r "$HOME/.config/vitrum/niri" "$C"
cp "$HOME/.local/share/vitrum/palette.json" "$H/.local/share/vitrum/" 2>/dev/null
# The bind catalogue (Settings → Keyboard lists it; vitrum-theme writes binds.kdl from it).
cp "$HOME/.config/vitrum/binds.json" "$H/.config/vitrum/" 2>/dev/null
# The user's fonts and icon themes (Phosphor, Bibata) live under the real XDG_DATA_HOME.
ln -s "$HOME/.local/share/fonts" "$H/.local/share/fonts"
ln -s "$HOME/.local/share/icons" "$H/.local/share/icons"
# NESTED_SETTINGS: settings.json for the test HOME, rendered before niri starts
# (a settings change mid-run reloads niri's config; the nested winit output is
# re-created then and its surfaces stop getting frames).
if [ -n "${NESTED_SETTINGS:-}" ]; then
  printf '%s\n' "$NESTED_SETTINGS" > "$H/.config/vitrum/settings.json"
  env HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" XDG_CACHE_HOME="$H/.cache" PATH="$TPATH" \
    vitrum-theme --quiet --no-color-scheme >> "$N/steps.log" 2>&1
fi
WALL="${NESTED_WALL:-$(ls "$HOME"/Pictures/Wallpapers/*.jpg 2>/dev/null | head -1)}"
ENVV="\"env\" \"VITRUM_TEST_WALL=$WALL\" \"HOME=$H\" \"XDG_CONFIG_HOME=$H/.config\" \"XDG_DATA_HOME=$H/.local/share\" \"PATH=$TPATH\""
{
  echo "spawn-at-startup $ENVV \"qs\" \"-p\" \"$N/wall/shell.qml\""
  echo "spawn-at-startup \"sh\" \"-c\" \"sleep 0.5; exec env HOME=$H XDG_CONFIG_HOME=$H/.config XDG_DATA_HOME=$H/.local/share PATH=$TPATH ${SHELL_ENV:-} qs -p $N/shell/shell.qml > $N/shell.log 2>&1\""
} > "$C/generated/session.kdl"
HS=$(ls -t "$XDG_RUNTIME_DIR"/niri.wayland-1.*.sock 2>/dev/null | head -1)   # the host session (the user's), if it is niri
# NESTED_HOST=headless (default): niri runs inside a headless tinywl, not in the
# user's session — nothing shows there, and a locked session cannot stall it.
# NESTED_HOST=session: inside the user's session (hostshot needs that).
HOSTWL=""
if [ "${NESTED_HOST:-headless}" = headless ]; then
  bash "$N/host/build.sh" "$HOME/.cache/vitrum-test-host" >> "$N/steps.log" 2>&1 \
    || echo "WARNING: no headless test host; nested niri runs hidden in the user's session and gets few frames" >> "$N/steps.log"
  # Only this session's own host: other sessions may be running theirs.
  [ -s "$N/host.pid" ] && kill "$(cat "$N/host.pid")" 2>/dev/null; rm -f "$N/hostwl" "$N/host.pid"
  # NESTED_WLR_RENDERER=pixman where there is no GPU (a container, a VM).
  ( WLR_BACKENDS=headless WLR_RENDERER="${NESTED_WLR_RENDERER:-gles2}" WLR_HEADLESS_OUTPUTS=1 timeout "$(( ${NESTED_TIMEOUT:-180} + 10 ))" \
      "$HOME/.cache/vitrum-test-host/tinywl" -s "echo \$WAYLAND_DISPLAY > $N/hostwl" > "$N/host.log" 2>&1 & echo $! > "$N/host.pid" )
  for _ in $(seq 50); do [ -s "$N/hostwl" ] && break; sleep 0.1; done
  HOSTWL=$(cat "$N/hostwl" 2>/dev/null)
fi
# A nested shell left locked by an earlier run would lock again at start (its
# marker survives): clear the nested displays' markers — never wayland-1's, the user's.
for m in "$XDG_RUNTIME_DIR"/vitrum-locked-wayland-*; do
  [ -e "$m" ] && [ "$m" != "$XDG_RUNTIME_DIR/vitrum-locked-wayland-1" ] && rm -f "$m"
done
# NESTED_DBUS=1: a private session bus for everything nested (niri, shell,
# portals), and niri publishing its D-Bus interfaces (screencast) on it.
if [ "${NESTED_DBUS:-0}" = 1 ]; then
  rm -f "$N/bus"; dbus-daemon --session --address="unix:path=$N/bus" --fork --print-pid > "$N/bus.pid"
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$N/bus"
  printf '\ndebug {\n    dbus-interfaces-in-non-session-instances\n}\n' >> "$C/config.kdl"
fi
[ -n "${NESTED_RUST_LOG:-}" ] && export RUST_LOG="$NESTED_RUST_LOG"
# PATH=TPATH: the nested niri's binds spawn vitrum-ipc, which must be the shim
# above (the nested shell), never the installed one (the user's shell).
( [ -n "$HOSTWL" ] && export WAYLAND_DISPLAY="$HOSTWL"; export PATH="$TPATH"; timeout "${NESTED_TIMEOUT:-180}" "${NESTED_NIRI:-niri}" -c "$C/config.kdl" > "$N/niri.log" 2>&1 & )
# The nested niri's socket: the one named after this session's own niri (its
# config lives in $N, so the pid is ours even with other sessions running).
S=""
for _ in $(seq 100); do
  NP=$(pgrep -n -f "^(/[^ ]*/)?niri -c $C/config.kdl")
  S=""; [ -n "$NP" ] && S=$(ls "$XDG_RUNTIME_DIR"/niri.wayland-*."$NP".sock 2>/dev/null | head -1)
  [ -n "$S" ] && [ "$S" != "$HS" ] && NIRI_SOCKET="$S" niri msg version >/dev/null 2>&1 && break
  sleep 0.1
done
sleep 2   # the shell and the wallpaper start half a second after niri
echo "host=$HS nested=$S" >> "$N/steps.log"
D=$(basename "$S" | cut -d. -f2)
rm -rf "$XDG_RUNTIME_DIR/vitrum-capture-$D" "$XDG_RUNTIME_DIR/vitrum-locked-$D"   # an earlier run's frames / lock marker
# Keep the test window out of the user's way: workspace 9 on the host, no focus.
NW=""
if [ -n "$HS" ] && [ -z "$HOSTWL" ]; then
  NW=$(NIRI_SOCKET="$HS" niri msg --json windows | python3 -c "import json,sys; w=[x for x in json.load(sys.stdin) if (x.get('app_id') or '').lower()=='niri']; print(w[-1]['id'] if w else '')")
  [ -n "$NW" ] && NIRI_SOCKET="$HS" niri msg action move-window-to-workspace --window-id "$NW" --focus false 9
fi
# Instance lookup by config path does not find it; the PID does.
qsipc() { local p; p=$(pgrep -n -f "qs -p $N/shell/shell.qml"); qs ipc --pid "$p" call "$@"; }
# Input runs inside the nested session (virtual keyboard: wtype, virtual pointer: wlrctl).
# SAFETY: input must never reach the user's session. ND is the nested niri's own
# display, taken from its socket; it is cleared (and every input, run: and bg:
# step refused) unless it is a live socket that is not the user's (wayland-1, the
# host session's display) and not the headless host's.
ND="$(basename "${S:-none}" | cut -d. -f2)"
UD="$(basename "${HS:-x.wayland-1.x}" | cut -d. -f2)"
if [ -z "$S" ] || [ -z "$ND" ] || [ "$ND" = wayland-1 ] || [ "$ND" = "$UD" ] || [ "$ND" = "${HOSTWL:-}" ] \
   || [ ! -S "$XDG_RUNTIME_DIR/$ND" ] || ! NIRI_SOCKET="$S" niri msg version >/dev/null 2>&1; then
  echo "SAFETY: no nested display (got '$ND', user's '$UD'): input, run: and bg: steps are refused" >> "$N/steps.log"
  ND=""
fi
echo "nested display: ${ND:-none} (user's: $UD, headless host: ${HOSTWL:-none})" >> "$N/steps.log"
nest() {
  case "$ND" in ""|wayland-1|"$UD") echo "SAFETY: refused '$*' (display '${ND:-unset}')" >> "$N/steps.log"; return 1 ;; esac
  echo "  [$ND] $*" >> "$N/steps.log"
  WAYLAND_DISPLAY="$ND" NIRI_SOCKET="$S" "$@"
}
# The id and top-left corner (output pixels) of the newest window with this app id: "id x y".
winpos() { NIRI_SOCKET="$S" niri msg --json windows | python3 -c '
import json, sys
ws = [w for w in json.load(sys.stdin) if (w.get("app_id") or "") == sys.argv[1]]
if ws:
    w = max(ws, key=lambda w: w["id"]); l = w["layout"]
    p = l.get("tile_pos_in_workspace_view") or [0, 0]; o = l.get("window_offset_in_tile") or [0, 0]
    print(w["id"], round(p[0] + o[0]), round(p[1] + o[1]), int(w["is_focused"]))' "$1"; }
# Absolute pointer position: wlrctl only moves relatively, so go to 0,0 first.
pointer_to() { nest wlrctl pointer move -20000 -20000; nest wlrctl pointer move "$1" "$2"; }
# A drag with the button held (wlrctl only clicks): host/vptr.c, built once
# (to a temporary name first: sessions in other slots may build it too).
VPTR="$HOME/.cache/vitrum-test-host/vptr"
if [ ! -x "$VPTR" ] || [ "$N/host/vptr.c" -nt "$VPTR" ]; then
  ( cd "$N/host" && wayland-scanner client-header wlr-virtual-pointer-unstable-v1.xml wlr-virtual-pointer-unstable-v1-client-protocol.h \
    && wayland-scanner private-code wlr-virtual-pointer-unstable-v1.xml wlr-virtual-pointer-unstable-v1-protocol.c \
    && mkdir -p "$(dirname "$VPTR")" && cc -O2 -I. vptr.c wlr-virtual-pointer-unstable-v1-protocol.c -o "$VPTR.$$" $(pkg-config --cflags --libs wayland-client) \
    && mv -f "$VPTR.$$" "$VPTR" ) >> "$N/steps.log" 2>&1 \
    || echo "WARNING: vptr did not build; drag: steps do nothing" >> "$N/steps.log"
fi
# drag_path x1 y1 [x y | shot:<cmd>]…: press at the first point, glide through
# the rest with the button held (shot: runs a command there, still held), let go.
drag_path() {
  local ops=(to "$1" "$2" wait 150 down wait 150); shift 2
  while [ $# -gt 0 ]; do
    case "$1" in shot:*) ops+=(wait 400 run "${1#shot:}" wait 200); shift ;;
                 *) ops+=(go "$1" "$2" 14 16 wait 150); shift 2 ;; esac
  done
  ops+=(up wait 300)
  nest "$VPTR" "${ops[@]}"
}
while IFS= read -r step; do
  [ -z "$step" ] && continue
  case "$step" in
    sleep:*) sleep "${step#sleep:}" ;;
    ipc:*) echo "ipc ${step#ipc:}" >> "$N/steps.log"; qsipc ${step#ipc:} >> "$N/steps.log" 2>&1 ;;
    niri:*) NIRI_SOCKET="$S" niri msg action ${step#niri:} ;;
    spawn:*) NIRI_SOCKET="$S" niri msg action spawn -- ${step#spawn:} >> "$N/steps.log" 2>&1 || echo "spawn failed: $?" >> "$N/steps.log" ;;
    windows) echo "windows: $(NIRI_SOCKET="$S" niri msg --json windows | python3 -c 'import json,sys; print([w["app_id"] + ("*" if w["is_focused"] else "") for w in json.load(sys.stdin)])')" >> "$N/steps.log" ;;
    # How long until some window holds the keyboard again (after an overlay closes).
    focuswait) t0=$(date +%s%N); while ! NIRI_SOCKET="$S" niri msg --json focused-window | grep -q '"id"'; do sleep 0.02; [ $(( ($(date +%s%N) - t0) / 1000000 )) -gt 5000 ] && break; done
               echo "focus after $(( ($(date +%s%N) - t0) / 1000000 )) ms" >> "$N/steps.log" ;;
    # Wait until a file exists (grim and friends are slow here: the hidden nested output gets few frames).
    waitfile:*) f="${step#waitfile:}"; f="${f/#\~/$H}"; t0=$(date +%s); while ! ls $f >/dev/null 2>&1; do sleep 0.2; [ $(( $(date +%s) - t0 )) -gt 40 ] && break; done
                echo "waitfile $f: $(( $(date +%s) - t0 )) s" >> "$N/steps.log" ;;
    # A command inside the nested session (its display and socket), output into the log; 15 s at most.
    # bg: a command left running in the nested session (killed at the end).
    bg:*) echo "bg [${ND:-refused}] ${step#bg:}" >> "$N/steps.log"
          [ -n "$ND" ] && ( WAYLAND_DISPLAY="$ND" NIRI_SOCKET="$S" setsid sh -c "${step#bg:}" >> "$N/steps.log" 2>&1 & echo $! >> "$N/bg.pids" ) ;;
    run:*) echo "run [${ND:-refused}] ${step#run:}" >> "$N/steps.log"
           if [ -n "$ND" ]; then WAYLAND_DISPLAY="$ND" NIRI_SOCKET="$S" timeout -s INT 15 sh -c "${step#run:}" >> "$N/steps.log" 2>&1; echo "exit $?" >> "$N/steps.log"; fi ;;
    app:*) a="${step#app:}"; name="${a%% *}"; pane=""; [ "$a" != "$name" ] && pane="${a#* }"
           NIRI_SOCKET="$S" niri msg action spawn -- sh -c "exec env HOME=$H XDG_CONFIG_HOME=$H/.config XDG_DATA_HOME=$H/.local/share PATH=$TPATH VITRUM_PANE=$pane qs -p $N/apps/$name/shell.qml >> $N/app-$name.log 2>&1" ;;
    appipc:*) a="${step#appipc:}"; name="${a%% *}"; echo "appipc $a" >> "$N/steps.log"
              qs ipc --pid "$(pgrep -n -f "qs -p $N/apps/$name/shell.qml")" call ${a#* } >> "$N/steps.log" 2>&1 ;;
    settings:*) printf '%s\n' "${step#settings:}" > "$H/.config/vitrum/settings.json"; sleep 2 ;;
    # waitwin:<app_id> — until a window with that app id exists and has the focus (30 s at most).
    waitwin:*) a="${step#waitwin:}"; t0=$(date +%s%N); st=""
               while :; do
                 wid=""; read -r wid wx wy wf <<< "$(winpos "$a")"
                 if [ -n "${wid:-}" ]; then
                   [ "${wf:-0}" = 1 ] && { st=focused; break; }
                   NIRI_SOCKET="$S" niri msg action focus-window --id "$wid" >/dev/null 2>&1
                 fi
                 [ $(( ($(date +%s%N) - t0) / 1000000 )) -gt 30000 ] && { st=timeout; break; }
                 sleep 0.2
               done
               sleep 0.8   # its first frames
               echo "waitwin $a: $st after $(( ($(date +%s%N) - t0) / 1000000 )) ms (id ${wid:-none} at ${wx:-?},${wy:-?})" >> "$N/steps.log" ;;
    # click:<x> <y> [left|right|middle] — output pixels (as in a shot:).
    click:*) set -- ${step#click:}; pointer_to "$1" "$2"; sleep 0.15; nest wlrctl pointer click "${3:-left}"; sleep 0.4
             echo "click $*" >> "$N/steps.log" ;;
    # wclick:<app_id> <x> <y> [button] — pixels inside that window (as in a winshot:).
    wclick:*) set -- ${step#wclick:}; wid=""; read -r wid wx wy wf <<< "$(winpos "$1")"
              if [ -n "${wid:-}" ]; then pointer_to $(( wx + $2 )) $(( wy + $3 )); sleep 0.15; nest wlrctl pointer click "${4:-left}"; sleep 0.4
                echo "wclick $* -> $(( wx + $2 )),$(( wy + $3 ))" >> "$N/steps.log"
              else echo "wclick $*: no such window" >> "$N/steps.log"; fi ;;
    # move:<x> <y> — the pointer to output pixels (hover). scroll:<dy> — wheel steps (+ down).
    move:*) set -- ${step#move:}; pointer_to "$1" "$2"; sleep 0.3 ;;
    # drag:<x1> <y1> <x2> <y2> [<x> <y> | shot=<name>]… — output pixels, the
    # button held all the way; shot= takes a screenshot there, before the release.
    # wdrag:<app_id> <x1> <y1> … — window pixels; its shots are of that window.
    drag:*|wdrag:*) set -- ${step#*drag:}; app=""; ox=0; oy=0; wid=""
           if [ "${step%%:*}" = wdrag ]; then app="$1"; shift; read -r wid ox oy wf <<< "$(winpos "$app")"; fi
           if [ -n "$app" ] && [ -z "${wid:-}" ]; then echo "wdrag $app: no such window" >> "$N/steps.log"; continue; fi
           seq=()
           while [ $# -gt 0 ]; do
             case "$1" in
               shot=*) if [ -n "$app" ]; then seq+=("shot:niri msg action screenshot-window --id $wid --write-to-disk true --path $N/shots/${1#shot=}.png >/dev/null 2>&1")
                       else seq+=("shot:niri msg action screenshot-screen --write-to-disk true --path $N/shots/${1#shot=}.png >/dev/null 2>&1"); fi; shift ;;
               *) [ $# -ge 2 ] || break; seq+=($(( ox + $1 )) $(( oy + $2 ))); shift 2 ;;
             esac
           done
           drag_path "${seq[@]}"; sleep 0.3
           echo "${step%%:*} ${step#*drag:}" >> "$N/steps.log" ;;
    scroll:*) nest wlrctl pointer scroll "$(( ${step#scroll:} * 15 ))" 0; sleep 0.4 ;;
    # type:<text> — typed as is. key:<keys> — one combo, e.g. Return, ctrl+a, shift+Tab.
    type:*) nest wtype -- "${step#type:}"; sleep 0.3 ;;
    key:*) k="${step#key:}"; args=(); IFS=+ read -ra parts <<< "$k"; last="${parts[${#parts[@]}-1]}"
           for m in "${parts[@]:0:${#parts[@]}-1}"; do args+=(-M "$m"); done; args+=(-k "$last")
           for m in "${parts[@]:0:${#parts[@]}-1}"; do args+=(-m "$m"); done
           nest wtype "${args[@]}" >> "$N/steps.log" 2>&1; sleep 0.3 ;;
    # winshot:<app_id> <name> — just that window (shots/<name>.png, window pixels).
    winshot:*) set -- ${step#winshot:}; wid=""; read -r wid wx wy wf <<< "$(winpos "$1")"
               [ -n "${wid:-}" ] && NIRI_SOCKET="$S" niri msg action screenshot-window --id "$wid" --write-to-disk true --path "$N/shots/$2.png" >/dev/null 2>&1; sleep 0.7 ;;
    # dump:<path> [name] — copy a file (~ is the test HOME) into the results.
    dump:*) set -- ${step#dump:}; f="${1/#\~/$H}"; cp "$f" "$N/shots/${2:-$(basename "$f")}" 2>> "$N/steps.log" ;;
    shot:*) NIRI_SOCKET="$S" niri msg action screenshot-screen --write-to-disk true --path "$N/shots/${step#shot:}.png" >/dev/null 2>&1; sleep 0.7 ;;
    # niri refuses screenshots while locked; the host niri can still shoot the nested window itself.
    hostshot:*) [ -n "$NW" ] && NIRI_SOCKET="$HS" niri msg action screenshot-window --id "$NW" --write-to-disk true --path "$N/shots/${step#hostshot:}.png" >/dev/null 2>&1; sleep 0.7 ;;
  esac
done <<< "$STEPS"
NIRI_SOCKET="$S" niri msg layers > "$N/layers.txt" 2>&1
pkill -f "niri -c $C/config.kdl"; pkill -f "qs -p $N/" 2>/dev/null
[ -n "$HOSTWL" ] && [ -s "$N/host.pid" ] && kill "$(cat "$N/host.pid")" 2>/dev/null
[ -f "$N/bg.pids" ] && { while read -r p; do kill -- -"$p" 2>/dev/null || kill "$p" 2>/dev/null; done < "$N/bg.pids"; rm -f "$N/bg.pids"; }
[ -f "$N/bus.pid" ] && kill "$(cat "$N/bus.pid")" 2>/dev/null; rm -f "$N/bus" "$N/bus.pid"
exit 0
