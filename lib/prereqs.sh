# shellcheck shell=bash
# The start-of-run look at what vitrum needs from outside the repository:
# packages and the fetched fonts. A partial run (--from, --only, --skip) skips
# the stages that bring them, and a missing one is only noticed much later.
#
# Needs install.sh's should_run and CHECK_ONLY (--check: no stage runs at all).

# prereqs_check — report what is missing; put it back unless the stage that
# normally does so runs in this very run. DRY_RUN=1 only lists.
prereqs_check() {
  local needs=() p a
  local pkgs=() assets=()
  local stage_pk=0 stage_fn=0
  if [[ "${CHECK_ONLY:-0}" != 1 ]]; then
    should_run packages && stage_pk=1
    should_run fonts && stage_fn=1
  fi

  mapfile -t needs < <(_package_needs)
  while IFS= read -r p; do
    [[ -n "$p" ]] && { pkg_installed "$p" || pkgs+=("$p"); }
  done < <(packages_for "${needs[@]}" 2>/dev/null)
  while IFS= read -r a; do
    [[ -n "$a" ]] && { asset_missing "$a" && assets+=("$a"); }
  done < <(assets_wanted)

  if [[ ${#pkgs[@]} -eq 0 && ${#assets[@]} -eq 0 ]]; then
    ok "packages and fonts: ok"
    return 0
  fi

  if [[ ${#pkgs[@]} -gt 0 ]]; then
    if [[ $stage_pk == 1 ]]; then
      info "${#pkgs[@]} missing packages: ${pkgs[*]}, the packages stage installs them"
    elif [[ "$DRY_RUN" == "1" ]]; then
      dim "${#pkgs[@]} missing packages: ${pkgs[*]}, would install them"
    else
      step "${#pkgs[@]} missing packages: ${pkgs[*]}, installing them"
      sudo_keepalive
      pkg_prepare
      local gone=() q
      mapfile -t gone < <(pkg_unavailable "${pkgs[@]}")
      if [[ ${#gone[@]} -gt 0 ]]; then
        warn '%s' "$(pkg_unavailable_message "${gone[@]}")"
        local keep=()
        for p in "${pkgs[@]}"; do
          for q in "${gone[@]}"; do [[ "${p%@*}" == "$q" ]] && continue 2; done
          keep+=("$p")
        done
        pkgs=("${keep[@]}")
      fi
      if [[ ${#pkgs[@]} -gt 0 ]]; then
        pkg_apply_use
        pkg_install "${pkgs[@]}"
        ok "packages installed"
      fi
    fi
  fi

  if [[ ${#assets[@]} -gt 0 ]]; then
    if [[ $stage_fn == 1 ]]; then
      info "${#assets[@]} missing fonts: ${assets[*]}, the fonts stage fetches them"
    elif [[ "$DRY_RUN" == "1" ]]; then
      dim "${#assets[@]} missing fonts: ${assets[*]}, would fetch them"
    else
      step "${#assets[@]} missing fonts: ${assets[*]}, fetching them"
      _prereqs_fetch_tools
      for a in "${assets[@]}"; do fetch_asset "$a"; done
      font_cache_refresh
    fi
  fi
  return 0
}

# What fetching and unpacking the assets takes. When the packages stage is
# still to come, a fresh system can lack it (Void's base has no xz and no
# unzip), so it goes in first, on its own.
_prereqs_fetch_tools() {
  local tools=() p
  while IFS= read -r p; do
    [[ -n "$p" ]] && { pkg_installed "$p" || tools+=("$p"); }
  done < <(packages_named curl xz unzip 2>/dev/null)
  [[ ${#tools[@]} -gt 0 ]] || return 0
  step "first what unpacks them: ${tools[*]}"
  sudo_keepalive
  pkg_prepare
  pkg_install "${tools[@]}"
}
