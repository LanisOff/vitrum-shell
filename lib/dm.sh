# shellcheck shell=bash
# SDDM as the login screen — without silently taking over from another one.

# dm_use_sddm — enable SDDM. If another display manager is active, replace it
# only with consent: REPLACE_DM, set by the confirmation screen's row or by
# --replace-dm, asked before any stage ran. The previous one is recorded for
# uninstall.sh. Without that consent (and so under --yes) it is kept.
dm_use_sddm() {
  local cur; cur="$(dm_current)"
  if [[ "$cur" == sddm ]]; then ok "SDDM is already the login screen"; return 0; fi
  if [[ -z "$cur" ]]; then svc_enable_display_manager sddm; ok "SDDM enabled"; return 0; fi

  if [[ "${REPLACE_DM:-0}" != 1 ]]; then
    warn 'keeping %s as the login screen — pick the "vitrum" session there (or re-run with --replace-dm)' "$cur"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then dim "would replace $cur with sddm"; return 0; fi
  mkdir -p "$VITRUM_STATE"
  printf '%s\n' "$cur" > "$VITRUM_STATE/previous-dm"
  svc_enable_display_manager sddm force
  ok "SDDM replaces $cur (uninstall.sh puts $cur back)"
}
