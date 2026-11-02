# shellcheck shell=bash
# SDDM as the login screen — without silently taking over from another one.

# lightdm_sees_vitrum <root> — 0 when LightDM looks where our entry is. Built
# for /usr, it looks in /usr/share only unless sessions-directory says more. The
# last setting wins, and it reads lightdm.conf after lightdm.conf.d. Awk with
# [ \t], not [[:space:]]: an older mawk has no such classes.
lightdm_sees_vitrum() {
  local dirs
  dirs="$(cat "$1"/etc/lightdm/lightdm.conf.d/*.conf "$1"/etc/lightdm/lightdm.conf 2>/dev/null \
    | awk '/^[ \t]*\[/ { in_lightdm = /^[ \t]*\[LightDM\]/; next }
           in_lightdm && /^[ \t]*sessions-directory[ \t]*=/ { sub(/^[^=]*=/, ""); v = $0 }
           END { print v }')" || true
  case ":${dirs//[[:space:]]/}:" in
    *:/usr/local/share/wayland-sessions:*|*:/usr/local/share/wayland-sessions/:*) return 0 ;;
  esac
  return 1
}

# dm_use_sddm — enable SDDM. If another display manager is active, replace it
# only with consent: REPLACE_DM, set by the confirmation screen's row or by
# --replace-dm, asked before any stage ran. The previous one is recorded for
# uninstall.sh. Without that consent (and so under --yes) it is kept.
dm_use_sddm() {
  local cur; cur="$(dm_current)"
  if [[ "$cur" == sddm ]]; then ok "SDDM is already the login screen"; return 0; fi
  if [[ -z "$cur" ]]; then svc_enable_display_manager sddm; ok "SDDM enabled"; return 0; fi

  if [[ "${REPLACE_DM:-0}" != 1 ]]; then
    if [[ "$cur" == lightdm ]] && ! lightdm_sees_vitrum "${VITRUM_ROOTFS:-}"; then
      warn 'keeping lightdm as the login screen — it does not list vitrum yet: add /usr/local/share/wayland-sessions to sessions-directory in /etc/lightdm/lightdm.conf (or re-run with --replace-dm)'
    else
      warn 'keeping %s as the login screen — pick the "vitrum" session there (or re-run with --replace-dm)' "$cur"
    fi
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then dim "would replace $cur with sddm"; return 0; fi
  mkdir -p "$VITRUM_STATE"
  printf '%s\n' "$cur" > "$VITRUM_STATE/previous-dm"
  svc_enable_display_manager sddm force
  ok "SDDM replaces $cur (uninstall.sh puts $cur back)"
}
