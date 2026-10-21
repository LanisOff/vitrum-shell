# shellcheck shell=bash
# Init backend: runit (Void), with elogind providing the seat and session.
#
# A runit service is enabled by linking /etc/sv/<name> into the directory
# runsvdir watches, and the link alone starts it: there is no "enabled but not
# running". So what must not start under a running install — the login screen,
# which would take the console, and NetworkManager, which would fight the
# network the install is using — is linked at the next boot instead, from
# /etc/rc.local (Void runs it in stage 2, before runsvdir starts).

# The rc.local block that does those changes once and then removes itself.
_RUNIT_BOOT_BEGIN="# vitrum begin: service changes for the next boot (written by the vitrum installer; it removes itself)"
_RUNIT_BOOT_END="# vitrum end: service changes for the next boot"

svc_exists() { [[ -d "${VITRUM_ROOTFS:-}/etc/sv/$1" ]]; }

# Where the links go. /var/service is the running runlevel; it points into
# /run, so with runit not running (a chroot, a container) it leads nowhere and
# the runlevel's own directory takes the links.
_runit_svdir() {
  local r="${VITRUM_ROOTFS:-}"
  if [[ -d "$r/var/service" ]]; then printf '%s\n' "$r/var/service"
  elif [[ -d "$r/etc/runit/runsvdir/current" ]]; then printf '%s\n' "$r/etc/runit/runsvdir/current"
  else printf '%s\n' "$r/etc/runit/runsvdir/default"; fi
}

# runsvdir is up: a link made now starts its service within five seconds.
_runit_running() { [[ -d "${VITRUM_ROOTFS:-}/run/runit/runsvdir" ]]; }

_runit_linked() { [[ -L "$(_runit_svdir)/$1" || -d "$(_runit_svdir)/$1" ]]; }

# _runit_start <service> — runsv picks a new link up on runsvdir's next scan
# (every five seconds); sv can only talk to it after that.
_runit_start() {
  local dir _
  dir="$(_runit_svdir)"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would run: sudo sv up $1"; return 0; fi
  for _ in 1 2 3 4 5 6 7 8; do
    sudo test -p "$dir/$1/supervise/ok" 2>/dev/null && break
    sleep 1
  done
  sudo sv up "$1" >/dev/null 2>&1 || warn 'runit did not start %s — see: sudo sv status %s' "$1" "$1"
}

svc_enable_system() {  # <service> [ignored: runit has no runlevel argument here]
  if ! svc_exists "$1"; then dim "no runit service $1 — skipped"; return 0; fi
  local dir; dir="$(_runit_svdir)"
  if ! _runit_linked "$1"; then
    run_ok sudo ln -s "/etc/sv/$1" "$dir/$1" || { warn 'could not enable %s' "$1"; return 0; }
  fi
  if _runit_running; then _runit_start "$1"
  else info "runit is not running here (a chroot or a container): $1 starts on the next boot"; fi
}

# _runit_block_awk <mode> — the first complete block in rc.local: "in"
# prints the queued lines inside it, "out" everything else. A begin marker
# with no end after it is no block: it and all after it are the user's.
# shellcheck disable=SC2016  # an awk program, not shell
_RUNIT_BLOCK_AWK='
  { line[NR] = $0 }
  END {
    for (i = 1; i <= NR; i++) if (line[i] == b) { s = i; break }
    if (s) for (i = s + 1; i <= NR; i++) if (line[i] == e) { t = i; break }
    if (!t) s = 0
    for (i = 1; i <= NR; i++) {
      inside = s && i > s && i < t
      if (mode == "in" && inside && line[i] ~ /^(ln -sfn|rm -f) /) print line[i]
      if (mode == "out" && !(s && i >= s && i <= t)) print line[i]
    }
  }'

# The rc.local lines already queued for the next boot.
_runit_boot_lines() {
  [[ -f "${VITRUM_ROOTFS:-}/etc/rc.local" ]] || return 0
  awk -v b="$_RUNIT_BOOT_BEGIN" -v e="$_RUNIT_BOOT_END" -v mode=in "$_RUNIT_BLOCK_AWK" "${VITRUM_ROOTFS:-}/etc/rc.local"
}

# The block's last line: it removes the block, the first one from the top
# only. rc.local is running while it does so, and the shell reading it goes on
# at its byte offset: rewritten in place, the user's lines below would be
# skipped or cut in half. So a new file takes the old one's name (mv), and the
# shell keeps reading the old one it has open. cp -p first gives the new file
# the old one's mode and owner; a symlinked rc.local stays a symlink.
_runit_boot_self_delete() {
  printf '%s' "vitrum_rc=\$(readlink -f /etc/rc.local) && [ -n \"\$vitrum_rc\" ] && cp -p \"\$vitrum_rc\" \"\$vitrum_rc.vitrum-tmp\" && awk -v b='$_RUNIT_BOOT_BEGIN' -v e='$_RUNIT_BOOT_END' 'f == 0 && \$0 == b { f = 1; next } f == 1 { if (\$0 == e) f = 2; next } { print }' \"\$vitrum_rc\" > \"\$vitrum_rc.vitrum-tmp\" && mv -f \"\$vitrum_rc.vitrum-tmp\" \"\$vitrum_rc\" || rm -f \"\${vitrum_rc:-/nonexistent}.vitrum-tmp\""
}

# _runit_at_next_boot <line>... — add "ln -sfn /etc/sv/X …/current/X" and
# "rm -f …/current/X" lines to the rc.local block. A line already there is not
# added twice, and a new one cancels a queued opposite for the same service
# (an uninstall before the reboot takes back what the install queued). The
# block goes right after the shebang: a user's rc.local that ends in exit 0,
# or execs something, would never reach a block at its end.
_runit_at_next_boot() {
  local f="${VITRUM_ROOTFS:-}/etc/rc.local" rest="" lines l svc drop=() head="#!/bin/sh" body="" was_x=1
  # A symlink to a file that is not there yet (rc.d layouts): the file is made
  # where it points, its folder first.
  if [[ -L "$f" && ! -e "$f" ]]; then
    local target; target="$(readlink "$f")"
    if [[ "$target" == /* ]]; then target="${VITRUM_ROOTFS:-}$target"; else target="$(dirname "$f")/$target"; fi
    run_ok sudo mkdir -p "$(dirname "$target")"       || { warn 'could not create %s, where /etc/rc.local points — nothing is changed at the next boot' "$target"; return 0; }
  fi
  if [[ -f "$f" ]]; then
    [[ -x "$f" ]] || was_x=0
    rest="$(awk -v b="$_RUNIT_BOOT_BEGIN" -v e="$_RUNIT_BOOT_END" -v mode=out "$_RUNIT_BLOCK_AWK" "$f")"
  fi
  if [[ "$rest" == '#!'* ]]; then head="${rest%%$'\n'*}"; [[ "$rest" == *$'\n'* ]] && body="${rest#*$'\n'}"
  else body="$rest"; fi
  for l in "$@"; do
    svc="${l##*/}"
    case "$l" in
      "ln -sfn "*) drop+=("rm -f /etc/runit/runsvdir/current/$svc") ;;
      "rm -f "*)   drop+=("ln -sfn /etc/sv/$svc /etc/runit/runsvdir/current/$svc") ;;
    esac
  done
  lines="$({ _runit_boot_lines | grep -vxF -f <(printf '%s\n' "${drop[@]}" ""); printf '%s\n' "$@"; } | awk 'NF && !seen[$0]++')"
  { printf '%s\n%s\n%s\n%s\n%s\n' "$head" "$_RUNIT_BOOT_BEGIN" "$lines" "$(_runit_boot_self_delete)" "$_RUNIT_BOOT_END"
    if [[ -n "$body" ]]; then printf '%s\n' "$body"; fi
  } | sudo_write "$f" 0755
  # Executable now, so the lines already in it run at boot too, which they did not before.
  (( was_x )) || info "/etc/rc.local was not executable: it is now, for the change at the next boot — the lines already in it will run at boot as well"
}

# Is <service> queued to be linked (or unlinked, with "rm") at the next boot?
# A here-string, not a pipe: grep -q stopping early would fail awk under pipefail.
_runit_pending() {
  local line="ln -sfn /etc/sv/$1 /etc/runit/runsvdir/current/$1"
  [[ "${2:-}" == rm ]] && line="rm -f /etc/runit/runsvdir/current/$1"
  grep -qxF "$line" <<<"$(_runit_boot_lines)"
}

# Like the OpenRC backend: nobody starts a session bus for us, and niri runs
# as a session instance so that it publishes its D-Bus interfaces.
session_exec_line() {
  # shellcheck disable=SC2016  # expanded by the session wrapper, not here
  printf '%s\n' 'if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then dbus-run-session /usr/local/bin/niri --session; else /usr/local/bin/niri --session; fi'
}

# Void has no PipeWire launcher and no user service manager by default, so the
# session starts PipeWire itself. Void's handbook has PipeWire start
# WirePlumber and the pulse server from /etc/pipewire/pipewire.conf.d: what is
# linked there is not started a second time. turnstile's user services
# (~/.config/service/pipewire) run it all already.
audio_bootstrap_line() {
  [[ -e "$HOME/.config/service/pipewire" ]] && return 0
  local conf="${VITRUM_SYSROOT:-}/etc/pipewire/pipewire.conf.d" after=""
  [[ -e "$conf/20-pipewire-pulse.conf" ]] || after+="pipewire-pulse & "
  [[ -e "$conf/10-wireplumber.conf" ]] || after+="wireplumber & "
  if [[ -z "$after" ]]; then printf 'spawn-at-startup "pipewire"\n'; return 0; fi
  # The others connect to PipeWire's socket, so they wait for it (five seconds at most).
  # shellcheck disable=SC2016  # expanded by the session's sh, not here
  printf 'spawn-at-startup "sh" "-c" "pipewire & for i in 1 2 3 4 5 6 7 8 9 10; do [ -S $XDG_RUNTIME_DIR/pipewire-0 ] && break; sleep 0.5; done; %swait"\n' "$after"
}

# No user units on runit: the session wrapper runs niri directly.
session_unit_install() { :; }

# PipeWire is started per session by audio_bootstrap_line.
audio_enable_user() { :; }

_RUNIT_DMS=(sddm lightdm gdm greetd lxdm slim ly emptty xdm lemurs nodm)

# The login screen runit starts: a linked one, unless the next boot replaces it.
dm_current() {
  local d
  for d in "${_RUNIT_DMS[@]}"; do _runit_pending "$d" && { printf '%s\n' "$d"; return 0; }; done
  for d in "${_RUNIT_DMS[@]}"; do
    _runit_linked "$d" && ! _runit_pending "$d" rm && { printf '%s\n' "$d"; return 0; }
  done
  return 0
}

# svc_enable_display_manager <dm> [force] — force takes the other login
# screens out; consent is checked in lib/dm.sh. Linked now, a login screen
# would start on top of the running install, and unlinking the current one
# would stop it and the session on it: with runit running, both wait for the
# next boot.
svc_enable_display_manager() {
  local dm="$1" d dir lines=()
  if ! svc_exists "$dm"; then warn 'no runit service %s — the login screen is not enabled' "$dm"; return 0; fi
  dir="$(_runit_svdir)"
  if [[ "${2:-}" == force ]]; then
    for d in "${_RUNIT_DMS[@]}"; do
      [[ "$d" != "$dm" ]] || continue
      if _runit_linked "$d" || _runit_pending "$d"; then lines+=("rm -f /etc/runit/runsvdir/current/$d"); fi
    done
  fi
  if ! _runit_running; then
    for d in "${lines[@]}"; do run_ok sudo rm -f "$dir/${d##*/}" || true; done
    _runit_linked "$dm" || run_ok sudo ln -s "/etc/sv/$dm" "$dir/$dm" || warn 'could not enable %s' "$dm"
    return 0
  fi
  # Linked already, but queued to go: the queue is told it stays.
  if ! _runit_linked "$dm" || _runit_pending "$dm" rm; then lines+=("ln -sfn /etc/sv/$dm /etc/runit/runsvdir/current/$dm"); fi
  [[ ${#lines[@]} -gt 0 ]] || return 0
  _runit_at_next_boot "${lines[@]}"
  info "login screen: $dm from the next boot (/etc/rc.local makes the switch)"
}

# The network clients Void may run, which fight NetworkManager over the
# interfaces: dhcpcd (also per interface, dhcpcd-eth0), wpa_supplicant (also
# per interface), iwd and ConnMan.
_runit_network_clients() {
  local dir f; dir="$(_runit_svdir)"
  for f in "$dir"/dhcpcd* "$dir"/wpa_supplicant* "$dir"/iwd "$dir"/connmand; do
    [[ -L "$f" || -d "$f" ]] && printf '%s\n' "${f##*/}"
  done
  return 0
}

# NetworkManager drives Wi-Fi through a backend. iwd, when it runs, stays and
# becomes that backend; wpa_supplicant's own service can go only because D-Bus
# starts wpa_supplicant for NetworkManager (Void's NetworkManager depends on
# the package, which ships that D-Bus service) — without that file it stays.
_RUNIT_WPA_DBUS=/usr/share/dbus-1/system-services/fi.w1.wpa_supplicant1.service

_runit_nm_iwd_backend() {
  local f="${VITRUM_ROOTFS:-}/etc/NetworkManager/conf.d/wifi_backend.conf"
  if [[ -e "$f" ]]; then
    grep -qs '^wifi.backend=iwd' "$f" || info "network: $f is there already and left as it is (NetworkManager should use iwd: wifi.backend=iwd)"
    return 0
  fi
  printf '# Written by the vitrum installer: iwd ran here, so NetworkManager drives Wi-Fi through it.\n[device]\nwifi.backend=iwd\n' | sudo_write "$f"
}

# With no other client linked, NetworkManager starts now; otherwise the switch
# waits for the next boot, as on OpenRC — switching under a running install
# would cut the network mid-build.
svc_use_networkmanager() {
  svc_exists NetworkManager || return 0
  local s clients=() drop=() keep=() lines=() wifi_rejoin=0
  mapfile -t clients < <(_runit_network_clients)
  if [[ ${#clients[@]} -eq 0 ]]; then svc_enable_system NetworkManager; return 0; fi
  local have_iwd=0
  for s in "${clients[@]}"; do [[ "$s" == iwd ]] && have_iwd=1; done
  for s in "${clients[@]}"; do
    case "$s" in
      iwd) keep+=("$s") ;;
      wpa_supplicant*)
        if (( have_iwd )) || [[ -e "${VITRUM_ROOTFS:-}$_RUNIT_WPA_DBUS" ]]; then drop+=("$s"); wifi_rejoin=1
        else keep+=("$s"); fi ;;
      *) drop+=("$s") ;;
    esac
  done
  (( have_iwd )) && _runit_nm_iwd_backend
  if ! _runit_running; then
    for s in "${drop[@]}"; do run_ok sudo rm -f "$(_runit_svdir)/$s" || true; done
    svc_enable_system NetworkManager
  else
    for s in "${drop[@]}"; do lines+=("rm -f /etc/runit/runsvdir/current/$s"); done
    _runit_linked NetworkManager || lines+=("ln -sfn /etc/sv/NetworkManager /etc/runit/runsvdir/current/NetworkManager")
    [[ ${#lines[@]} -gt 0 ]] && _runit_at_next_boot "${lines[@]}"
    info "network: NetworkManager from the next boot${drop[*]:+ (${drop[*]} leave then — they fight over the interfaces)}${keep[*]:+; ${keep[*]} stays}"
  fi
  if (( have_iwd )); then
    info "network: NetworkManager uses iwd for Wi-Fi (wifi.backend=iwd), which keeps running"
  elif (( wifi_rejoin )); then
    warn 'Wi-Fi: from the next boot NetworkManager runs it, and the networks wpa_supplicant knew are not carried over — join them again in the network panel or with nmtui'
  fi
  if [[ " ${keep[*]} " == *" wpa_supplicant"* ]] && (( ! have_iwd )); then
    warn 'Wi-Fi: wpa_supplicant keeps its own service — without its D-Bus service file (%s) NetworkManager would be left with no Wi-Fi backend' "$_RUNIT_WPA_DBUS"
  fi
  return 0
}

# For the doctor: is <service> linked, or queued for the next boot?
svc_enabled() { _runit_linked "$1" || _runit_pending "$1"; }
