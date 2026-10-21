# shellcheck shell=bash
# --------------------------------------------------------- the language -----
#
# The first screen: English or Russian, with the device's language under the
# cursor. Its own words are in both languages at once, as nothing is chosen
# yet. Shown once; the choice is stored with the components.

# shellcheck source=lib/tui.sh
source "$VITRUM_DIR/lib/tui.sh"

LANGUAGE_CODES=(en ru)
LANGUAGE_NAMES=("English" "Русский")
LANGUAGE_CURSOR=0

# language_render — the frame, on stdout.
language_render() {
  local i
  printf '  %svitrum%s\n\n' "$C_BOLD" "$C_RESET"
  printf '  Choose a language %s Выберите язык\n\n' "$TUI_G_SEP"
  for i in "${!LANGUAGE_CODES[@]}"; do
    if (( i == LANGUAGE_CURSOR )); then
      tui_fit 12 "${LANGUAGE_NAMES[i]}"
      printf '%s  %s %s%s\n' "$TUI_REV" "$TUI_G_PTR" "$_TUI_FIT" "$TUI_RESET"
    else
      printf '    %s\n' "${LANGUAGE_NAMES[i]}"
    fi
  done
  printf '\n  %s%s  Enter  %s  Esc: quit %s выход%s\n' "$C_DIM" "$TUI_G_UD" "$TUI_G_SEP" "$TUI_G_SEP" "$C_RESET"
}

# language_run — sets VITRUM_LANG. Esc, or the end of the input, leaves the
# installer (status 130, as for Ctrl+C), with the terminal given back first.
language_run() {
  local own=0 i guess
  if [[ "$_TUI_ON" != 1 ]]; then tui_begin || return 1; own=1; fi
  guess="$(i18n_guess)"
  LANGUAGE_CURSOR=0
  for i in "${!LANGUAGE_CODES[@]}"; do [[ "${LANGUAGE_CODES[i]}" == "$guess" ]] && LANGUAGE_CURSOR=$i; done
  while :; do
    tui_size
    language_render > "$_TUI_FRAME"
    tui_frame "$_TUI_FRAME"
    _tui_read_key || true
    case "$TUI_KEY" in
      up)    (( LANGUAGE_CURSOR > 0 )) && LANGUAGE_CURSOR=$(( LANGUAGE_CURSOR - 1 )) ;;
      down)  (( LANGUAGE_CURSOR < ${#LANGUAGE_CODES[@]} - 1 )) && LANGUAGE_CURSOR=$(( LANGUAGE_CURSOR + 1 )) ;;
      enter) break ;;
      esc|eof) tui_end; exit 130 ;;
    esac
  done
  VITRUM_LANG="${LANGUAGE_CODES[LANGUAGE_CURSOR]}"
  export VITRUM_LANG
  if (( own )); then tui_end; fi
  return 0
}
