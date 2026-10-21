# shellcheck shell=bash
# ------------------------------------------------------- the final screen -----
#
# What the run did, printed on the main screen once the progress view has
# gone, so it stays in the scrollback and lands in the log: what is installed
# and what is not, the stages skipped and what they took with them, what went
# wrong, the first steps, the log. No buttons: nothing more is asked.

# shellcheck source=lib/screens/confirm.sh
source "$VITRUM_DIR/lib/screens/confirm.sh"
# shellcheck source=lib/progress.sh
source "$VITRUM_DIR/lib/progress.sh"

# _finish_list <label> <label…> — "  Label: a · b · c", wrapped under itself.
_finish_list() {
  local head="$1" indent
  shift
  (( $# )) || return 0
  tui_fit $(( ${#head} + 1 )) "$head"
  printf -v indent '%*s' $(( ${#head} + 3 )) ''
  _confirm_list "  $_TUI_FIT" "$indent" "$UI_WIDTH" "$@"
}

# _finish_lines <file> — its lines, each once, in the order they came.
_finish_lines() {
  [[ -s "$1" ]] || return 0
  awk 'NF && !seen[$0]++' "$1"
}

# The stages that put each part in place (FINISH_STAGES[id]): the packages
# stage installs what every part needs, and some parts are set up by a later
# stage as well. The pick rows terminal and shell are the terminal stage's.
declare -gA FINISH_STAGES=(
  [terminal]="packages terminal" [shell]="packages terminal"
  [sddm]="packages boot" [plymouth]="packages boot"
  [tmux]="packages terminal" [author_nvim]="packages terminal"
  [author_tmux_keys]=terminal [tmux_autostart]=terminal
  [games]="packages shell"
)

# _finish_part_state <id> — installed, skipped (a stage of it was skipped or
# could not run) or absent (a stage of it was not in this run, and the part
# was not there from before).
_finish_part_state() {
  local id="$1" key st absent=0
  for key in ${FINISH_STAGES[$id]:-packages}; do
    if [[ " ${PROGRESS_STAGES[*]} " == *" $key "* ]]; then
      st="$(_progress_status "$key")"
      [[ "$st" == skip || "$st" == needs || "$st" == fail ]] && { printf 'skipped'; return 0; }
    else
      absent=1
    fi
  done
  # A stage not in this run did its work on an earlier one, for a part that
  # was there before (an update with --only); on a first install it did not.
  if (( absent )) && { [[ "${INSTALL_MODE:-fresh}" == fresh ]] || \
       [[ "$id" != terminal && "$id" != shell && " ${CONFIRM_INSTALLED:-} " != *" $id "* ]]; }; then
    printf 'absent'; return 0
  fi
  printf 'installed'
}

# finish_render — the final screen, on stdout.
finish_render() {
  local ver="${REPO_VERSION:-$(vitrum_repo_version)}" title took=""
  if [[ "${INSTALL_MODE:-fresh}" == fresh ]]; then title="$(T "vitrum %s is installed" "$ver")"
  else title="$(T "vitrum %s is updated" "$ver")"
  fi
  [[ "${RUN_STARTED:-}" =~ ^[0-9]+$ ]] && took="$(T "took %s" "$(_progress_clock $(( $(date +%s) - RUN_STARTED )))")"
  printf '\n  %s%s%s%s\n\n' "$C_BOLD" "$title" "$C_RESET" "${took:+  $C_DIM$TUI_G_SEP $took$C_RESET}"

  # What is there and what is not. Unticked now but installed before is no
  # longer managed: nothing was removed. Ticked is not enough to be listed as
  # installed: the stages that put the part in place must have run, and run
  # cleanly.
  local id yes=() no=() gone=() label
  for id in terminal shell $(component_ids); do
    case "$id" in
      terminal) label="${VITRUM_TERMINAL:-kitty}" ;;
      shell)    label="${VITRUM_SHELL:-fish}" ;;
      *)        label="$(confirm_short "$id")" ;;
    esac
    if [[ "$id" == terminal || "$id" == shell || "$(component_get "$id")" == 1 ]]; then
      case "$(_finish_part_state "$id")" in
        installed) yes+=("$label") ;;
        skipped)   no+=("$(T "%s (skipped)" "$label")") ;;
        *)         no+=("$(T "%s (not in this run)" "$label")") ;;
      esac
    elif [[ " ${CONFIRM_INSTALLED:-} " == *" $id "* ]]; then gone+=("$label")
    else no+=("$label")
    fi
  done
  _finish_list "$(T "Installed:")" "${yes[@]}"
  _finish_list "$(T "Not installed:")" "${no[@]}"
  if (( ${#gone[@]} )); then
    local joined="" g
    for g in "${gone[@]}"; do joined+="${joined:+ $TUI_G_SEP }$g"; done
    tui_wrap $(( UI_WIDTH - 4 )) "$(T "no longer managed: %s" "$joined")" | sed 's/^/  /'
  fi

  # The stages skipped, what could not run without them, and how to run them
  # later: the one stage alone, or from it on when others waited for it.
  local key line deps n names how
  for key in "${PROGRESS_STAGES[@]}"; do
    [[ "$(_progress_status "$key")" == skip ]] || continue
    line="$(T "Skipped: %s" "$(STAGE_LABEL "$key")")"
    deps="$(progress_needs_of "$key")"
    how="./install.sh --only $key"
    if [[ -n "$deps" ]]; then
      names=""
      for n in $deps; do names+="${names:+, }$(STAGE_LABEL "$n")"; done
      line+=" — $(T "not run without it: %s" "$names")"
      how="./install.sh --from $key"
    fi
    printf '\n'
    tui_wrap $(( UI_WIDTH - 4 )) "$line" | sed "s/^/  $C_YELLOW/; s/\$/$C_RESET/"
    printf '  %s\n' "$(T "To run it later: %s" "$how")"
  done

  # What went wrong, each line once.
  local errs warns
  errs="$(_finish_lines "${VITRUM_RUN_DIR:-/nonexistent}/errors")"
  warns="$(_finish_lines "${VITRUM_RUN_DIR:-/nonexistent}/warnings")"
  if [[ -n "$errs$warns" ]]; then
    printf '\n  %s%s%s\n' "$C_BOLD" "$(T "What did not go cleanly")" "$C_RESET"
    [[ -n "$errs" ]] && while IFS= read -r line; do printf '  %s%s%s %s\n' "$C_RED" "$G_ERR" "$C_RESET" "$line"; done <<<"$errs"
    [[ -n "$warns" ]] && while IFS= read -r line; do printf '  %s%s%s %s\n' "$C_YELLOW" "$G_WARN" "$C_RESET" "$line"; done <<<"$warns"
  fi

  printf '\n  %s%s%s\n' "$C_BOLD" "$(T "First steps")" "$C_RESET"
  [[ "${INSTALL_MODE:-fresh}" == fresh ]] && printf '    %s\n' "$(T "Log out, then pick vitrum on the login screen.")"
  printf '    %s%-14s%s %s\n' "$C_BLUE" "Mod+/" "$C_RESET" "$(T "every shortcut")"
  printf '    %s%-14s%s %s\n' "$C_BLUE" "Mod+Space" "$C_RESET" "$(T "search apps and files")"
  printf '    %s%-14s%s %s\n' "$C_BLUE" "Mod+Alt+W" "$C_RESET" "$(T "edit desktop widgets")"
  printf '    %s%-14s%s %s\n' "$C_BLUE" "vitrum update" "$C_RESET" "$(T "when the bar says there is something new")"

  printf '\n  %s%s%s\n\n' "$C_DIM" "$(T "Log: %s" "${VITRUM_LOG:-}")" "$C_RESET"
}

# finish_run — the final screen. It only prints: the run is over.
finish_run() {
  finish_render
}
