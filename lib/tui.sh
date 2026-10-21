# shellcheck shell=bash
# ------------------------------------------------------------------ tui -----
#
# The terminal under the installer's screens, in plain bash: a fresh system
# has no gum, whiptail or dialog, and the screens come before the packages
# stage. Raw keys come from stty, the drawing is escape codes on the
# alternate screen, so the scrollback is left as it was when the screens end.
#
# Everything is drawn on fd 3, opened on /dev/tty by tui_begin: the installer's
# stdout goes through tee into the log, and the log must never hold a screen.
# Tests point TUI_OUT at a file for the drawing and TUI_IN at a file of keys
# (or a pipe); both only with VITRUM_TEST=1 (lib/common.sh).
#
# Needs lib/common.sh (the colours and _utf8_ok).

[[ -n "${_VITRUM_TUI_LOADED:-}" ]] && return 0
_VITRUM_TUI_LOADED=1

_TUI_ON=0
_TUI_STTY=""
_TUI_FRAME=""
_TUI_IN_FD=""
_TUI_IN_PATH=""
_TUI_TRAPS=()
TUI_KEY=""

# Reverse video marks the cursor. It is an attribute, not a colour, so it stays
# under NO_COLOR: without it nobody could tell where the cursor is.
# shellcheck disable=SC2034  # these and the glyphs below are read by the screens
TUI_REV=$'\e[7m'
TUI_RESET=$'\e[0m'

# The glyphs the screens draw with, and their ASCII forms for a run without
# any UTF-8 locale (see common.sh), where these would print as escapes.
# shellcheck disable=SC2034
if _utf8_ok; then
  TUI_G_PTR='›' TUI_G_ON='•' TUI_G_SEP='·' TUI_G_RULE='─'
  TUI_G_UD='↑↓' TUI_G_LR='←→' TUI_G_MORE_UP='↑' TUI_G_MORE_DOWN='↓'
else
  TUI_G_PTR='>' TUI_G_ON='*' TUI_G_SEP='-' TUI_G_RULE='-'
  TUI_G_UD='up/down' TUI_G_LR='left/right' TUI_G_MORE_UP='^' TUI_G_MORE_DOWN='v'
fi

# tui_available — 0 only when the screens can be shown: a terminal to read
# keys from and draw on, stdout on a terminal when the run started (VITRUM_TTY
# survives install.sh's tee), a TERM that understands escape codes, and no
# --yes. Without a controlling terminal (ssh -T, a container, curl | bash
# under setsid) opening /dev/tty fails at once rather than hanging. Stdin is
# not asked about: the keys come from /dev/tty, and under curl | bash stdin is
# the pipe the script came through.
#
# VITRUM_FORCE_TUI=1 is a test hook: with TUI_IN and TUI_OUT pointing at files
# the screens run with no terminal at all, as the tests of install.sh need.
# Like the others it works only with VITRUM_TEST=1 (lib/common.sh).
tui_available() {
  [[ "${ASSUME_YES:-0}" == 1 ]] && return 1
  if [[ "${VITRUM_FORCE_TUI:-}" == 1 && -n "${TUI_IN:-}" && -n "${TUI_OUT:-}" ]]; then return 0; fi
  # An unset TERM says as little about escape codes as dumb does.
  [[ -n "${TERM:-}" && "$TERM" != dumb ]] || return 1
  [[ -t 1 || "${VITRUM_TTY:-}" == 1 ]] || return 1
  { : <>/dev/tty; } 2>/dev/null || return 1
  return 0
}

# tui_begin — raw keys, no echo, the cursor hidden, the alternate screen.
# Ctrl+C and a kill give the terminal back before the installer goes, and an
# EXIT trap set before (the sudo keepalive's) still runs after this one. The
# traps are in place before the terminal modes change: a Ctrl+C that comes in
# between must still find something to put them back.
tui_begin() {
  [[ "$_TUI_ON" == 1 ]] && return 0
  if [[ -n "${TUI_OUT:-}" ]]; then
    exec 3>>"$TUI_OUT" || return 1
  else
    { exec 3>/dev/tty; } 2>/dev/null || return 1
  fi
  _TUI_STTY=""
  if [[ -z "${TUI_IN:-}" ]]; then
    _TUI_STTY="$(stty -g </dev/tty 2>/dev/null)" || _TUI_STTY=""
  fi
  _TUI_TRAPS=("$(trap -p EXIT)" "$(trap -p INT)" "$(trap -p TERM)")
  local prev; prev="$(trap_cmd EXIT)"
  # shellcheck disable=SC2064  # the earlier command is meant to be fixed now
  trap "tui_end exit${prev:+; $prev}" EXIT
  trap '_tui_signal 130' INT
  trap '_tui_signal 143' TERM
  _TUI_ON=1
  if [[ -n "$_TUI_STTY" ]]; then
    stty -echo -icanon min 1 time 0 </dev/tty 2>/dev/null || true
  fi
  _TUI_FRAME="$(mktemp "${TMPDIR:-/tmp}/vitrum-frame.XXXXXX")" || _TUI_FRAME=""
  printf '\e[?1049h\e[?25l\e[H\e[2J' >&3
}

# A signal ends the screens and then the installer, with the usual status
# (128 + the signal); the EXIT trap given back by tui_end runs on the way out.
_tui_signal() {
  tui_end
  exit "$1"
}

# tui_end — undo tui_begin: cursor, main screen, terminal modes, traps. Safe to
# call twice. From the EXIT trap itself (tui_end exit) the traps are left as
# they are, as that trap is already running the earlier one.
tui_end() {
  [[ "$_TUI_ON" == 1 ]] || return 0
  _TUI_ON=0
  printf '\e[0m\e[?25h\e[?1049l' >&3 2>/dev/null || true
  if [[ -n "$_TUI_STTY" ]]; then
    stty "$_TUI_STTY" </dev/tty 2>/dev/null || stty sane </dev/tty 2>/dev/null || true
  fi
  exec 3>&-
  if [[ -n "$_TUI_IN_FD" ]]; then
    exec {_TUI_IN_FD}<&-
    _TUI_IN_FD="" _TUI_IN_PATH=""
  fi
  [[ -n "$_TUI_FRAME" ]] && rm -f "$_TUI_FRAME"
  _TUI_FRAME=""
  [[ "${1:-}" == exit ]] && return 0
  local i sigs=(EXIT INT TERM)
  for i in 0 1 2; do
    if [[ -n "${_TUI_TRAPS[i]:-}" ]]; then eval "${_TUI_TRAPS[i]}"; else trap - "${sigs[i]}"; fi
  done
  return 0
}

# tui_size — TUI_ROWS and TUI_COLS from the terminal, 24×80 when it cannot
# say. A test drawing to TUI_OUT keeps the size it set.
tui_size() {
  if [[ -n "${TUI_OUT:-}" ]]; then
    TUI_ROWS="${TUI_ROWS:-24}" TUI_COLS="${TUI_COLS:-80}"
    return 0
  fi
  local size rows="" cols=""
  size="$(stty size </dev/tty 2>/dev/null)" || size=""
  read -r rows cols <<<"$size" || true
  [[ "$rows" =~ ^[1-9][0-9]*$ ]] || rows=24
  [[ "$cols" =~ ^[1-9][0-9]*$ ]] || cols=80
  TUI_ROWS="$rows" TUI_COLS="$cols"
}

# The keys come from one descriptor kept open between reads, so a file of keys
# is read in order rather than from its start every time.
_tui_in_open() {
  local want="${TUI_IN:-/dev/tty}"
  if [[ -n "$_TUI_IN_FD" && "$_TUI_IN_PATH" == "$want" ]]; then return 0; fi
  if [[ -n "$_TUI_IN_FD" ]]; then exec {_TUI_IN_FD}<&-; _TUI_IN_FD=""; fi
  { exec {_TUI_IN_FD}<"$want"; } 2>/dev/null || { _TUI_IN_FD=""; return 1; }
  _TUI_IN_PATH="$want"
}

# _tui_read_key — one key into TUI_KEY, in this shell (no subshell, so the
# screens' loops keep the input's place). 1 at the end of the input, with
# TUI_KEY=eof: the screens take that as cancel or quit, never as Esc, which
# goes back a screen. Two screens sending each other back on every eof would
# spin for ever once the terminal went away.
_tui_read_key() {
  TUI_KEY=""
  _tui_in_open || { TUI_KEY=eof; return 1; }
  local c="" c2="" seq=""
  IFS= read -rN1 -u "$_TUI_IN_FD" c || { TUI_KEY=eof; return 1; }
  case "$c" in
    $'\e')
      # An arrow is ESC [ A or, in application mode, ESC O A, all at once; an
      # ESC with nothing after it within 50 ms is the Esc key.
      if ! IFS= read -rN1 -t 0.05 -u "$_TUI_IN_FD" c2; then TUI_KEY=esc; return 0; fi
      if [[ "$c2" != '[' && "$c2" != O ]]; then TUI_KEY=esc; return 0; fi
      # The rest of the sequence: parameters, then one final letter or ~.
      while IFS= read -rN1 -t 0.05 -u "$_TUI_IN_FD" c2; do
        seq+="$c2"
        [[ "$c2" == [A-Za-z~] ]] && break
      done
      case "$seq" in
        A|*\;*A) TUI_KEY=up ;;
        B|*\;*B) TUI_KEY=down ;;
        C|*\;*C) TUI_KEY=right ;;
        D|*\;*D) TUI_KEY=left ;;
        Z)       TUI_KEY=tab ;;
        *)       TUI_KEY="" ;;
      esac
      ;;
    ' ')           TUI_KEY=space ;;
    $'\n'|$'\r')   TUI_KEY=enter ;;
    $'\t')         TUI_KEY=tab ;;
    $'\x7f'|$'\b') TUI_KEY=backspace ;;
    *)             TUI_KEY="$c" ;;
  esac
  return 0
}

# tui_key — read one key and print its name: up down left right space enter
# esc tab backspace eof, or the character itself. A key the screens have no use
# for (Delete, F1…) prints an empty line.
tui_key() {
  local rc=0
  _tui_read_key || rc=$?
  printf '%s\n' "$TUI_KEY"
  return "$rc"
}

# tui_flush — drop the keys typed while nothing was asking (an Enter pressed
# during a long build), so they do not answer the next question unread. A
# test's file of keys is its script, every key meant for a question; a pipe
# is fed as a terminal is, keys typed ahead included, and is flushed.
tui_flush() {
  [[ -n "${TUI_IN:-}" && ! -p "$TUI_IN" ]] && return 0
  _tui_in_open || return 0
  local c
  while IFS= read -rN1 -t 0.01 -u "$_TUI_IN_FD" c; do :; done
  return 0
}

# _tui_cut <line> <cells> — the line cut to that many cells into _TUI_CUT, its
# width into _TUI_CUT_W. Colour codes (ESC[…m) take no cells; a line that was
# cut and had any ends with a reset so the colour does not run on.
_tui_cut() {
  local s="$1" max="$2" plain="$1" re_m=$'\e\\[[0-9;]*m' re_seq=$'^\e\\[[0-9;?]*[A-Za-z]'
  while [[ "$plain" =~ $re_m ]]; do plain="${plain//"${BASH_REMATCH[0]}"/}"; done
  if (( ${#plain} <= max )); then
    _TUI_CUT="$s" _TUI_CUT_W=${#plain}
    return 0
  fi
  local out="" w=0 i=0 n=${#s} c had=0 rest
  while (( i < n && w < max )); do
    c="${s:i:1}"
    if [[ "$c" == $'\e' ]]; then
      rest="${s:i:32}"
      if [[ "$rest" =~ $re_seq ]]; then
        out+="${BASH_REMATCH[0]}"; i=$(( i + ${#BASH_REMATCH[0]} )); had=1
        continue
      fi
    fi
    out+="$c"; w=$((w + 1)); i=$((i + 1))
  done
  (( had )) && out+="$TUI_RESET"
  _TUI_CUT="$out" _TUI_CUT_W=$w
}

# tui_frame <file> — paint a prepared frame from the top left, each line cut
# to TUI_COLS and no more lines than TUI_ROWS. Each line clears what an older,
# longer frame left after it, and the rest of the screen is cleared below:
# repainting in place does not flicker the way clearing first does. A line
# that fills the row is not followed by a clear, which would erase its last
# cell (the cursor waits on it), and the last row never gets a newline, which
# would scroll the screen.
tui_frame() {
  local file="$1" rows="${TUI_ROWS:-24}" cols="${TUI_COLS:-80}" line out=$'\e[H' n=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    (( n >= rows )) && break
    (( n )) && out+=$'\n'
    _tui_cut "$line" "$cols"
    out+="$_TUI_CUT"
    (( _TUI_CUT_W < cols )) && out+=$'\e[K'
    n=$((n + 1))
  done < "$file"
  (( n < rows )) && out+=$'\n\e[J'
  printf '%s' "$out" >&3
}

# tui_wrap <width> <text> — the text in lines of at most width characters,
# broken between words; one word longer than that is left for the frame to cut.
tui_wrap() {
  local width="$1" word line="" words=()
  # Split into words without globbing (a hint with a * in it stays a *), and
  # across lines: read alone would stop at the first newline.
  read -d '' -ra words <<<"$2" || true
  for word in "${words[@]}"; do
    if [[ -z "$line" ]]; then line="$word"
    elif (( ${#line} + 1 + ${#word} <= width )); then line+=" $word"
    else printf '%s\n' "$line"; line="$word"
    fi
  done
  [[ -n "$line" ]] && printf '%s\n' "$line"
  return 0
}

# tui_fit <width> <text> — the text padded with spaces, or cut with an
# ellipsis, to exactly width characters (plain text, no colour codes), into
# _TUI_FIT. Not printf's %-*s: that counts bytes, and Cyrillic is two a letter.
tui_fit() {
  local width="$1" s="$2" pad=""
  if (( ${#s} > width )); then
    if _utf8_ok; then s="${s:0:width-1}…"; else s="${s:0:width}"; fi
  fi
  (( ${#s} < width )) && printf -v pad '%*s' $(( width - ${#s} )) ''
  _TUI_FIT="$s$pad"
}
