# shellcheck shell=bash
# SDDM as the login screen — without silently taking over from another one.

# dm_use_sddm — enable SDDM. If another display manager is active, replace it
# only with consent (interactive "yes", or --replace-dm); the previous one is
# recorded for uninstall.sh. Under --yes the default is to keep it.
dm_use_sddm() {
  local cur; cur="$(dm_current)"
  if [[ "$cur" == sddm ]]; then ok "SDDM is already the login screen"; return 0; fi
  if [[ -z "$cur" ]]; then svc_enable_display_manager sddm; ok "SDDM enabled"; return 0; fi

  local replace=0
  if [[ "${REPLACE_DM:-0}" == 1 ]]; then replace=1
  elif [[ "${ASSUME_YES:-0}" != 1 && "${DRY_RUN:-0}" != 1 ]] && confirm "replace your login screen ($cur) with SDDM?" n; then replace=1
  fi
  if [[ $replace == 0 ]]; then
    warn "keeping $cur as the login screen — pick the \"vitrum\" session there (or re-run with --replace-dm)"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then dim "would replace $cur with sddm"; return 0; fi
  mkdir -p "$VITRUM_STATE"
  printf '%s\n' "$cur" > "$VITRUM_STATE/previous-dm"
  svc_enable_display_manager sddm force
  ok "SDDM replaces $cur (uninstall.sh puts $cur back)"
}
