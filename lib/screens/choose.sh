# shellcheck shell=bash
# ----------------------------------------------------------- the choice -----
#
# One screen with every optional part on it, grouped: the pick-one rows at
# the top (terminal, shell, fastfetch logo), then Desktop, Tools and Extras
# with a checkbox each, a hint for the row under the cursor at the bottom.
# In update mode it shows only the parts it is given (the new ones, and the
# ones still not installed), under their headings.
#
# The model (CHOOSE_ROWS, CHOOSE_CURSOR, CHOOSE_TOP and the component
# variables) is changed by choose_key and drawn by choose_render, which only
# prints, so both run in the tests without a terminal.

# shellcheck source=lib/tui.sh
source "$VITRUM_DIR/lib/tui.sh"

CHOOSE_ROWS=()
CHOOSE_CURSOR=0
CHOOSE_TOP=0
CHOOSE_UPDATE=0

# choose_label <id> — the row's text, for a part or a pick.
choose_label() {
  case "$1" in
    terminal)         T "Terminal" ;;
    shell)            T "Shell" ;;
    fastfetch_logo)   T "fastfetch logo" ;;
    sddm)             T "Login screen (SDDM)" ;;
    plymouth)         T "Boot splash (Plymouth)" ;;
    live_wallpaper)   T "Video wallpapers" ;;
    phone)            T "Phone (KDE Connect)" ;;
    tmux)             T "tmux, themed, with plugins" ;;
    games)            T "Game mode + HUD (gamemode, MangoHud)" ;;
    steam_theme)      T "Steam theme (Millennium)" ;;
    vesktop_theme)    T "Vesktop theme (Discord)" ;;
    utilities)        T "Mic noise filter, VPN, sensors, mixer, archives" ;;
    cli_tools)        T "Command-line tools: eza, bat, fzf, zoxide, delta" ;;
    file_manager)     T "File manager: Dolphin" ;;
    ocr)              T "Text from screenshots (OCR)" ;;
    author_nvim)      T "Neovim with the author's config" ;;
    author_tmux_keys) T "tmux: the author's keys (Ctrl+a, | and - splits)" ;;
    tmux_autostart)   T "Start tmux with every terminal" ;;
    *)                printf '%s' "$1" ;;
  esac
}

# choose_name <id> — a part's name where a whole label is too long: in "needs
# tmux" beside a row that cannot be ticked.
choose_name() {
  case "$1" in
    tmux)  printf 'tmux' ;;
    games) T "Game mode" ;;
    *)     choose_label "$1" ;;
  esac
}

# choose_heading <group>
choose_heading() {
  case "$1" in
    desktop) T "Desktop" ;;
    tools)   T "Tools" ;;
    extras)  T "Extras — the author's own setup" ;;
    *)       printf '%s' "$1" ;;
  esac
}

# choose_option_label <option> — one choice of a pick-one row.
choose_option_label() {
  case "$1" in
    picture) T "picture" ;;
    distro)  T "distribution logo" ;;
    *)       printf '%s' "$1" ;;
  esac
}

# pick_option_disabled <pick> <option> — 0 when that option cannot be chosen
# here. The picture logo needs a terminal that shows images; every terminal
# vitrum sets up today does, so nothing is disabled until other terminals come.
pick_option_disabled() {
  return 1
}

# The hint under the screen: what the part is (these were the questions'
# explanations before the screen), then why it cannot be ticked, if it cannot.
choose_hint() {
  local text req
  case "$1" in
    terminal)         text="$(T "The terminal vitrum sets up and colours from your wallpaper.")" ;;
    shell)            text="$(T "The shell in that terminal, with the Starship prompt.")" ;;
    fastfetch_logo)   text="$(T "What fastfetch shows beside the system facts: the vitrum picture or your distribution's logo.")" ;;
    sddm)             text="$(T "The login screen in the same style as the lock screen; other sessions stay listed.")" ;;
    plymouth)         text="$(T "A boot splash. The initramfs is regenerated with dracut or mkinitcpio, whichever builds it here.")" ;;
    live_wallpaper)   text="$(T "Live wallpapers through mpvpaper. Static ones work either way.")" ;;
    phone)            text="$(T "Notifications from the phone, its battery, a shared clipboard and files. Pulls in part of KDE Frameworks.")" ;;
    tmux)             text="$(T "tmux with a vitrum status bar and its plugins. Without the author's keys it keeps its own (Ctrl+b).")" ;;
    games)            text="$(T "Game mode with its HUD: gamemode and MangoHud.")" ;;
    steam_theme)      text="$(T "Steam theme: vitrum's look for Steam via Millennium, follows your colours.")" ;;
    vesktop_theme)    text="$(T "Vesktop theme: vitrum's glass for Discord (Vesktop), follows your colours.")" ;;
    utilities)        text="$(T "The microphone noise filter, WireGuard and OpenVPN, hardware sensors, a sound mixer (pavucontrol), cava and Ark for archives.")" ;;
    cli_tools)        text="$(T "Better ls, cat, find and cd: eza, bat, fzf and zoxide, with delta for git diffs.")" ;;
    file_manager)     text="$(T "Dolphin, themed like the rest of the desktop.")" ;;
    ocr)              text="$(T "Copy the text out of a screenshot, with tesseract. English always, Russian too on a Russian system.")" ;;
    author_nvim)      text="$(T "Neovim with the author's plugins and keymaps, and a colourscheme from the vitrum palette.")" ;;
    author_tmux_keys) text="$(T "Ctrl+a prefix, | and - split, H J K L resize, vi copy-mode. Unticked, tmux keeps its own keys (Ctrl+b).")" ;;
    tmux_autostart)   text="$(T "Opening a terminal drops you straight into a tmux session instead of a bare shell.")" ;;
    *)                text="" ;;
  esac
  req="${COMPONENT_REQUIRES[$1]:-}"
  if [[ -n "$req" && "$(component_get "$req")" == 0 ]]; then
    text+=" $(T "Needs %s ticked." "$(choose_label "$req")")"
  fi
  if [[ "$1" == fastfetch_logo ]] && pick_option_disabled fastfetch_logo picture; then
    text+=" $(T "%s cannot show images" "${VITRUM_TERMINAL:-kitty}")."
  fi
  printf '%s' "$text"
}

# _choose_blocked <id> — 0 when the part cannot be ticked: what it needs is off.
_choose_blocked() {
  local req="${COMPONENT_REQUIRES[$1]:-}"
  [[ -n "$req" && "$(component_get "$req")" == 0 ]]
}

# choose_init [id…] — the rows: the picks, then each group's heading and its
# parts. Given ids, only those parts and no picks (update mode).
choose_init() {
  CHOOSE_ROWS=() CHOOSE_CURSOR=0 CHOOSE_TOP=0 CHOOSE_UPDATE=0
  local only=" $* " entry id group last="" opts var
  (( $# )) && CHOOSE_UPDATE=1
  if (( ! CHOOSE_UPDATE )); then
    for entry in "${PICKS[@]}"; do
      IFS='|' read -r id var opts <<<"$entry"
      CHOOSE_ROWS+=("pick:$id")
    done
  fi
  for entry in "${COMPONENTS[@]}"; do
    IFS='|' read -r id group _ <<<"$entry"
    (( CHOOSE_UPDATE )) && [[ "$only" != *" $id "* ]] && continue
    [[ "$group" != "$last" ]] && { CHOOSE_ROWS+=("head:$group"); last="$group"; }
    CHOOSE_ROWS+=("item:$id")
  done
  # A part whose requirement is off is off too (flags can say --no-tmux
  # --tmux-autostart): the screen shows it unticked and greyed, and that is
  # what the stages will do.
  local dep
  for dep in "${!COMPONENT_REQUIRES[@]}"; do
    _choose_blocked "$dep" && component_set "$dep" 0
  done
  local i
  for i in "${!CHOOSE_ROWS[@]}"; do
    [[ "${CHOOSE_ROWS[i]}" != head:* ]] && { CHOOSE_CURSOR=$i; break; }
  done
  return 0
}

# _choose_pick_value <pick> — its value, or its first option while unset.
_choose_pick_value() {
  local var opts; var="$(_pick_var "$1")"; opts="$(_pick_options "$1")"
  printf '%s' "${!var:-${opts%% *}}"
}

# _choose_cycle <pick> <+1|-1> — the next option that can be chosen, round.
_choose_cycle() {
  local pick="$1" step="$2" var cur i n k
  var="$(_pick_var "$pick")"
  local -a opts; read -ra opts <<<"$(_pick_options "$pick")"
  n=${#opts[@]}
  (( n > 1 )) || return 0
  cur="$(_choose_pick_value "$pick")"
  for (( i = 0; i < n; i++ )); do [[ "${opts[i]}" == "$cur" ]] && break; done
  (( i < n )) || i=0
  for (( k = 1; k < n; k++ )); do
    local next="${opts[(i + step * k + n * k) % n]}"
    pick_option_disabled "$pick" "$next" && continue
    printf -v "$var" '%s' "$next"
    return 0
  done
  return 0
}

# _choose_set <id> <0|1> — set a part; off also turns off what needs it.
_choose_set() {
  local id="$1" v="$2" dep
  if [[ "$v" == 1 ]] && _choose_blocked "$id"; then return 0; fi
  component_set "$id" "$v"
  if [[ "$v" == 0 ]]; then
    for dep in "${!COMPONENT_REQUIRES[@]}"; do
      [[ "${COMPONENT_REQUIRES[$dep]}" == "$id" ]] && component_set "$dep" 0
    done
  fi
  return 0
}

# _choose_group <group> — the a key: tick every part of the group on the
# screen, or untick them all when every one that can be ticked already is.
_choose_group() {
  local group="$1" row id all=1
  for row in "${CHOOSE_ROWS[@]}"; do
    [[ "$row" == item:* ]] || continue
    id="${row#item:}"
    [[ "$(component_field "$id" group)" == "$group" ]] || continue
    _choose_blocked "$id" && continue
    [[ "$(component_get "$id")" == 1 ]] || { all=0; break; }
  done
  for row in "${CHOOSE_ROWS[@]}"; do
    [[ "$row" == item:* ]] || continue
    id="${row#item:}"
    [[ "$(component_field "$id" group)" == "$group" ]] || continue
    if (( all )); then _choose_set "$id" 0; else _choose_set "$id" 1; fi
  done
  return 0
}

# _choose_move <+1|-1> — to the next row that is not a heading, if there is one.
_choose_move() {
  local i=$CHOOSE_CURSOR
  while :; do
    i=$(( i + $1 ))
    (( i >= 0 && i < ${#CHOOSE_ROWS[@]} )) || return 0
    [[ "${CHOOSE_ROWS[i]}" == head:* ]] || { CHOOSE_CURSOR=$i; return 0; }
  done
}

# choose_key <key> — 0 to go on, 10 when Enter finishes, 11 when Esc goes
# back, 12 when the input ended (nobody is there: leave). The group key is
# a, or the same key on a Russian layout (ф).
choose_key() {
  local row="${CHOOSE_ROWS[CHOOSE_CURSOR]:-}" id
  id="${row#*:}"
  case "$1" in
    up)    _choose_move -1 ;;
    down)  _choose_move 1 ;;
    enter) return 10 ;;
    esc)   return 11 ;;
    eof)   return 12 ;;
    space)
      case "$row" in
        item:*) if [[ "$(component_get "$id")" == 1 ]]; then _choose_set "$id" 0; else _choose_set "$id" 1; fi ;;
        pick:*) _choose_cycle "$id" 1 ;;
      esac
      ;;
    right) [[ "$row" == pick:* ]] && _choose_cycle "$id" 1 ;;
    left)  [[ "$row" == pick:* ]] && _choose_cycle "$id" -1 ;;
    a|A|ф|Ф) [[ "$row" == item:* ]] && _choose_group "$(component_field "$id" group)" ;;
  esac
  return 0
}

# _choose_row_text <row> <width> — the row as plain text, width characters.
_choose_row_text() {
  local row="$1" width="$2" id="${1#*:}" text="" mark
  case "$row" in
    pick:*)
      local label opt cur
      label="$(choose_label "$id")"
      cur="$(_choose_pick_value "$id")"
      tui_fit "$_CHOOSE_PICK_W" "$label"
      text="$_TUI_FIT"
      for opt in $(_pick_options "$id"); do
        if pick_option_disabled "$id" "$opt"; then mark="(-)"
        elif [[ "$opt" == "$cur" ]]; then mark="($TUI_G_ON)"
        else mark="( )"
        fi
        text+="  $mark $(choose_option_label "$opt")"
      done
      text="    $text"
      ;;
    item:*)
      if [[ "$(component_get "$id")" == 1 ]]; then mark="[x]"; else mark="[ ]"; fi
      text="    $mark $(choose_label "$id")"
      _choose_blocked "$id" && text+="  ($(T "needs %s" "$(choose_name "${COMPONENT_REQUIRES[$id]}")"))"
      ;;
  esac
  tui_fit "$width" "$text"
}

# _choose_hint_lines <width> <lines> <text> — the text wrapped into exactly
# that many lines (_CHOOSE_HINT), the last one cut with an ellipsis when the
# text is longer, so the rows above never move with the hint.
_choose_hint_lines() {
  local width="$1" max="$2" line rest=""
  _CHOOSE_HINT=()
  while IFS= read -r line; do
    if (( ${#_CHOOSE_HINT[@]} < max )); then _CHOOSE_HINT+=("$line"); else rest+=" $line"; fi
  done < <(tui_wrap "$width" "$3")
  if [[ -n "$rest" ]]; then
    tui_fit "$width" "${_CHOOSE_HINT[max - 1]}$rest"
    _CHOOSE_HINT[max - 1]="$_TUI_FIT"
  fi
  while (( ${#_CHOOSE_HINT[@]} < max )); do _CHOOSE_HINT+=(""); done
  return 0
}

# choose_render — the frame, on stdout. Scrolls the rows (CHOOSE_TOP) so the
# cursor stays in view when they do not all fit, and keeps a heading in view
# with the first row under it.
choose_render() {
  local rows="${TUI_ROWS:-24}" cols="${TUI_COLS:-80}"
  local width=$(( cols < UI_WIDTH ? cols : UI_WIDTH ))
  local n=${#CHOOSE_ROWS[@]} cur="${CHOOSE_ROWS[CHOOSE_CURSOR]:-}"
  local id="${cur#*:}"

  # The pick labels share one column.
  local entry pid label
  _CHOOSE_PICK_W=0
  for entry in "${PICKS[@]}"; do
    pid="${entry%%|*}"
    label="$(choose_label "$pid")"
    (( ${#label} > _CHOOSE_PICK_W )) && _CHOOSE_PICK_W=${#label}
  done

  # The hint gets two lines on a terminal tall enough, one otherwise.
  local hint_max=2 hint_lines=() line
  (( rows < 16 )) && hint_max=1
  _choose_hint_lines $(( width - 4 )) "$hint_max" "$(choose_hint "$id")"
  hint_lines=("${_CHOOSE_HINT[@]}")

  # Title, hint and keys are fixed; a blank line under the title and one above
  # the hint only when there is room for them.
  local fixed=$(( 2 + hint_max )) gap_top=0 gap_bottom=0
  if (( n + fixed + 2 <= rows )); then gap_top=1 gap_bottom=1
  elif (( n + fixed + 1 <= rows )); then gap_top=1
  fi
  local height=$(( rows - fixed - gap_top - gap_bottom ))
  (( height < 1 )) && height=1
  if (( n <= height )); then
    CHOOSE_TOP=0
  else
    local first=$CHOOSE_CURSOR
    (( first > 0 )) && [[ "${CHOOSE_ROWS[first - 1]}" == head:* ]] && first=$(( first - 1 ))
    (( first < CHOOSE_TOP )) && CHOOSE_TOP=$first
    (( CHOOSE_CURSOR >= CHOOSE_TOP + height )) && CHOOSE_TOP=$(( CHOOSE_CURSOR - height + 1 ))
    (( CHOOSE_TOP > n - height )) && CHOOSE_TOP=$(( n - height ))
    (( CHOOSE_TOP < 0 )) && CHOOSE_TOP=0
  fi

  printf '  %s%s%s\n' "$C_BOLD" "$(T "vitrum — what to install")" "$C_RESET"
  (( gap_top )) && printf '\n'

  local i last=$(( CHOOSE_TOP + height - 1 )) row text
  (( last > n - 1 )) && last=$(( n - 1 ))
  for (( i = CHOOSE_TOP; i <= last; i++ )); do
    row="${CHOOSE_ROWS[i]}"
    if [[ "$row" == head:* ]]; then
      label="$(choose_heading "${row#head:}")"
      local rule_w=$(( width - 3 - ${#label} ))
      (( rule_w < 0 )) && rule_w=0
      text="  $label $(_repeat "$rule_w" "$TUI_G_RULE")"
    else
      _choose_row_text "$row" "$width"
      text="$_TUI_FIT"
    fi
    # More rows above or below: an arrow at the end of the first or last row.
    if (( i == CHOOSE_TOP && CHOOSE_TOP > 0 )); then text="${text:0:${#text}-1}$TUI_G_MORE_UP"
    elif (( i == last && last < n - 1 )); then text="${text:0:${#text}-1}$TUI_G_MORE_DOWN"
    fi
    if (( i == CHOOSE_CURSOR )); then
      # The rows start with four spaces; the pointer takes the third.
      printf '%s  %s %s%s\n' "$TUI_REV" "$TUI_G_PTR" "${text:4}" "$TUI_RESET"
    elif [[ "$row" == head:* ]]; then
      local cut=$(( 2 + ${#label} ))
      printf '%s%s%s%s%s\n' "$C_BOLD$C_BLUE" "${text:0:cut}" "$C_RESET$C_DIM" "${text:cut}" "$C_RESET"
    elif [[ "$row" == item:* ]] && _choose_blocked "${row#item:}"; then
      printf '%s%s%s\n' "$C_DIM" "$text" "$C_RESET"
    else
      printf '%s\n' "$text"
    fi
  done

  (( gap_bottom )) && printf '\n'
  for line in "${hint_lines[@]}"; do printf '  %s%s%s\n' "$C_GREY" "$line" "$C_RESET"; done
  printf '  %s%s%s\n' "$C_DIM" "$(_choose_keys "$cur" $(( width - 2 )))" "$C_RESET"
}

# _choose_keys <row> <width> — the keys that do something on this row. On a
# narrow terminal the group key is left out before anything is cut.
_choose_keys() {
  local first second="" last keys
  first="$TUI_G_UD $(T "move")"
  case "$1" in
    pick:*) first+="  $TUI_G_LR $(T "choose")" ;;
    item:*) first+="  $(T "space") $(T "tick")"; second="  a $(T "whole group")" ;;
  esac
  last="  Enter $(T "next")  Esc $(T "back")"
  keys="$first$second$last"
  (( ${#keys} > $2 )) && keys="$first$last"
  printf '%s' "$keys"
}

# choose_run [id…] — the screen until Enter (0), Esc (1) or the end of the
# input (2). Draws on the terminal tui_begin opened, or opens it for itself.
choose_run() {
  local own=0 rc=0
  if [[ "$_TUI_ON" != 1 ]]; then tui_begin || return 1; own=1; fi
  choose_init "$@"
  while :; do
    tui_size
    choose_render > "$_TUI_FRAME"
    tui_frame "$_TUI_FRAME"
    _tui_read_key || true
    rc=0; choose_key "$TUI_KEY" || rc=$?
    (( rc >= 10 )) && break
  done
  if (( own )); then tui_end; fi
  return $(( rc - 10 ))
}
