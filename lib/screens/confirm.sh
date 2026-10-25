# shellcheck shell=bash
# ----------------------------------------------------- the confirmation -----
#
# After the choice screen: what will be installed and what will not, roughly
# how long it takes, that sudo is needed, and Install / Change / Cancel.
#
# The questions the stages used to ask halfway through (make fish the login
# shell, replace another login screen, go on with little disk space) are rows
# here, shown only when they apply, so the progress view never stops for an
# answer. Each row sets the variable the stage reads: WANT_LOGIN_SHELL,
# REPLACE_DM, ACCEPT_LOW_DISK. preflight_facts (00-preflight.sh) supplies
# the FACT_* values they depend on.
#
# In an update, CONFIRM_INSTALLED holds the parts that were installed before
# this run; one of them unticked now is "no longer managed", not "not".

# shellcheck source=lib/screens/choose.sh
source "$VITRUM_DIR/lib/screens/choose.sh"

# The time estimate comes from the progress view (lib/progress.sh), for the
# stages that will run: install.sh puts them in CONFIRM_STAGES. Without it,
# 0, and an estimate of 0 is not shown.
declare -F progress_estimate_total >/dev/null || progress_estimate_total() { printf '0\n'; }
declare -ga CONFIRM_STAGES

CONFIRM_ROWS=()
CONFIRM_TOGGLES=()
CONFIRM_CURSOR=0
CONFIRM_BUTTON=0
CONFIRM_BLOCKED=0
CONFIRM_INSTALLED="${CONFIRM_INSTALLED:-}"
# The questions shown when Install was chosen, so install.sh can tell an
# answer from a default nobody saw.
CONFIRM_ANSWERED=""

# The disk space the niri build wants, with some to spare.
CONFIRM_DISK_MB=6000

# _confirm_low_disk — 0 when the disk space row applies.
_confirm_low_disk() {
  [[ "${FACT_NIRI_BUILD:-0}" == 1 && "${FACT_FREE_MB:-0}" =~ ^[0-9]+$ ]] && (( FACT_FREE_MB < CONFIRM_DISK_MB ))
}

# confirm_init — the rows: install:, not: and unmanaged: with their ids, the
# estimate, sudo, and a toggle:<VAR> for each question that applies. The
# questions' variables keep a value given before (--replace-dm) and otherwise
# take their defaults. They are exported: the stages may run in a child bash.
confirm_init() {
  CONFIRM_ROWS=() CONFIRM_TOGGLES=() CONFIRM_CURSOR=0 CONFIRM_BUTTON=0 CONFIRM_BLOCKED=0
  : "${WANT_LOGIN_SHELL:=1}" "${REPLACE_DM:=0}" "${ACCEPT_LOW_DISK:=0}"
  export WANT_LOGIN_SHELL REPLACE_DM ACCEPT_LOW_DISK
  local id yes="" no="" gone=""
  for id in $(component_ids); do
    if [[ "$(component_get "$id")" == 1 ]]; then yes+=" $id"
    elif [[ " ${CONFIRM_INSTALLED:-} " == *" $id "* ]]; then gone+=" $id"
    else no+=" $id"
    fi
  done
  CONFIRM_ROWS+=("install:${yes# }")
  [[ -n "$no" ]] && CONFIRM_ROWS+=("not:${no# }")
  [[ -n "$gone" ]] && CONFIRM_ROWS+=("unmanaged:${gone# }")
  # The estimate is in seconds; the screen says minutes, rounded up.
  local est; est="$(progress_estimate_total "${CONFIRM_STAGES[@]}" 2>/dev/null)" || est=0
  [[ "$est" =~ ^[0-9]+$ ]] && (( est > 0 )) && CONFIRM_ROWS+=("estimate:$(( (est + 59) / 60 ))")
  CONFIRM_ROWS+=("sudo")

  if [[ "${FACT_FISH_IS_SHELL:-0}" != 1 && "${VITRUM_SHELL:-fish}" == fish ]]; then
    CONFIRM_TOGGLES+=(WANT_LOGIN_SHELL)
  fi
  if [[ "$(component_get sddm)" == 1 && -n "${FACT_DM:-}" ]]; then
    CONFIRM_TOGGLES+=(REPLACE_DM)
  fi
  _confirm_low_disk && CONFIRM_TOGGLES+=(ACCEPT_LOW_DISK)
  local var
  for var in "${CONFIRM_TOGGLES[@]}"; do CONFIRM_ROWS+=("toggle:$var"); done
  return 0
}

_confirm_shell_name() {
  if [[ -n "${FACT_SHELL:-}" ]]; then printf '%s' "${FACT_SHELL##*/}"; else T "unknown"; fi
}

# confirm_short <id> — a part's name in the summary, shorter than its row on
# the choice screen so the whole list takes a few lines.
confirm_short() {
  case "$1" in
    sddm)             T "Login screen" ;;
    plymouth)         T "Boot splash" ;;
    live_wallpaper)   T "Video wallpapers" ;;
    phone)            T "Phone" ;;
    tmux)             printf 'tmux' ;;
    games)            T "Game mode" ;;
    steam_theme)      T "Steam theme" ;;
    vesktop_theme)    T "Vesktop theme" ;;
    utilities)        T "Mic filter, VPN, sensors" ;;
    cli_tools)        printf 'eza, bat, fzf, zoxide, delta' ;;
    file_manager)     printf 'Dolphin' ;;
    ocr)              printf 'OCR' ;;
    author_nvim)      printf 'Neovim' ;;
    author_tmux_keys) T "the author's tmux keys" ;;
    tmux_autostart)   T "tmux autostart" ;;
    *)                choose_label "$1" ;;
  esac
}

# confirm_label <VAR> — a question's row.
confirm_label() {
  case "$1" in
    WANT_LOGIN_SHELL) T "Make fish my login shell (now %s)" "$(_confirm_shell_name)" ;;
    REPLACE_DM)       T "Replace %s with SDDM" "${FACT_DM:-}" ;;
    ACCEPT_LOW_DISK)  T "Only %sMB free, niri wants about 5GB: install anyway" "${FACT_FREE_MB:-0}" ;;
  esac
}

# confirm_hint <VAR> — what the row under the cursor means.
confirm_hint() {
  case "$1" in
    WANT_LOGIN_SHELL) T "Logins and new terminals start fish. Unticked, %s stays the login shell and kitty still opens fish." "$(_confirm_shell_name)" ;;
    REPLACE_DM)       T "SDDM with the vitrum theme becomes the login screen; uninstall.sh puts %s back. Unticked, pick the vitrum session in %s." "${FACT_DM:-}" "${FACT_DM:-}" ;;
    ACCEPT_LOW_DISK)  T "Building niri takes about 5GB in your home folder; with less it can fail halfway." ;;
    *)                T "The password for sudo is asked once, after Install." ;;
  esac
}

# confirm_key <key> — 0 to go on, 20 Install, 21 Change, 22 Cancel. The end
# of the input cancels: Change would send it back to the choice screen, and
# that one back here, for ever.
confirm_key() {
  local n=${#CONFIRM_TOGGLES[@]} var
  case "$1" in
    left)  CONFIRM_BUTTON=$(( (CONFIRM_BUTTON + 2) % 3 )) ;;
    right|tab) CONFIRM_BUTTON=$(( (CONFIRM_BUTTON + 1) % 3 )) ;;
    up)    (( CONFIRM_CURSOR > 0 )) && CONFIRM_CURSOR=$(( CONFIRM_CURSOR - 1 )) ;;
    down)  (( CONFIRM_CURSOR < n - 1 )) && CONFIRM_CURSOR=$(( CONFIRM_CURSOR + 1 )) ;;
    space)
      if (( n )); then
        var="${CONFIRM_TOGGLES[CONFIRM_CURSOR]}"
        if [[ "${!var:-0}" == 1 ]]; then printf -v "$var" 0; else printf -v "$var" 1; fi
      fi
      ;;
    esc)   return 21 ;;
    eof)   return 22 ;;
    enter)
      case "$CONFIRM_BUTTON" in
        0)
          # Too little room for the build is a refusal until the row says
          # install anyway: the hint says why nothing happened.
          if _confirm_low_disk && [[ "${ACCEPT_LOW_DISK:-0}" != 1 ]]; then CONFIRM_BLOCKED=1; return 0; fi
          return 20
          ;;
        1) return 21 ;;
        *) return 22 ;;
      esac
      ;;
  esac
  return 0
}

# _confirm_list <first> <rest> <width> <label…> — the labels as lines,
# broken between them, never inside one: the first line starts with first,
# the others with rest (spaces as wide as first).
_confirm_list() {
  local first="$1" rest="$2" width="$3" label line sep=" $TUI_G_SEP "
  shift 3
  line="$first"
  local fresh=1
  for label in "$@"; do
    if (( fresh )); then line+="$label"; fresh=0
    elif (( ${#line} + ${#sep} + ${#label} <= width )); then line+="$sep$label"
    else printf '%s\n' "$line"; line="$rest$label"
    fi
  done
  printf '%s\n' "$line"
}

# confirm_render — the frame, on stdout. On a short terminal the summary is
# cut first, so the questions and the buttons always stay on screen.
confirm_render() {
  local rows="${TUI_ROWS:-24}" cols="${TUI_COLS:-80}"
  local width=$(( cols < UI_WIDTH ? cols : UI_WIDTH ))
  local summary=() middle=() bottom=() row line

  # The label column of the summary.
  local l_yes l_no col
  l_yes="$(T "will install:")" l_no="$(T "not:")"
  col=$(( ${#l_yes} > ${#l_no} ? ${#l_yes} : ${#l_no} ))
  col=$(( col + 2 ))
  local pad_yes pad_no indent
  printf -v indent '%*s' $(( col + 2 )) ''
  tui_fit "$col" "$l_yes"; pad_yes="$_TUI_FIT"
  tui_fit "$col" "$l_no"; pad_no="$_TUI_FIT"

  local note="" ids=() labels=() id
  for row in "${CONFIRM_ROWS[@]}"; do
    labels=()
    case "$row" in
      install:*|not:*|unmanaged:*)
        read -ra ids <<<"${row#*:}"
        for id in "${ids[@]}"; do labels+=("$(confirm_short "$id")"); done
        ;;
    esac
    case "$row" in
      install:*)
        # The core first, then the picks and the parts, as one list.
        labels=("$(T "niri with liquid glass and the vitrum shell")" "${VITRUM_TERMINAL:-kitty}" "${VITRUM_SHELL:-fish}" "${labels[@]}")
        while IFS= read -r line; do summary+=("$line"); done \
          < <(_confirm_list "  $pad_yes" "$indent" "$width" "${labels[@]}")
        ;;
      not:*)
        while IFS= read -r line; do summary+=("$line"); done \
          < <(_confirm_list "  $pad_no" "$indent" "$width" "${labels[@]}")
        ;;
      unmanaged:*)
        local joined="" label
        for label in "${labels[@]}"; do joined+="${joined:+ $TUI_G_SEP }$label"; done
        while IFS= read -r line; do summary+=("  $line"); done \
          < <(tui_wrap $(( width - 4 )) "$(T "no longer managed: %s" "$joined")")
        ;;
      estimate:*) note="$(T "about %s min" "${row#estimate:}")" ;;
      sudo)       note+="${note:+ $TUI_G_SEP }$(T "needs sudo")" ;;
    esac
  done
  # One label longer than the line would be cut by the frame anyway; cut here
  # it ends with an ellipsis instead.
  local i
  for i in "${!summary[@]}"; do
    (( ${#summary[i]} > width )) && { tui_fit "$width" "${summary[i]}"; summary[i]="$_TUI_FIT"; }
  done

  # The questions.
  local n=${#CONFIRM_TOGGLES[@]} var mark text
  for (( i = 0; i < n; i++ )); do
    var="${CONFIRM_TOGGLES[i]}"
    if [[ "${!var:-0}" == 1 ]]; then mark="[x]"; else mark="[ ]"; fi
    tui_fit $(( width - 4 )) "$mark $(confirm_label "$var")"
    text="$_TUI_FIT"
    if (( i == CONFIRM_CURSOR )); then
      middle+=("$TUI_REV  $TUI_G_PTR $text$TUI_RESET")
    else
      middle+=("    $text")
    fi
  done

  # The hint: why Install did nothing, or what the row under the cursor means.
  local hint hint_max=2
  (( rows < 16 )) && hint_max=1
  if (( CONFIRM_BLOCKED )) && [[ "${ACCEPT_LOW_DISK:-0}" != 1 ]]; then
    hint="$C_YELLOW"
    _choose_hint_lines $(( width - 4 )) "$hint_max" "$(T "Tick the disk space row to install anyway, or free some space first.")"
  elif (( n )); then
    hint="$C_GREY"
    _choose_hint_lines $(( width - 4 )) "$hint_max" "$(confirm_hint "${CONFIRM_TOGGLES[CONFIRM_CURSOR]}")"
  else
    hint="$C_GREY"
    _choose_hint_lines $(( width - 4 )) "$hint_max" "$(confirm_hint "")"
  fi
  for line in "${_CHOOSE_HINT[@]}"; do bottom+=("  $hint$line$C_RESET"); done
  bottom+=("")

  # The buttons, the chosen one in brackets (and reverse video).
  local names=("$(T "Install")" "$(T "Change")" "$(T "Cancel")") b buttons="  "
  for b in 0 1 2; do
    if (( b == CONFIRM_BUTTON )); then buttons+="${TUI_REV}[ ${names[b]} ]$TUI_RESET  "
    else buttons+="  ${names[b]}    "
    fi
  done
  bottom+=("$buttons")
  # On a narrow terminal Esc goes unmentioned first: Change is a button too.
  local keys
  keys="$TUI_G_LR $(T "button")"
  (( n )) && keys+="  $TUI_G_UD $(T "row")  $(T "space") $(T "tick")"
  keys+="  Enter $(T "select")"
  local esc
  esc="  Esc $(T "change")"
  (( ${#keys} + ${#esc} <= width - 2 )) && keys+="$esc"
  bottom+=("  $C_DIM$keys$C_RESET")

  # Title, a blank, the summary, the note, a blank, the questions and a blank
  # when there are any, then the bottom. What does not fit comes off the
  # summary, its last line saying there was more.
  local fixed=$(( 3 + 1 + ${#bottom[@]} ))
  (( n )) && fixed=$(( fixed + n + 1 ))
  local room=$(( rows - fixed ))
  (( room < 1 )) && room=1
  if (( ${#summary[@]} > room )); then
    summary=("${summary[@]:0:room}")
    if _utf8_ok; then summary[room - 1]="${indent}…"; else summary[room - 1]="${indent}..."; fi
  fi

  printf '  %s%s%s\n\n' "$C_BOLD" "$(T "vitrum — ready to install")" "$C_RESET"
  printf '%s\n' "${summary[@]}"
  printf '  %s%s%s\n\n' "$C_DIM" "$note" "$C_RESET"
  if (( n )); then printf '%s\n' "${middle[@]}"; printf '\n'; fi
  printf '%s\n' "${bottom[@]}"
}

# confirm_run — the screen until a button: 0 Install, 1 Change (back to the
# choice screen), 2 Cancel. Draws on the terminal tui_begin opened, or opens it.
# On Install, CONFIRM_ANSWERED holds the questions that were on the screen.
confirm_run() {
  local own=0 rc=0
  if [[ "$_TUI_ON" != 1 ]]; then tui_begin || return 2; own=1; fi
  CONFIRM_ANSWERED=""
  confirm_init
  while :; do
    tui_size
    confirm_render > "$_TUI_FRAME"
    tui_frame "$_TUI_FRAME"
    _tui_read_key || true
    rc=0; confirm_key "$TUI_KEY" || rc=$?
    (( rc >= 20 )) && break
  done
  # shellcheck disable=SC2034  # read by install.sh
  (( rc == 20 )) && CONFIRM_ANSWERED="${CONFIRM_TOGGLES[*]}"
  if (( own )); then tui_end; fi
  return $(( rc - 20 ))
}
