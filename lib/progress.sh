# shellcheck shell=bash
# ------------------------------------------------------------- progress -----
#
# The progress view: one line per stage, the running one opened up with the
# last lines of its output, and a bar with the time left. A stage that fails
# stops the view with Retry / Skip this stage / Show log / Quit.
#
# Each stage runs in a background subshell, so its die ends the stage and not
# the installer. Its output goes through tee into the log, whole, as before,
# and into $VITRUM_RUN_DIR/<key>.out, whose tail the view shows. The view
# itself is drawn on the terminal (fd 3) and never reaches the log. Small
# files beside the output carry what the parent cannot see across the
# subshell: <key>.status (running, ok, fail, skip, needs), .start, .time,
# .step (the step text, from step), .error (die's message), .needs and .asked
# (it was stopped for asking on the terminal), and the run's warnings and
# errors (from warn and err).
#
# Needs lib/common.sh.

[[ -n "${_VITRUM_PROGRESS_LOADED:-}" ]] && return 0
_VITRUM_PROGRESS_LOADED=1

# shellcheck source=lib/tui.sh
source "$VITRUM_DIR/lib/tui.sh"

# Each stage's file under lib/stages (or an absolute path, as the tests give);
# the function in it is always stage_<key>.
declare -gA STAGE_FILE=(
  [preflight]=00-preflight.sh [packages]=10-packages.sh [fonts]=20-fonts.sh
  [niri]=30-niri.sh [shell]=40-shell.sh [apps]=50-apps.sh
  [terminal]=45-terminal.sh [theming]=60-theming.sh [boot]=70-boot.sh
  [session]=80-session.sh [doctor]=90-doctor.sh
)

# What a stage cannot do without: everything that installs from packages,
# the apps that run in the shell, the session that starts niri and the shell.
# A stage whose need was skipped or failed in this run is not run.
declare -gA STAGE_NEEDS=(
  [niri]=packages [shell]=packages [apps]=shell [terminal]=packages
  [theming]=packages [boot]=packages [session]="niri shell"
)

# The doctor reports problems, it does not fix them: its non-zero status is a
# report for the final screen, as it was before (stage_doctor || true).
declare -gA STAGE_SOFT=([doctor]=1)

PROGRESS_STAGES=()
declare -gA PROGRESS_EST=()
_PROGRESS_PID=""
_PROGRESS_TICK=0
_PROGRESS_FAILED=""
_PROGRESS_BUTTON=0
# Until when (SECONDS) the failure prompt takes no letters, and the stage
# being stopped gently after Ctrl+C (the bottom line says so).
_PROGRESS_GUARD=0
_PROGRESS_STOPPING=""

# The spinner and the bar, with ASCII forms for a run without UTF-8.
if _utf8_ok; then
  _PROGRESS_SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) _PROGRESS_PENDING='·' _PROGRESS_SKIP='–'
  _PROGRESS_FULL='█' _PROGRESS_EMPTY='░' _PROGRESS_BAR='│'
else
  # shellcheck disable=SC1003  # a backslash, not an escaped quote
  _PROGRESS_SPIN=('|' '/' '-' '\') _PROGRESS_PENDING='.' _PROGRESS_SKIP='-'
  _PROGRESS_FULL='#' _PROGRESS_EMPTY='.' _PROGRESS_BAR='|'
fi

# STAGE_LABEL <key> — the stage's name on the screens.
STAGE_LABEL() {
  case "$1" in
    preflight) T "Checks" ;;
    packages)  T "Packages" ;;
    fonts)     T "Fonts" ;;
    niri)      T "niri" ;;
    shell)     T "Shell" ;;
    apps)      T "Apps" ;;
    terminal)  T "Terminal" ;;
    theming)   T "Theming" ;;
    boot)      T "Boot" ;;
    session)   T "Session" ;;
    doctor)    T "Doctor" ;;
    *)         printf '%s' "$1" ;;
  esac
}

# progress_estimate <key> — roughly how many seconds the stage takes. A rough
# table is enough: the view corrects it by how fast this machine has been.
progress_estimate() {
  local s
  case "$1" in
    preflight) s=3 ;;   packages) s=180 ;; fonts) s=20 ;;  niri) s=600 ;;
    shell)     s=15 ;;  apps) s=10 ;;      terminal) s=40 ;; theming) s=10 ;;
    boot)      s=60 ;;  session) s=20 ;;   doctor) s=10 ;;   *) s=10 ;;
  esac
  if [[ "${PKG_BACKEND:-}" == portage ]]; then
    # Gentoo builds what Arch downloads.
    case "$1" in packages) s=3600 ;; niri) s=900 ;; esac
  fi
  if [[ "$1" == niri ]]; then
    # shellcheck source=lib/stages/30-niri.sh
    declare -F niri_needs_build >/dev/null || source "$VITRUM_DIR/lib/stages/30-niri.sh"
    niri_needs_build || s=5
  fi
  printf '%s\n' "$s"
}

# progress_estimate_total <stage…> — their estimates added up, in seconds.
progress_estimate_total() {
  local key sum=0
  for key in "$@"; do sum=$(( sum + $(progress_estimate "$key") )); done
  printf '%s\n' "$sum"
}

# _progress_clock <seconds> — 0:42, 12:05, 1:02:03.
_progress_clock() {
  local t="${1:-0}"
  [[ "$t" =~ ^[0-9]+$ ]] || t=0
  if (( t >= 3600 )); then
    printf '%d:%02d:%02d' $(( t / 3600 )) $(( t % 3600 / 60 )) $(( t % 60 ))
  else
    printf '%d:%02d' $(( t / 60 )) $(( t % 60 ))
  fi
}

# _progress_read <key> <what> — the content of <key>.<what>, empty if none.
_progress_read() {
  local f="${VITRUM_RUN_DIR:-}/$1.$2" v=""
  [[ -f "$f" ]] && v="$(<"$f")"
  printf '%s' "$v"
}

# _progress_status <key> — running, ok, fail, skip, needs or pending.
_progress_status() {
  local st; st="$(_progress_read "$1" status)"
  printf '%s' "${st:-pending}"
}

# progress_all_ok — 0 when every stage of the run ended ok.
progress_all_ok() {
  local key
  for key in "${PROGRESS_STAGES[@]}"; do
    [[ "$(_progress_status "$key")" == ok ]] || return 1
  done
  return 0
}

# _progress_cut <text> <cells> — the text, cut with an ellipsis to fit.
_progress_cut() {
  local s="$1" max="$2"
  (( max < 1 )) && { printf ''; return 0; }
  if (( ${#s} > max )); then
    if _utf8_ok; then s="${s:0:max-1}…"; else s="${s:0:max}"; fi
  fi
  printf '%s' "$s"
}

# _progress_tail <file> <n> — the last n lines of the output that have
# anything on them, into _PROGRESS_TAIL. A progress meter's \r rewrites keep
# only their last state; colours and other escapes are dropped, since the
# frame cuts lines by their width and an escape cut in half would garble it.
_progress_tail() {
  local file="$1" n="$2" line all=() re=$'\e\\[[0-9;?]*[ -/]*[@-~]'
  _PROGRESS_TAIL=()
  [[ -s "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line##*$'\r'}"
    while [[ "$line" =~ $re ]]; do line="${line//"${BASH_REMATCH[0]}"/}"; done
    line="${line//$'\t'/  }"
    line="${line//[[:cntrl:]]/}"
    [[ -n "${line//[[:space:]]/}" ]] || continue
    all+=("$line")
  done < <(tail -n 40 "$file" 2>/dev/null)
  local k=$(( ${#all[@]} - n ))
  (( k < 0 )) && k=0
  _PROGRESS_TAIL=("${all[@]:k}")
  return 0
}

# _progress_left <now> — the minutes left: what is still to run, by the
# estimates, times how this machine has done so far against them (elapsed /
# estimated, held to 0.5–3 so one odd stage does not swing it wildly).
_progress_left() {
  local now="$1" key st est t done_est=0 done_t=0 rest=0 run_est=0 run_el=0
  for key in "${PROGRESS_STAGES[@]}"; do
    est="${PROGRESS_EST[$key]:-}"
    [[ -n "$est" ]] || est="$(progress_estimate "$key")"
    st="$(_progress_status "$key")"
    case "$st" in
      ok|fail)
        t="$(_progress_read "$key" time)"; [[ "$t" =~ ^[0-9]+$ ]] || t=0
        done_est=$(( done_est + est )) done_t=$(( done_t + t )) ;;
      running)
        t="$(_progress_read "$key" start)"; [[ "$t" =~ ^[0-9]+$ ]] || t=$now
        run_est=$est run_el=$(( now - t )) ;;
      pending) rest=$(( rest + est )) ;;
    esac
  done
  local ratio=100
  (( done_est > 0 )) && ratio=$(( done_t * 100 / done_est ))
  (( ratio < 50 )) && ratio=50
  (( ratio > 300 )) && ratio=300
  local run_left=$(( run_est * ratio / 100 - run_el ))
  (( run_left < 0 )) && run_left=0
  local left=$(( rest * ratio / 100 + run_left ))
  local min=$(( (left + 59) / 60 ))
  (( min < 1 )) && min=1
  printf '%s' "$min"
}

# progress_needs_of <key> — the stages that did not run, directly or through
# another, because this one was skipped. For the final screen.
progress_needs_of() {
  local want=" $1 " key grew=1 needs n out=()
  while (( grew )); do
    grew=0
    for key in "${PROGRESS_STAGES[@]}"; do
      [[ "$(_progress_status "$key")" == needs && "$want" != *" $key "* ]] || continue
      needs="$(_progress_read "$key" needs)"
      for n in $needs; do
        if [[ "$want" == *" $n "* ]]; then want+="$key "; out+=("$key"); grew=1; break; fi
      done
    done
  done
  (( ${#out[@]} )) && printf '%s\n' "${out[@]}"
  return 0
}

# _progress_buttons — the failure prompt's choices.
_progress_buttons() {
  _PROGRESS_NAMES=("$(T "Retry")" "$(T "Skip this stage")" "$(T "Show log")" "$(T "Quit")")
}

# progress_render — the frame, on stdout: the header, a line per stage (the
# running or failed one opened up), then the bar, or under a failure the
# prompt's buttons.
progress_render() {
  local rows="${TUI_ROWS:-24}" cols="${TUI_COLS:-80}"
  local width=$(( cols < UI_WIDTH ? cols : UI_WIDTH ))
  local now; now="$(date +%s)"
  _PROGRESS_TICK=$(( _PROGRESS_TICK + 1 ))

  local key label lw=0
  for key in "${PROGRESS_STAGES[@]}"; do
    label="$(STAGE_LABEL "$key")"
    (( ${#label} > lw )) && lw=${#label}
  done
  # glyph, label, state, time: "  ✓ Label   state   12:05"
  local tw=7 sw
  sw=$(( width - 4 - lw - 2 - 1 - tw ))
  (( sw < 0 )) && sw=0

  local lines=() opened=-1 st glyph state t cut pad="" done_n=0 total=${#PROGRESS_STAGES[@]}
  for key in "${PROGRESS_STAGES[@]}"; do
    st="$(_progress_status "$key")"
    label="$(STAGE_LABEL "$key")"
    state="" t=""
    case "$st" in
      ok)      glyph="$C_GREEN$G_OK$C_RESET"; t="$(_progress_read "$key" time)"; done_n=$((done_n + 1)) ;;
      fail)    glyph="$C_RED$G_ERR$C_RESET"; t="$(_progress_read "$key" time)"; state="$(T "failed")"; done_n=$((done_n + 1)) ;;
      skip)    glyph="$C_YELLOW$_PROGRESS_SKIP$C_RESET"; state="$(T "skipped")"; done_n=$((done_n + 1)) ;;
      needs)
        glyph="$C_YELLOW$_PROGRESS_SKIP$C_RESET"; done_n=$((done_n + 1))
        local n names=""
        for n in $(_progress_read "$key" needs); do names+="${names:+, }$(STAGE_LABEL "$n")"; done
        state="$(T "skipped: needs %s" "$names")"
        ;;
      running)
        glyph="$C_BLUE${_PROGRESS_SPIN[_PROGRESS_TICK % ${#_PROGRESS_SPIN[@]}]}$C_RESET"
        state="$(_progress_read "$key" step)"
        local started; started="$(_progress_read "$key" start)"
        [[ "$started" =~ ^[0-9]+$ ]] && t=$(( now - started ))
        ;;
      *)       glyph="$C_DIM$_PROGRESS_PENDING$C_RESET" ;;
    esac
    [[ -n "$t" ]] && t="$(_progress_clock "$t")"
    tui_fit "$lw" "$label"; label="$_TUI_FIT"
    tui_fit "$sw" "$(_progress_cut "$state" "$sw")"; state="$_TUI_FIT"
    printf -v pad '%*s' "$tw" "$t"
    if [[ "$st" == pending ]]; then
      lines+=("  $glyph $C_DIM$label$C_RESET  $state $pad")
    else
      lines+=("  $glyph $label  $C_GREY$state$C_RESET $C_DIM$pad$C_RESET")
    fi
    # The stage that runs, or the one that failed, shows its last lines.
    if [[ "$st" == running || ( "$st" == fail && "$key" == "$_PROGRESS_FAILED" ) ]]; then
      opened=${#lines[@]}
      local e="" _PROGRESS_SHOWN=()
      if [[ "$st" == fail ]]; then
        e="$(_progress_read "$key" error)"
        if [[ -n "$e" ]]; then
          local el
          while IFS= read -r el; do lines+=("    $C_RED$el$C_RESET"); done < <(tui_wrap $(( width - 4 )) "$e" | head -n 3)
        fi
      fi
      _progress_tail "$VITRUM_RUN_DIR/$key.out" 4
      for cut in "${_PROGRESS_TAIL[@]}"; do
        # die's own line repeats the error just shown above.
        [[ "$st" == fail && -n "${e:-}" && "$cut" == *"$e" ]] && continue
        _PROGRESS_SHOWN+=("$cut")
      done
      (( ${#_PROGRESS_SHOWN[@]} > 3 )) && _PROGRESS_SHOWN=("${_PROGRESS_SHOWN[@]: -3}")
      for cut in "${_PROGRESS_SHOWN[@]}"; do
        lines+=("    $C_DIM$_PROGRESS_BAR$C_RESET $(_progress_cut "$cut" $(( cols - 6 )))")
      done
    fi
  done

  # The bottom: the bar and the time left, or the failure's buttons.
  local bottom=()
  if [[ -n "$_PROGRESS_STOPPING" ]]; then
    local wl
    while IFS= read -r wl; do bottom+=("  $C_YELLOW$wl$C_RESET"); done < <(tui_wrap $(( width - 4 )) \
      "$(T "Stopping safely: %s is given up to %s seconds to finish what it is doing." "$(STAGE_LABEL "$_PROGRESS_STOPPING")" "$_PROGRESS_GENTLE_S")")
  elif [[ -n "$_PROGRESS_FAILED" ]]; then
    # A stage stopped for a password: whatever is typed now is not for us.
    if [[ -e "$VITRUM_RUN_DIR/$_PROGRESS_FAILED.asked" ]]; then
      local al
      while IFS= read -r al; do bottom+=("  $C_YELLOW$al$C_RESET"); done < <(tui_wrap $(( width - 4 )) \
        "$(T "A command asked for a password on the terminal. Do not type it here; run the installer again: sudo is asked first.")")
    fi
    _progress_buttons
    local b buttons="  "
    for b in 0 1 2 3; do
      if (( b == _PROGRESS_BUTTON )); then buttons+="${TUI_REV}[ ${_PROGRESS_NAMES[b]} ]$TUI_RESET  "
      else buttons+="  ${_PROGRESS_NAMES[b]}    "
      fi
    done
    bottom+=("$buttons")
    bottom+=("  $C_DIM$TUI_G_LR $(T "button")  Enter $(T "select")  r s l q$C_RESET")
  else
    local text bar_w filled
    if (( done_n >= total )); then text="$(T "%s/%s · done" "$done_n" "$total")"
    else text="$(T "%s/%s · about %s min left" "$done_n" "$total" "$(_progress_left "$now")")"
    fi
    bar_w=$(( width - 6 - ${#text} ))
    (( bar_w > 30 )) && bar_w=30
    (( bar_w < 4 )) && bar_w=4
    filled=0
    (( total > 0 )) && filled=$(( done_n * bar_w / total ))
    bottom+=("  $C_BLUE$(_repeat "$filled" "$_PROGRESS_FULL")$C_DIM$(_repeat $(( bar_w - filled )) "$_PROGRESS_EMPTY")$C_RESET  $text")
  fi

  # The header.
  local mode head
  case "${INSTALL_MODE:-fresh}" in
    fresh) mode="$(T "installing")" ;;
    *)     mode="$(T "updating")" ;;
  esac
  head="vitrum ${REPO_VERSION:-$(vitrum_repo_version)} $TUI_G_SEP $mode"
  [[ -n "${PKG_BACKEND:-}" ]] && head+=" $TUI_G_SEP ${PKG_BACKEND}${INIT_BACKEND:+, $INIT_BACKEND}"

  # Header, a blank, the stages, a blank, the bottom. On a terminal too short
  # for all of it the blanks go first, then finished stages from the top, so
  # the running one and the bar stay in view.
  local gaps=2 room
  (( 1 + ${#lines[@]} + ${#bottom[@]} + gaps > rows )) && gaps=0
  room=$(( rows - 1 - ${#bottom[@]} - gaps ))
  (( room < 1 )) && room=1
  local drop=$(( ${#lines[@]} - room ))
  if (( drop > 0 )); then
    # Never past the opened stage's own line.
    (( opened >= 0 && drop > opened - 1 )) && drop=$(( opened - 1 ))
    (( drop < 0 )) && drop=0
    lines=("${lines[@]:drop}")
  fi

  printf '  %s%s%s\n' "$C_BOLD" "$(_progress_cut "$head" $(( width - 2 )))" "$C_RESET"
  (( gaps )) && printf '\n'
  printf '%s\n' "${lines[@]}"
  (( gaps )) && printf '\n'
  printf '%s\n' "${bottom[@]}"
}

# _progress_draw — the frame on the terminal. A frame that cannot be drawn
# (the terminal went away) is not a reason to stop: the stage goes on, and
# the hang-up, if that is what it was, has its own trap.
_progress_draw() {
  tui_size
  { progress_render > "$_TUI_FRAME" && tui_frame "$_TUI_FRAME"; } 2>/dev/null || true
}

# _progress_tree <pid> — the pid and every process under it, one per line.
# Read before anything is killed: an orphan is given to init and is lost.
_progress_tree() {
  local want=" $1 " pid ppid grew=1 table
  table="$(ps -A -o pid= -o ppid= 2>/dev/null)" || { printf '%s\n' "$1"; return 0; }
  while (( grew )); do
    grew=0
    while read -r pid ppid; do
      [[ "$want" == *" $ppid "* && "$want" != *" $pid "* ]] && { want+="$pid "; grew=1; }
    done <<<"$table"
  done
  # shellcheck disable=SC2086  # the pids are words
  printf '%s\n' $want
}

# How long a stage that changes the system as a whole is given to stop by
# itself after Ctrl+C, in seconds.
_PROGRESS_GENTLE_S=15

# _progress_kill [gentle] — end the running stage: its process group and, for
# what left the group, every process under it. TERM first; what is still there
# two seconds later gets KILL. Gentle, for the packages and boot stages: INT
# first, to the group only (sudo passes it on), and up to _PROGRESS_GENTLE_S
# seconds to act on it. pacman and emerge stop between two packages on INT,
# where TERM or KILL in the middle of a transaction or of mkinitcpio can leave
# a half-written package database or initramfs.
_progress_kill() {
  local pid="$_PROGRESS_PID" gentle="${1:-}" tree i
  [[ -n "$pid" ]] || return 0
  tree="$(_progress_tree "$pid")"
  if [[ -n "$gentle" ]]; then
    kill -INT -- "-$pid" 2>/dev/null || true
    kill -CONT -- "-$pid" 2>/dev/null || true
    for (( i = 0; i < _PROGRESS_GENTLE_S * 10; i++ )); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  fi
  # shellcheck disable=SC2086  # the pids are words
  kill -TERM -- "-$pid" $tree 2>/dev/null || true
  # A stopped process keeps a TERM pending until it runs again.
  # shellcheck disable=SC2086
  kill -CONT -- "-$pid" $tree 2>/dev/null || true
  for (( i = 0; i < 20; i++ )); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  # shellcheck disable=SC2086
  kill -KILL -- "-$pid" $tree 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  _PROGRESS_PID=""
}

# _progress_interrupt <status> <why> — Ctrl+C, a kill or a hang-up during
# the view: the stage goes, the log says why, the run directory goes, the
# terminal comes back, and the installer ends with the usual status.
_progress_interrupt() {
  trap '' INT TERM HUP
  local gentle=""
  case "${VITRUM_STAGE_KEY:-}" in
    packages|boot) [[ -n "$_PROGRESS_PID" ]] && gentle=1 ;;
  esac
  if [[ -n "$gentle" ]]; then
    _PROGRESS_STOPPING="$VITRUM_STAGE_KEY"
    _progress_draw
  fi
  _progress_kill "$gentle"
  _PROGRESS_STOPPING=""
  printf '\n%s\n' "$2" >> "${VITRUM_LOG:-/dev/null}" 2>/dev/null || true
  [[ -n "${VITRUM_RUN_DIR:-}" && -d "$VITRUM_RUN_DIR" ]] && rm -rf "$VITRUM_RUN_DIR"
  tui_end
  printf '\n  %s\n' "$(T "Interrupted.")"
  if [[ -n "${VITRUM_STAGE_KEY:-}" ]]; then
    printf '  %s\n' "$(T "Continue later: %s" "./install.sh --from $VITRUM_STAGE_KEY")"
  fi
  printf '\n'
  exit "$1"
}

# The view's own Ctrl+C and kill handling, over tui_begin's: there is a stage
# to stop first. A hang-up too: the stage is not in the terminal's foreground
# group, so closing the terminal would not reach it, and it would go on
# installing with nobody to see it.
_progress_traps() {
  trap "_progress_interrupt 130 'interrupted by the user'" INT
  trap "_progress_interrupt 143 'terminated'" TERM
  trap "_progress_interrupt 129 'the terminal was closed'" HUP
}

# _progress_done — what progress_run leaves set: nothing of the stage it ran
# last, and no hang-up trap.
_progress_done() {
  trap - HUP
  VITRUM_PROGRESS=0
  unset VITRUM_STAGE_KEY
}

# _progress_stage_path <key> — the stage's file.
_progress_stage_path() {
  local f="${STAGE_FILE[$1]:-}"
  [[ "$f" == /* ]] || f="$VITRUM_DIR/lib/stages/$f"
  printf '%s' "$f"
}

# _progress_body <key> — what runs in the stage's subshell.
# VITRUM_SKIP_STAGES_FOR_TEST=1 is a test hook: every stage is just true, so
# the tests of install.sh run its whole flow without installing anything.
_progress_body() {
  local key="$1"
  [[ "${VITRUM_SKIP_STAGES_FOR_TEST:-}" == 1 ]] && return 0
  # shellcheck source=/dev/null
  source "$(_progress_stage_path "$key")"
  if [[ -n "${STAGE_SOFT[$key]:-}" ]]; then
    "stage_$key" || true
  else
    "stage_$key"
  fi
}

# _progress_unmet <key> — 0 (and the stage marked needs) when something it
# needs was skipped or failed in this run. A need that is not in this run at
# all (--only, --from) was done before and counts as there.
_progress_unmet() {
  local key="$1" n st missing=""
  for n in ${STAGE_NEEDS[$key]:-}; do
    st="$(_progress_status "$n")"
    [[ "$st" == skip || "$st" == needs || "$st" == fail ]] && missing+="${missing:+ }$n"
  done
  [[ -n "$missing" ]] || return 1
  printf '%s\n' "$missing" > "$VITRUM_RUN_DIR/$key.needs"
  printf 'needs\n' > "$VITRUM_RUN_DIR/$key.status"
  printf '\n%s\n' "skipping stage: $key (needs: $missing)" >> "${VITRUM_LOG:-/dev/null}" 2>/dev/null || true
  return 0
}

# _progress_stage <key> <index> — run one stage, drawing as it goes; its
# status is left in <key>.status.
#
# The stage gets its own process group (set -m only for that one job), so
# Quit and Ctrl+C can end everything it started. Not setsid: a new session
# has no controlling terminal, and sudo keeps the timestamp the password
# warmed per terminal, so every sudo in the stage would ask again, with
# nowhere to ask. Stdin is /dev/null: a stage that reads must not wait on a
# terminal it is not in the foreground of.
_progress_stage() {
  local key="$1" d="$VITRUM_RUN_DIR" started rc=0 had_m=0
  : > "$d/$key.out"
  rm -f "$d/$key.step" "$d/$key.error" "$d/$key.time" "$d/$key.asked"
  printf 'running\n' > "$d/$key.status"
  started="$(date +%s)"
  printf '%s\n' "$started" > "$d/$key.start"
  # shellcheck disable=SC2034  # STAGE_INDEX is read by stage(), in the subshell
  VITRUM_STAGE_KEY="$key" STAGE_INDEX=$(( $2 - 1 ))
  export VITRUM_STAGE_KEY
  local log="${VITRUM_LOG:-/dev/null}"
  [[ $- == *m* ]] && had_m=1
  set -m
  # Job control is for that one job: inside, its own pipes and background
  # commands stay in its group.
  # Git asks for a username on a 401 on the terminal; here it fails instead.
  ( set +m; set -o pipefail; export GIT_TERMINAL_PROMPT=0
    ( _progress_body "$key" ) 2>&1 | tee -a "$log" > "$d/$key.out" ) </dev/null &
  _PROGRESS_PID=$!
  (( had_m )) || set +m
  local stopped=0
  while kill -0 "$_PROGRESS_PID" 2>/dev/null; do
    _progress_draw
    if _progress_stopped "$_PROGRESS_PID"; then stopped=1; break; fi
    sleep 0.2
  done
  if (( stopped )); then
    # Something in the stage opened the terminal to ask (a sudo password, a
    # prompt), which a background group may not: it was stopped, and would
    # stay stopped with the spinner turning for ever.
    _progress_kill
    rc=1
    : > "$d/$key.asked"
    L 'a command in this stage waited for input on the terminal (a sudo password?) and was stopped' > "$d/$key.error"
    printf '\n%s\n' "$(<"$d/$key.error")" | tee -a "$log" >> "$d/$key.out"
  else
    wait "$_PROGRESS_PID" || rc=$?
  fi
  _PROGRESS_PID=""
  printf '%s\n' "$(( $(date +%s) - started ))" > "$d/$key.time"
  if (( rc == 0 )); then printf 'ok\n' > "$d/$key.status"; else printf 'fail\n' > "$d/$key.status"; fi
}

# _progress_stopped <pgid> — 0 when a process of that group is stopped (ps
# state T): one that read or set the terminal from the background.
_progress_stopped() {
  local pgid stat
  while read -r pgid stat; do
    [[ "$pgid" == "$1" && "$stat" == T* ]] && return 0
  done < <(ps -A -o pgid= -o stat= 2>/dev/null)
  return 1
}

# _progress_lines <file> — how many lines it has (0 for none).
_progress_lines() {
  local n=0
  [[ -f "$1" ]] && n="$(wc -l < "$1" | tr -d ' ')"
  printf '%s' "${n:-0}"
}

# _progress_trim <file> <lines> — keep only its first lines: a retry forgets
# what the failed attempt warned about.
_progress_trim() {
  [[ -f "$1" ]] || return 0
  local keep=""
  (( $2 > 0 )) && keep="$(head -n "$2" "$1")"
  if [[ -n "$keep" ]]; then printf '%s\n' "$keep" > "$1"; else : > "$1"; fi
}

# progress_run <stage…> — run them in order under the view. 0 when every one
# ended ok or was skipped, 1 on Quit.
progress_run() {
  local own=0 key i=0 rc w e
  PROGRESS_STAGES=("$@")
  if [[ -z "${VITRUM_RUN_DIR:-}" || ! -d "$VITRUM_RUN_DIR" ]]; then
    VITRUM_RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vitrum-run.XXXXXX")" || return 1
  fi
  VITRUM_PROGRESS=1
  STAGE_TOTAL=$#
  export VITRUM_RUN_DIR VITRUM_PROGRESS STAGE_TOTAL
  PROGRESS_EST=()
  for key in "$@"; do
    PROGRESS_EST[$key]="$(progress_estimate "$key")"
    rm -f "$VITRUM_RUN_DIR/$key".{status,start,time,step,error,needs,out,asked}
  done
  _PROGRESS_FAILED=""
  if [[ "$_TUI_ON" != 1 ]]; then tui_begin || return 1; own=1; fi
  _progress_traps
  for key in "$@"; do
    i=$(( i + 1 ))
    _progress_unmet "$key" && continue
    while :; do
      w="$(_progress_lines "$VITRUM_RUN_DIR/warnings")" e="$(_progress_lines "$VITRUM_RUN_DIR/errors")"
      _progress_stage "$key" "$i"
      [[ "$(_progress_status "$key")" == ok ]] && break
      rc=0; progress_failure "$key" || rc=$?
      case "$rc" in
        30) _progress_trim "$VITRUM_RUN_DIR/warnings" "$w"; _progress_trim "$VITRUM_RUN_DIR/errors" "$e" ;;
        31) printf 'skip\n' > "$VITRUM_RUN_DIR/$key.status"; break ;;
        *)  _progress_done; return 1 ;;
      esac
    done
  done
  _progress_draw
  if (( own )); then
    tui_end
  else
    trap '_tui_signal 130' INT
    trap '_tui_signal 143' TERM
  fi
  _progress_done
  return 0
}

# _progress_failure_key <key> — 0 to go on, 30 Retry, 31 Skip, 32 Quit, 33
# Show log. The letters work on a Russian layout too (the same keys), and
# the end of the input quits: nobody is there to answer. While the guard is
# up (_PROGRESS_GUARD) letters do nothing: they are a password still coming.
_progress_failure_key() {
  if (( SECONDS < _PROGRESS_GUARD )); then
    case "$1" in
      left|up|right|down|tab|enter|eof) ;;
      *) return 0 ;;
    esac
  fi
  case "$1" in
    r|R|к|К) return 30 ;;
    s|S|ы|Ы) return 31 ;;
    l|L|д|Д) return 33 ;;
    q|Q|й|Й|eof) return 32 ;;
    left|up)         _PROGRESS_BUTTON=$(( (_PROGRESS_BUTTON + 3) % 4 )) ;;
    right|down|tab)  _PROGRESS_BUTTON=$(( (_PROGRESS_BUTTON + 1) % 4 )) ;;
    enter)
      case "$_PROGRESS_BUTTON" in 0) return 30 ;; 1) return 31 ;; 2) return 33 ;; *) return 32 ;; esac
      ;;
  esac
  return 0
}

# _progress_show_log <key> — the stage's output in a pager, on the main
# screen and the terminal (never into the log), then back to the view.
_progress_show_log() {
  local f="$VITRUM_RUN_DIR/$1.out" tty=/dev/tty
  tui_end
  if [[ -n "${TUI_IN:-}" ]]; then
    # The tests have no terminal for a pager.
    cat "$f" >> "${TUI_OUT:-/dev/null}"
  elif have less; then
    less -R +G "$f" > "$tty" 2>/dev/null </dev/tty || true
  elif have more; then
    more "$f" > "$tty" 2>/dev/null </dev/tty || true
  else
    cat "$f" > "$tty" 2>/dev/null || true
  fi
  tui_begin || true
  _progress_traps
}

# progress_failure <key> — the failed stage, its error and last lines, and
# Retry / Skip this stage / Show log / Quit. Returns 30 (retry), 31 (skip)
# or 32 (quit). Quit gives the terminal back and says how to go on later.
#
# A stage stopped for asking on the terminal (a sudo password) had its prompt
# over the view, and the user may be typing the password into the prompt
# that comes next: a second for the rest of it to arrive, all of it dropped,
# the cursor on Show log (not Retry or Quit, which an Enter would take), and
# for two seconds more a letter is no button.
progress_failure() {
  local key="$1" rc
  _PROGRESS_FAILED="$key" _PROGRESS_BUTTON=0 _PROGRESS_GUARD=0
  if [[ -e "$VITRUM_RUN_DIR/$key.asked" ]]; then
    _progress_draw
    sleep 1
    _PROGRESS_BUTTON=2 _PROGRESS_GUARD=$(( SECONDS + 2 ))
  fi
  tui_flush
  while :; do
    _progress_draw
    _tui_read_key || true
    rc=0; _progress_failure_key "$TUI_KEY" || rc=$?
    case "$rc" in
      30|31) _PROGRESS_FAILED=""; return "$rc" ;;
      33)    _progress_show_log "$key" ;;
      32)    break ;;
    esac
  done
  _PROGRESS_FAILED=""
  tui_end
  local e; e="$(_progress_read "$key" error)"
  printf '\n  %s%s%s %s%s\n' "$C_RED" "$G_ERR" "$C_RESET" "$(STAGE_LABEL "$key")" "${e:+: $e}"
  printf '  %s\n' "$(T "Continue later: %s" "./install.sh --from $key")"
  printf '  %s\n\n' "$(T "Log: %s" "${VITRUM_LOG:-}")"
  return 32
}
