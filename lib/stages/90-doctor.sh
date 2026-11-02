#!/usr/bin/env bash
# Stage: doctor — check an install without changing anything.
#
# Failures are things the desktop needs to start; warnings degrade looks, not
# function. Exit status: non-zero when anything failed.

VITRUM_SYSROOT="${VITRUM_SYSROOT:-}"

_DOC_FAIL=0
_DOC_WARN=0

_chk() {  # _chk <label> ok|warn|fail [detail]
  case "$2" in
    ok)   printf '  %s%s%s %s\n' "$C_GREEN" "$G_OK" "$C_RESET" "$1" ;;
    warn) _DOC_WARN=$((_DOC_WARN + 1)); printf '  %s!%s %s%s\n' "$C_YELLOW" "$C_RESET" "$1" "${3:+ — $3}" ;;
    fail) _DOC_FAIL=$((_DOC_FAIL + 1)); printf '  %s%s%s %s%s\n' "$C_RED" "$G_ERR" "$C_RESET" "$1" "${3:+ — $3}" ;;
  esac
}
_chk_path() {  # _chk_path <path> <label> [fail|warn]
  if [[ -e "$1" ]]; then _chk "$2" ok; else _chk "$2" "${3:-fail}" "missing: $1"; fi
}

stage_doctor() {
  stage "Doctor"
  _DOC_FAIL=0 _DOC_WARN=0

  _chk "system: packages $PKG_BACKEND, init $INIT_BACKEND" ok

  local bin="${VITRUM_NIRI_BIN:-/usr/local/bin/niri}"
  if [[ -x "$bin" ]]; then
    if "$bin" --version >/dev/null 2>&1; then _chk "niri: $("$bin" --version 2>/dev/null | head -1)" ok
    else _chk "niri" fail "does not start, a system update may have taken a library from it — ./install.sh --only niri"; fi
    # shellcheck source=/dev/null
    [[ -n "${NIRI_REV:-}" ]] || source "$VITRUM_DIR/lib/stages/30-niri.sh"
    local stamp kind
    stamp="$(cat "$VITRUM_STATE/niri.rev" 2>/dev/null)" || stamp=""
    kind="$(niri_installed_kind)"
    if [[ "$stamp" == "$(niri_stamp)" ]]; then
      _chk "compositor: $kind, from the pinned niri, glass and patches (${stamp:0:7}${stamp#"$NIRI_REV"})" ok
    else
      _chk "compositor revision ($kind)" warn "built from other revisions — ./install.sh --only niri"
    fi
  else
    _chk "niri" fail "not installed — ./install.sh --only niri"
  fi

  _chk_path "$VITRUM_SYSROOT/usr/local/bin/vitrum-session" "session wrapper"
  _chk_path "$VITRUM_SYSROOT/usr/local/share/wayland-sessions/vitrum.desktop" "login entry"
  _chk_path "$VITRUM_PREFIX/niri/config.kdl" "niri config"
  if [[ -x "$bin" && -e "$VITRUM_PREFIX/niri/config.kdl" ]]; then
    if "$bin" validate -c "$VITRUM_PREFIX/niri/config.kdl" >/dev/null 2>&1; then _chk "niri accepts the config" ok
    else _chk "niri config" fail "rejected — run: niri validate -c $VITRUM_PREFIX/niri/config.kdl"; fi
  fi
  _chk_path "$HOME/.local/bin/vitrum-startup" "startup script"
  _chk_path "$HOME/.local/bin/vitrum-shell" "shell launcher"
  _chk_path "$XDG_CONFIG_HOME/quickshell/vitrum/shell.qml" "shell files"
  _doctor_versions
  _doctor_init

  local fonts; fonts="$(fc-list 2>/dev/null)" || true
  local f
  for f in "Inter" "JetBrains Mono" "Phosphor-Light" "Phosphor-Fill"; do
    if grep -q "$f" <<<"$fonts"; then _chk "font: $f" ok; else _chk "font: $f" warn "not found by fontconfig"; fi
  done
  _chk_path "$HOME/.local/share/icons/Bibata-Modern-Classic" "cursor: Bibata Modern Classic" warn

  _doctor_session
  _doctor_crashes
  _doctor_kernel
  _doctor_steam_theme
  _doctor_vesktop_theme
  _doctor_input_method

  local missing=() p
  while IFS= read -r p; do pkg_installed "$p" || missing+=("${p%@*}"); done < <(packages_for required 2>/dev/null)
  if [[ ${#missing[@]} -eq 0 ]]; then _chk "every required package is installed" ok
  else _chk "${#missing[@]} required packages missing" fail "${missing[*]}"; fi

  printf '\n'
  if (( _DOC_FAIL > 0 )); then
    err '%s problem(s), %s warning(s)' "$_DOC_FAIL" "$_DOC_WARN"
    return 1
  fi
  ok "healthy ($_DOC_WARN warning(s))"
  stage_done
}

# The input method: fcitx5 there, its three engines there, and inside a session
# (only there: an install from a TTY has no daemon to ask) the daemon up.
_doctor_input_method() {
  local on
  on="$(components_load >/dev/null 2>&1; component_active input_method && echo 1)" || true
  [[ "$on" == 1 ]] || return 0
  if ! have fcitx5; then _chk "input method" fail "fcitx5 is not installed — ./install.sh --only packages"; return 0; fi
  local e dir="$VITRUM_SYSROOT/usr/share/fcitx5/inputmethod"
  for e in mozc hangul pinyin; do
    if [[ -e "$dir/$e.conf" ]]; then _chk "input method: $e" ok
    else _chk "input method: $e" warn "the engine is missing — ./install.sh --only packages"; fi
  done
  [[ -n "${WAYLAND_DISPLAY:-}" ]] || return 0
  if ! have fcitx5-remote; then _chk "input method" warn "no fcitx5-remote: the bar cannot follow it"
  elif fcitx5-remote --check >/dev/null 2>&1; then _chk "input method: fcitx5 is running" ok
  else _chk "input method" warn "fcitx5 is not running — vitrum-im start"; fi
}

# _doc_version <command> — the first x.y.z its --version prints, or nothing.
_doc_version() { "$1" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1 || true; }

# A package can be there and still be too old: Fedora's own quickshell is a
# 0.2 snapshot and its matugen a 3.x, both under the names the COPR builds
# have, and the theme quietly falls back to the preset with matugen 3.
_doctor_versions() {
  local q v
  if have qs; then q=qs; elif have quickshell; then q=quickshell; else q=""; fi
  if [[ -z "$q" ]]; then _chk "quickshell" fail "not on PATH"
  else
    v="$(_doc_version "$q")"
    if [[ -n "$v" ]] && [[ "$(version_cmp "$v" 0.3.1)" == -1 ]]; then _chk "quickshell $v" fail "the shell needs 0.3.1 or newer — ./install.sh --only packages"
    else _chk "quickshell${v:+ $v}" ok; fi
  fi
  if have matugen; then
    v="$(_doc_version matugen)"
    if [[ -n "$v" ]] && [[ "$(version_cmp "$v" 4.0.0)" == -1 ]]; then _chk "matugen $v" warn "colours from the wallpaper need matugen 4 — the theme falls back to the preset"
    else _chk "matugen${v:+ $v}" ok; fi
  fi
}

# On runit nothing runs a service that is not linked: without the system bus
# and elogind there is no login screen, no seat and no XDG_RUNTIME_DIR.
_doctor_init() {
  [[ "${INIT_BACKEND:-}" == runit ]] && declare -F svc_enabled >/dev/null || return 0
  local s
  for s in dbus elogind; do
    if svc_enabled "$s"; then _chk "runit: $s" ok; else _chk "runit: $s" fail "not enabled — sudo ln -s /etc/sv/$s /var/service/"; fi
  done
  for s in polkitd NetworkManager; do
    if svc_enabled "$s"; then _chk "runit: $s" ok; else _chk "runit: $s" warn "not enabled — sudo ln -s /etc/sv/$s /var/service/"; fi
  done
  if [[ -n "${WAYLAND_DISPLAY:-}" && -z "${XDG_RUNTIME_DIR:-}" ]]; then
    _chk "XDG_RUNTIME_DIR" fail "unset in the session — elogind did not register the login (pam_elogind in /etc/pam.d/system-login)"
  fi
}

# The Steam theme, when the part is on (as components.json has it: vitrum
# doctor runs before anything loads the choices, so they are read here, in a
# subshell that leaves a run's own alone), from vitrum-steam-theme status.
# Warnings only: Steam works either way. No Steam, nothing to say.
_doctor_steam_theme() {
  local on
  on="$(components_load >/dev/null 2>&1; component_active steam_theme && echo 1)" || true
  [[ "$on" == 1 ]] || return 0
  if [[ ! -d "$HOME/.steam/steam/ubuntu12_32" && ! -d "$XDG_DATA_HOME/Steam/ubuntu12_32" ]]; then
    [[ -d "$HOME/.var/app/com.valvesoftware.Steam" ]] && _chk "Steam theme" warn "Steam is the Flatpak, which Millennium does not support"
    return 0
  fi
  local helper="$HOME/.local/bin/vitrum-steam-theme" st
  if [[ ! -x "$helper" ]]; then _chk "Steam theme" warn "vitrum-steam-theme is missing — ./install.sh --only shell"; return 0; fi
  # millennium installed active, each 1 or 0
  st="$("$helper" status 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(*(int(bool(d.get(k))) for k in ("millennium","installed","active")))' 2>/dev/null)" || st=""
  if [[ ! "$st" =~ ^[01]\ [01]\ [01]$ ]]; then _chk "Steam theme" warn "vitrum-steam-theme status failed — run it to see why"; return 0; fi
  local mill inst act; read -r mill inst act <<<"$st"
  if [[ "$mill" == 1 ]]; then _chk "Millennium" ok
  else _chk "Millennium" warn "not installed, or Steam no longer loads it (a Steam update can drop the hook) — vitrum-steam-theme install"; fi
  if [[ "$inst" == 0 ]]; then _chk "Steam theme" warn "not installed — vitrum-steam-theme install"
  elif [[ "$act" == 1 ]]; then _chk "Steam theme: active" ok
  elif _doc_steam_theme_off; then _chk "Steam theme: installed, switched off in Settings" ok
  else _chk "Steam theme" warn "installed but not active — vitrum-steam-theme apply, then restart Steam"; fi
}

# _doc_steam_theme_off — steam.theme.enabled is false in your settings.
_doc_steam_theme_off() {
  have python3 || return 1
  python3 - "$XDG_CONFIG_HOME/vitrum/settings.json" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(1)
t = ((d.get("steam") or {}).get("theme") or {}) if isinstance(d, dict) else {}
raise SystemExit(0 if isinstance(t, dict) and t.get("enabled") is False else 1)
PY
}

# The Vesktop theme, read the same way as the Steam theme's, from
# vitrum-vesktop-theme status. Warnings only; no Vesktop (native or the
# Flatpak), nothing to say.
_doctor_vesktop_theme() {
  local on
  on="$(components_load >/dev/null 2>&1; component_active vesktop_theme && echo 1)" || true
  [[ "$on" == 1 ]] || return 0
  vesktop_present || return 0
  local helper="$HOME/.local/bin/vitrum-vesktop-theme" st
  if [[ ! -x "$helper" ]]; then _chk "Vesktop theme" warn "vitrum-vesktop-theme is missing — ./install.sh --only shell"; return 0; fi
  # installed active, each 1 or 0
  st="$("$helper" status 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(*(int(bool(d.get(k))) for k in ("installed","active")))' 2>/dev/null)" || st=""
  if [[ ! "$st" =~ ^[01]\ [01]$ ]]; then _chk "Vesktop theme" warn "vitrum-vesktop-theme status failed — run it to see why"; return 0; fi
  local inst act; read -r inst act <<<"$st"
  if [[ "$inst" == 0 ]]; then _chk "Vesktop theme" warn "not installed — vitrum-vesktop-theme install"
  elif [[ "$act" == 1 ]]; then _chk "Vesktop theme: active" ok
  elif _doc_vesktop_theme_off; then _chk "Vesktop theme: installed, switched off in Settings" ok
  else _chk "Vesktop theme" warn "installed but not active — vitrum-vesktop-theme apply, then restart Vesktop"; fi
}

# _doc_vesktop_theme_off — vesktop.theme.enabled is false in your settings.
_doc_vesktop_theme_off() {
  have python3 || return 1
  python3 - "$XDG_CONFIG_HOME/vitrum/settings.json" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(1)
t = ((d.get("vesktop") or {}).get("theme") or {}) if isinstance(d, dict) else {}
raise SystemExit(0 if isinstance(t, dict) and t.get("enabled") is False else 1)
PY
}

# The shell's crashes of the last week, newest first, from Quickshell's own
# reports: every init has those, core dumps only exist under systemd. One
# warning however many there are; the folder also holds Settings' crashes,
# which _doc_crash leaves out.
_doctor_crashes() {
  local dir="$XDG_CACHE_HOME/quickshell/crashes" f why files=() lines=()
  while IFS= read -r f; do files+=("$f"); done < <(find "$dir" -maxdepth 2 -name report.txt -mtime -7 2>/dev/null)
  if [[ ${#files[@]} -gt 0 ]]; then
    while IFS= read -r f; do
      why="$(_doc_crash "$f")"
      [[ -z "$why" ]] || lines+=("$(date -r "$f" '+%F %H:%M') $why — $f")
    done < <(ls -1t -- "${files[@]}")
  fi
  if [[ ${#lines[@]} -eq 0 ]]; then _chk "no shell crashes in the last 7 days" ok; return 0; fi
  _chk "shell crashes: ${#lines[@]} in the last 7 days" warn
  printf '      %s\n' "${lines[@]:0:10}"
  if [[ ${#lines[@]} -gt 10 ]]; then printf '      … and %s older\n' "$((${#lines[@]} - 10))"; fi
}

# _doc_crash <report.txt> — the cause in one line, nothing for another config's
# crash. The same reading as shell/lib/crashes.js, in awk because a tty has no
# QML; both are tested on tests/fixtures/crashes.
_doc_crash() {
  awk '
    function short(s, n, w) {
      gsub(/\(anonymous namespace\)::/, "", s); gsub(/operator\(\)/, "operator@", s)
      while (sub(/<[^<>]*>/, "", s)) {}
      sub(/\(.*$/, "", s); sub(/[ \t]+$/, "", s)
      n = split(s, w, /[ \t]+/); s = w[n]
      sub(/operator@/, "operator()", s)
      return s
    }
    /^===== / { sect = $0; next }
    sect ~ /Instance Information/ {
      if ($0 ~ /^Signal: /) { sig = substr($0, 9); sub(/ \([0-9]+\)$/, "", sig) }
      else if ($0 ~ /^Config Path: /) conf = substr($0, 14)
      next
    }
    sect ~ /Stacktrace/ && frame == "" {
      if ($0 !~ /^#[0-9]+[ \t]+(0x[0-9a-fA-F]+|\(inlined\))[ \t]+(at|in) /) next
      rest = $0; sub(/^#[0-9]+[ \t]+(0x[0-9a-fA-F]+|\(inlined\))[ \t]+/, "", rest)
      sym = ""; file = ""
      if (rest ~ /^at /) file = substr(rest, 4)
      else {
        rest = substr(rest, 4); at = 0
        for (i = 1; i <= length(rest) - 3; i++) if (substr(rest, i, 4) == " at ") at = i
        if (at) { sym = short(substr(rest, 1, at - 1)); file = substr(rest, at + 4) }
        else sym = short(rest)
      }
      if (file ~ /(^|\/)(libc|libpthread|libgcc_s|libstdc\+\+|libjemalloc|ld-linux[^\/]*)\.so/) next
      if (sym != "") {
        if (sym !~ /^(raise|abort|gsignal|pthread_kill|__pthread_kill[A-Za-z0-9_]*|__restore_rt|__assert[A-Za-z0-9_]*|__libc[A-Za-z0-9_]*|__GI_[A-Za-z0-9_]*|__cxa[A-Za-z0-9_]*|__cxxabiv1[^ ]*|__gnu_cxx::[^ ]*|std::terminate|std::__terminate|qt_assert[A-Za-z0-9_]*|qt_message[A-Za-z0-9_]*|qFatal|QMessageLogger::[^ ]*|QDebug::~QDebug|qs::crash::[^ ]*)$/) frame = sym
      } else if (file != "" && lib == "") {
        lib = file; sub(/^.*\//, "", lib); sub(/\.so.*$/, ".so", lib)
      }
    }
    END {
      sub(/[ \t]+$/, "", conf)
      if (conf != "" && conf !~ /\/quickshell\/vitrum\/shell\.qml$/) exit
      if (sig == "") sig = "Unknown signal"
      if (frame != "") print sig " in " frame
      else if (lib != "") print sig " in " lib " (no symbols)"
      else print sig " (no usable stack in the report)"
    }
  ' "$1"
}

# Kernel options: warnings, each naming what it costs. Without a readable config
# (no CONFIG_IKCONFIG_PROC, no /boot/config-*) the check says so and moves on.
_doctor_kernel() {
  # shellcheck source=/dev/null
  declare -F kernel_missing >/dev/null || source "$VITRUM_DIR/lib/kernel.sh"
  local config missing line
  if ! config="$(kernel_config 2>/dev/null)" || [[ -z "$config" ]]; then
    _chk "kernel options" warn "no config to read (CONFIG_IKCONFIG_PROC or /boot/config-$(uname -r)) — not checked"
    return 0
  fi
  missing="$(kernel_missing "$config")"
  if [[ -z "$missing" ]]; then _chk "kernel: every option the desktop uses is there" ok; return 0; fi
  while IFS= read -r line; do
    _chk "kernel: CONFIG_${line%%|*} is off" warn "${line#*|}"
  done <<<"$missing"
}

# What the running session gets wrong: screen sharing (portal + niri's D-Bus
# interfaces), sound, the NVIDIA driver, glass. Only checked from inside a
# session; from a tty there is nothing running to ask.
_doctor_session() {
  local sysroot="$VITRUM_SYSROOT"
  _chk_path "$sysroot/usr/share/xdg-desktop-portal/portals/vitrum.portal" "screen-share portal backend" warn
  local conf="$XDG_CONFIG_HOME/xdg-desktop-portal/niri-portals.conf"
  [[ -f "$conf" ]] || conf="$XDG_CONFIG_HOME/xdg-desktop-portal/portals.conf"
  if grep -qs 'ScreenCast=vitrum' "$conf"; then _chk "portals: screen sharing goes to vitrum" ok
  else _chk "portals: screen sharing" warn "not routed to vitrum in $conf — ./install.sh --only session"; fi

  if [[ -z "${WAYLAND_DISPLAY:-}" || -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    _chk "session checks" warn "not inside a graphical session — run vitrum doctor from a terminal in the desktop"
    return 0
  fi
  _doc_name() { busctl --user status "$1" >/dev/null 2>&1 || dbus-send --session --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetNameOwner "string:$1" >/dev/null 2>&1; }
  if _doc_name org.gnome.Mutter.ScreenCast; then _chk "niri's screen-cast interface (niri --session)" ok
  else _chk "niri's screen-cast interface" fail "absent: niri was not started with --session — log out and pick the vitrum session"; fi
  if pgrep -u "$(id -u)" -x xdg-desktop-portal >/dev/null 2>&1 || _doc_name org.freedesktop.portal.Desktop; then _chk "xdg-desktop-portal" ok
  else _chk "xdg-desktop-portal" warn "not running (it starts on first use)"; fi
  if _doc_name org.freedesktop.secrets; then _chk "password store (Secret Service)" ok
  else _chk "password store" warn "nothing answers org.freedesktop.secrets — browsers and git keep passwords in plain text or forget them; log out and in after ./install.sh --only session"; fi
  local p
  for p in pipewire wireplumber; do
    if pgrep -u "$(id -u)" -x "$p" >/dev/null 2>&1; then _chk "$p" ok; else _chk "$p" fail "not running — no sound and no screen sharing"; fi
  done
  if [[ -e /sys/module/nvidia ]]; then
    # The parameters are root-only on some kernels: then the kernel command
    # line and modprobe.d tell what was asked for.
    local ms fb asked
    ms="$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || true)"
    fb="$(cat /sys/module/nvidia_drm/parameters/fbdev 2>/dev/null || true)"
    asked="$(cat /proc/cmdline 2>/dev/null || true) $(cat /etc/modprobe.d/*.conf 2>/dev/null | grep -E '^options nvidia[-_]drm' || true)"
    if [[ "$ms" == "Y" ]] || { [[ -z "$ms" ]] && grep -qE 'nvidia[-_]drm[. ].*modeset=1|nvidia-drm\.modeset=1|nvidia_drm\.modeset=1' <<<"$asked"; }; then
      _chk "NVIDIA: kernel modesetting" ok
    elif [[ -z "$ms" ]]; then
      _chk "NVIDIA: kernel modesetting" warn "could not tell (root-only) — make sure nvidia_drm.modeset=1 is set"
    else
      _chk "NVIDIA: kernel modesetting" fail "nvidia_drm.modeset=1 is not set — add it to the kernel command line"
    fi
    if [[ "$fb" == "N" ]]; then _chk "NVIDIA: fbdev" warn "nvidia_drm.fbdev=1 avoids a black console after the session"
    else _chk "NVIDIA: fbdev" ok; fi
  fi
  local caps="${XDG_DATA_HOME:-$HOME/.local/share}/vitrum/niri-caps.json"
  if grep -qs '"shapedGlass": true' "$caps"; then _chk "shaped glass (islands and panels as one drop)" ok
  else _chk "shaped glass" warn "the running niri lacks it — log out and in after an update, or ./install.sh --only niri"; fi
}
