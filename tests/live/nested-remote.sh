# Runs on terpinator (fed to bash -s by nested.sh). STEPS holds the steps, one per line.
set -u
export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1
N=/tmp/vitrum-nested
H="$N/home"
[ -n "$N" ] || exit 1
C="$H/.config/vitrum/niri"     # the nested niri reads the test HOME's config, so settings → vitrum-theme → niri works
# NESTED_NIRI: another niri binary (a fresh build) for the nested session; it
# comes first in PATH there, so vitrum-theme probes it too.
BIN="$N/bin"; rm -rf "$BIN"; mkdir -p "$BIN"
[ -n "${NESTED_NIRI:-}" ] && ln -sf "$NESTED_NIRI" "$BIN/niri"
TPATH="$BIN:$N/tools:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
pkill -f "niri -c $C/config.kdl" 2>/dev/null; pkill -f "qs -p $N/" 2>/dev/null; sleep 0.5
rm -rf "$H" "$N/shots" "$N/steps.log" "$N"/app-*.log
mkdir -p "$H/.config/vitrum" "$H/.local/share/vitrum" "$N/shots"
cp -r "$HOME/.config/vitrum/niri" "$C"
cp "$HOME/.local/share/vitrum/palette.json" "$H/.local/share/vitrum/" 2>/dev/null
# The user's fonts and icon themes (Material Symbols, Bibata) live under the real XDG_DATA_HOME.
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
WALL=$(ls "$HOME"/Pictures/Wallpapers/*.jpg 2>/dev/null | head -1)
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
  bash "$N/host/build.sh" "$HOME/.cache/vitrum-test-host" >> "$N/steps.log" 2>&1
  pkill -f "$HOME/.cache/vitrum-test-host/tinywl" 2>/dev/null; rm -f "$N/hostwl"
  ( WLR_BACKENDS=headless WLR_RENDERER=gles2 WLR_HEADLESS_OUTPUTS=1 timeout "$(( ${NESTED_TIMEOUT:-180} + 10 ))" \
      "$HOME/.cache/vitrum-test-host/tinywl" -s "echo \$WAYLAND_DISPLAY > $N/hostwl" > "$N/host.log" 2>&1 & )
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
( [ -n "$HOSTWL" ] && export WAYLAND_DISPLAY="$HOSTWL"; timeout "${NESTED_TIMEOUT:-180}" "${NESTED_NIRI:-niri}" -c "$C/config.kdl" > "$N/niri.log" 2>&1 & )
sleep 5
S=$(ls -t "$XDG_RUNTIME_DIR"/niri.wayland-*.sock | grep -v "^$HS\$" | head -1)
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
    bg:*) echo "bg ${step#bg:}" >> "$N/steps.log"; ( WAYLAND_DISPLAY="$(basename "$S" | cut -d. -f2)" NIRI_SOCKET="$S" setsid sh -c "${step#bg:}" >> "$N/steps.log" 2>&1 & echo $! >> "$N/bg.pids" ) ;;
    run:*) echo "run ${step#run:}" >> "$N/steps.log"; WAYLAND_DISPLAY="$(basename "$S" | cut -d. -f2)" NIRI_SOCKET="$S" timeout -s INT 15 sh -c "${step#run:}" >> "$N/steps.log" 2>&1; echo "exit $?" >> "$N/steps.log" ;;
    app:*) a="${step#app:}"; name="${a%% *}"; pane=""; [ "$a" != "$name" ] && pane="${a#* }"
           NIRI_SOCKET="$S" niri msg action spawn -- sh -c "exec env HOME=$H XDG_CONFIG_HOME=$H/.config XDG_DATA_HOME=$H/.local/share PATH=$TPATH VITRUM_PANE=$pane qs -p $N/apps/$name/shell.qml >> $N/app-$name.log 2>&1" ;;
    appipc:*) a="${step#appipc:}"; name="${a%% *}"; echo "appipc $a" >> "$N/steps.log"
              qs ipc --pid "$(pgrep -n -f "qs -p $N/apps/$name/shell.qml")" call ${a#* } >> "$N/steps.log" 2>&1 ;;
    settings:*) printf '%s\n' "${step#settings:}" > "$H/.config/vitrum/settings.json"; sleep 2 ;;
    shot:*) NIRI_SOCKET="$S" niri msg action screenshot-screen --write-to-disk true --path "$N/shots/${step#shot:}.png" >/dev/null 2>&1; sleep 0.7 ;;
    # niri refuses screenshots while locked; the host niri can still shoot the nested window itself.
    hostshot:*) [ -n "$NW" ] && NIRI_SOCKET="$HS" niri msg action screenshot-window --id "$NW" --write-to-disk true --path "$N/shots/${step#hostshot:}.png" >/dev/null 2>&1; sleep 0.7 ;;
  esac
done <<< "$STEPS"
NIRI_SOCKET="$S" niri msg layers > "$N/layers.txt" 2>&1
pkill -f "niri -c $C/config.kdl"; pkill -f "qs -p $N/" 2>/dev/null
[ -n "$HOSTWL" ] && pkill -f "$HOME/.cache/vitrum-test-host/tinywl" 2>/dev/null
[ -f "$N/bg.pids" ] && { while read -r p; do kill -- -"$p" 2>/dev/null || kill "$p" 2>/dev/null; done < "$N/bg.pids"; rm -f "$N/bg.pids"; }
[ -f "$N/bus.pid" ] && kill "$(cat "$N/bus.pid")" 2>/dev/null; rm -f "$N/bus" "$N/bus.pid"
exit 0
