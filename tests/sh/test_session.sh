# shellcheck shell=bash disable=SC1090,SC1091
_load_session() {
  export INIT_BACKEND="$1"
  source "$VITRUM_DIR/lib/common.sh"; source "$VITRUM_DIR/lib/backend/init-$1.sh"
  source "$VITRUM_DIR/lib/stages/80-session.sh"
  stub sudo '"$@"'
  export VITRUM_SYSROOT="$HOME/sys"   # system files land here in tests
}

test_session_wrapper_openrc_uses_dbus_run_session() {
  _load_session openrc
  _session_wrapper
  w="$VITRUM_SYSROOT/usr/local/bin/vitrum-session"
  assert_contains "$(cat "$w")" "dbus-run-session"
  assert_contains "$(cat "$w")" 'NIRI_CONFIG="$HOME/.config/vitrum/niri/config.kdl"'
  sh -n "$w"
}
test_session_wrapper_systemd_uses_session_flag() {
  _load_session systemd
  _session_wrapper
  assert_contains "$(cat "$VITRUM_SYSROOT/usr/local/bin/vitrum-session")" "start niri.service"
}
test_desktop_entry_names_vitrum() {
  _load_session openrc
  _session_wrapper
  assert_contains "$(cat "$VITRUM_SYSROOT/usr/local/share/wayland-sessions/niri.desktop")" "Name=niri"
}
test_session_kdl_is_idempotent() {
  _load_session openrc
  stub gentoo-pipewire-launcher; stub rc-update 'exit 0'
  _session_spawns; _session_spawns
  f="$VITRUM_PREFIX/niri/generated/session.kdl"
  assert_eq "$(grep -c 'vitrum-startup' "$f")" 1
  assert_contains "$(cat "$f")" "gentoo-pipewire-launcher"
  # The clipboard history goes through vitrum-clip (no count limit on text).
  assert_eq "$(grep -c 'watch vitrum-clip store' "$f")" 2
}
test_config_has_includes_and_no_tahoe() {
  _load_session openrc
  printf '# Binds\n' > "$HOME/kb.md"; export VITRUM_KEYBINDS_MD="$HOME/kb.md"
  _session_config
  c="$(cat "$VITRUM_PREFIX/niri/config.kdl")"
  assert_contains "$c" 'include "generated/session.kdl"'
  assert_contains "$c" 'include optional=true "generated/look.kdl"'
  assert_contains "$c" 'include optional=true "overrides.kdl"'
  ! grep -qi tahoe <<<"$c"
  ! grep -q '@BINDS@\|@LAYER_EFFECTS@\|@WALLPAPER_DAEMON@' <<<"$c"
}
test_startup_script_is_valid_bash() {
  _load_session openrc
  _session_startup_script
  bash -n "$HOME/.local/bin/vitrum-startup"
  assert_contains "$(cat "$HOME/.local/bin/vitrum-startup")" "vitrum-shell"
  assert_contains "$(cat "$HOME/.local/bin/vitrum-startup")" "dbus-update-activation-environment"
}
test_migration_copies_known_keys_once() {
  _load_session openrc
  mkdir -p "$XDG_CONFIG_HOME/niri-tahoe"
  printf '{"weather":{"latitude":55.7,"longitude":37.6},"dock":{"autohide":true},"glass":{"materiality":0.3}}' > "$XDG_CONFIG_HOME/niri-tahoe/settings.json"
  migrate_tahoe_settings
  s="$(cat "$VITRUM_PREFIX/settings.json")"
  assert_contains "$s" '"latitude": 55.7'
  assert_contains "$s" '"migratedFrom": "niri-tahoe"'
  ! grep -q materiality <<<"$s"
  printf '{"mine":1}' > "$VITRUM_PREFIX/settings.json"
  migrate_tahoe_settings
  assert_eq "$(cat "$VITRUM_PREFIX/settings.json")" '{"mine":1}'
}

test_niri_environment_keeps_the_desktop_name() {
  # niri --session resets XDG_CURRENT_DESKTOP; the config's environment block puts it back. It is niri.
  assert_contains "$(cat "$VITRUM_DIR/config/niri/config.kdl.in")" 'XDG_CURRENT_DESKTOP "niri"'
}
test_migration_snapshot_is_not_in_the_restore_manifest() {
  _load_session openrc
  mkdir -p "$XDG_CONFIG_HOME/niri-tahoe"; printf '{"weather":{"latitude":1}}' > "$XDG_CONFIG_HOME/niri-tahoe/settings.json"
  migrate_tahoe_settings
  ! grep -q "niri-tahoe" "$XDG_DATA_HOME/vitrum/originals/.manifest" 2>/dev/null
  [[ -f "$XDG_DATA_HOME/vitrum/migrated/niri-tahoe-settings.json" ]]
}
test_migration_still_runs_over_the_empty_settings_the_shell_stage_wrote() {
  _load_session openrc
  mkdir -p "$XDG_CONFIG_HOME/niri-tahoe" "$VITRUM_PREFIX"
  printf '{"weather":{"latitude":55.7}}' > "$XDG_CONFIG_HOME/niri-tahoe/settings.json"
  printf '{}' > "$VITRUM_PREFIX/settings.json"
  migrate_tahoe_settings
  assert_contains "$(cat "$VITRUM_PREFIX/settings.json")" '"latitude": 55.7'
}

# niri sessions read niri-portals.conf; without it the system portals.conf
# (default=*) also tries backends that are not running here (hyprland), and
# every portal call from a starting app can wait for a D-Bus timeout.
test_session_writes_niri_portal_preferences() {
  _load_session openrc
  _session_portals
  c="$(cat "$XDG_CONFIG_HOME/xdg-desktop-portal/niri-portals.conf")"
  assert_contains "$c" "default=gtk"
  ! grep -q "hyprland\|=\*" <<<"$c"
  ! grep -q "gnome;" <<<"$c"
  # A Secret backend makes xdg-desktop-portal activate org.freedesktop.secrets
  # at start; when gnome-keyring runs on another bus that waits out the 25 s
  # D-Bus timeout, and every Qt app (the shell first) waits with it.
  ! grep -q "Secret" <<<"$c" || { echo "$c"; return 1; }
}
# Screen sharing (Discord, browsers): vitrum's own backend, with the shell's
# picker, over niri's screencast interface — whatever else is installed.
test_session_portals_share_the_screen_through_vitrum() {
  _load_session openrc
  _session_portals
  c="$(cat "$XDG_CONFIG_HOME/xdg-desktop-portal/niri-portals.conf")"
  assert_contains "$c" "org.freedesktop.impl.portal.ScreenCast=vitrum"
  ! grep -q "ScreenCast=gnome" <<<"$c"
  [[ -x "$VITRUM_SYSROOT/usr/local/libexec/vitrum/vitrum-portal" && -f "$VITRUM_SYSROOT/usr/local/libexec/vitrum/vitrum_portal.py" ]]
  p="$(cat "$VITRUM_SYSROOT/usr/share/xdg-desktop-portal/portals/vitrum.portal")"
  assert_contains "$p" "DBusName=org.freedesktop.impl.portal.desktop.vitrum"
  assert_contains "$p" "Interfaces=org.freedesktop.impl.portal.ScreenCast"
  assert_contains "$(cat "$VITRUM_SYSROOT/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.vitrum.service")" \
    "Exec=/usr/local/libexec/vitrum/vitrum-portal"
}
# niri publishes its screencast interface only as a session instance.
test_session_openrc_runs_niri_as_a_session() {
  _load_session openrc
  assert_contains "$(session_exec_line)" "/usr/local/bin/niri --session"
}
# niri runs xwayland-satellite itself and gives programs DISPLAY; a
# `DISPLAY null` in the environment block took it away again, and X11 apps
# (Steam) had nowhere to go.
test_niri_config_leaves_display_to_niri() {
  ! grep -qE '^\s*DISPLAY\s' "$VITRUM_DIR/config/niri/config.kdl.in" || { grep -n DISPLAY "$VITRUM_DIR/config/niri/config.kdl.in"; return 1; }
}
# After a logout SDDM's switch back to its VT got lost while the session was
# still closing: the greeter came up on an inactive VT and the screen stayed
# black. The wrapper hands the VT back itself, while it still may.
test_session_wrapper_returns_to_the_login_vt() {
  _load_session openrc
  _session_wrapper
  w="$(cat "$VITRUM_SYSROOT/usr/local/bin/vitrum-session")"
  assert_contains "$w" "org.freedesktop.login1.Seat SwitchTo u"
  ! grep -qE '^\s*(if .*then )?exec .*niri' <<<"$w" || { echo "the compositor is exec'd, nothing runs after it"; return 1; }
  sh -n "$VITRUM_SYSROOT/usr/local/bin/vitrum-session"
}
test_session_wrapper_systemd_returns_to_the_login_vt() {
  _load_session systemd
  _session_wrapper
  assert_contains "$(cat "$VITRUM_SYSROOT/usr/local/bin/vitrum-session")" "org.freedesktop.login1.Seat SwitchTo u"
}

test_overrides_starter_written_once_and_kept() {
  _load_session openrc
  _session_overrides
  f="$VITRUM_PREFIX/niri/overrides.kdl"
  assert_contains "$(cat "$f")" "// binds {"
  assert_contains "$(cat "$f")" "Mouse & touchpad"
  printf 'binds { Mod+T { spawn "foot"; } }\n' > "$f"
  _session_overrides
  assert_eq "$(cat "$f")" 'binds { Mod+T { spawn "foot"; } }'
  if grep -qs "overrides.kdl" "$BACKUP_DIR/.manifest"; then echo "overrides.kdl must not be in the manifest"; return 1; fi
}
test_input_kdl_included_before_overrides() {
  _load_session openrc
  _session_config
  c="$(cat "$VITRUM_PREFIX/niri/config.kdl")"
  assert_contains "$c" 'include optional=true "generated/input.kdl"'
  i="$(grep -n 'generated/input.kdl' <<<"$c" | cut -d: -f1)"; o="$(grep -n '"overrides.kdl"' <<<"$c" | cut -d: -f1)"
  [[ "$i" -lt "$o" ]] || { echo "input.kdl must come before overrides.kdl"; return 1; }
}
test_keybinds_reapply_settings_through_vitrum_theme() {
  _load_session openrc
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\necho "$@" > "%s/theme-args"\n' "$HOME" > "$HOME/.local/bin/vitrum-theme"
  chmod +x "$HOME/.local/bin/vitrum-theme"
  _session_keybinds
  assert_contains "$(cat "$HOME/theme-args")" "--no-color-scheme"
}
