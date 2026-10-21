#!/usr/bin/env bash
# Shared helpers for every install stage. Sourced, never executed.

[[ -n "${_VITRUM_COMMON_LOADED:-}" ]] && return 0
_VITRUM_COMMON_LOADED=1

# ----------------------------------------------------------- test hooks -----

# The tests point the installer at a fake world through these: a root to
# detect the system in, a place for system files, the screens drawn into a
# file with keys from another, every stage skipped. They are honoured only
# with VITRUM_TEST=1 (tests/sh/lib.sh sets it); anywhere else a stray one in
# the environment must not skip every stage or send the screens to a file.
if [[ "${VITRUM_TEST:-}" != 1 ]]; then
  unset VITRUM_SKIP_STAGES_FOR_TEST VITRUM_FORCE_TUI TUI_IN TUI_OUT \
    VITRUM_ROOTFS VITRUM_SYSROOT VITRUM_RUNTIME_PREFIX VITRUM_ASSETS_TABLE \
    VITRUM_KEYBINDS_MD VITRUM_NIRI_BIN VITRUM_NIRI_OLD
fi

# ---------------------------------------------------------------- paths -----

VITRUM_DIR="${VITRUM_DIR:?VITRUM_DIR must be set by install.sh}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

VITRUM_PREFIX="$XDG_CONFIG_HOME/vitrum"
VITRUM_STATE="$XDG_DATA_HOME/vitrum"
# One persistent place for the originals of every file vitrum ever replaced.
BACKUP_DIR="${VITRUM_BACKUP_DIR:-$VITRUM_STATE/originals}"
BUILD_DIR="${BUILD_DIR:-$XDG_CACHE_HOME/vitrum-build}"

# Translations: T for the screens, L for the messages below.
# shellcheck source=lib/i18n.sh
source "$VITRUM_DIR/lib/i18n.sh"

# --------------------------------------------------------------- output -----

# VITRUM_TTY is set by install.sh before it pipes everything through tee: the
# output is still going to a terminal, it is simply going through a pipe on the
# way, and losing every colour because of that would be silly.
if { [[ -t 1 ]] || [[ "${VITRUM_TTY:-}" == "1" ]]; } && [[ "${NO_COLOR:-}" != "1" ]]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_BLUE=$'\033[38;5;39m'; C_GREEN=$'\033[38;5;42m'
  C_YELLOW=$'\033[38;5;214m'; C_RED=$'\033[38;5;203m'
  C_PURPLE=$'\033[38;5;141m'; C_GREY=$'\033[38;5;245m'
  C_ON_ACCENT=$'\033[48;5;39m\033[38;5;255m'
else
  C_RESET=; C_DIM=; C_BOLD=; C_BLUE=; C_GREEN=; C_YELLOW=; C_RED=
  C_PURPLE=; C_GREY=; C_ON_ACCENT=
fi

# The frame the installer draws — boxes, rules, the stage bar — is box-drawing
# and ASCII, never a Nerd Font glyph: on a fresh machine the fonts stage has not
# run yet, and a banner made of tofu is a bad first impression. The status
# markers are the one exception, and they check first; see ui_icons.
UI_WIDTH="${UI_WIDTH:-72}"

_stage_name=""
STAGE_INDEX="${STAGE_INDEX:-0}"
STAGE_TOTAL="${STAGE_TOTAL:-0}"

_repeat() { local n="$1" c="$2" out=""; while (( n-- > 0 )); do out+="$c"; done; printf '%s' "$out"; }

ui_rule() {
  printf '%s%s%s\n' "$C_DIM" "$(_repeat "$UI_WIDTH" '─')" "$C_RESET"
}

# ui_box <title> <line...> — a rounded panel, the CLI's version of a sheet.
ui_box() {
  local title="$1"; shift
  local inner=$((UI_WIDTH - 2))
  printf '%s╭%s╮%s\n' "$C_BLUE" "$(_repeat "$inner" '─')" "$C_RESET"
  if [[ -n "$title" ]]; then
    printf '%s│%s %s%-*s%s %s│%s\n' \
      "$C_BLUE" "$C_RESET" "$C_BOLD" "$((inner - 2))" "$title" "$C_RESET" "$C_BLUE" "$C_RESET"
    printf '%s│%s%s│%s\n' "$C_BLUE" "$(_repeat "$inner" ' ')" "$C_BLUE" "$C_RESET"
  fi
  local line
  for line in "$@"; do
    printf '%s│%s %-*s %s│%s\n' "$C_BLUE" "$C_RESET" "$((inner - 2))" "$line" "$C_BLUE" "$C_RESET"
  done
  printf '%s╰%s╯%s\n' "$C_BLUE" "$(_repeat "$inner" '─')" "$C_RESET"
}

# ui_kv <key> <value> — an aligned key/value row.
ui_kv() { printf '    %s%-26s%s %s\n' "$C_GREY" "$1" "$C_RESET" "$2"; }

stage() {
  _stage_name="$1"
  _stage_started="$(date +%s)"
  STAGE_INDEX=$((STAGE_INDEX + 1))
  local counter="" clen=0
  if [[ "$STAGE_TOTAL" -gt 0 ]]; then
    counter="$(printf '%d/%d' "$STAGE_INDEX" "$STAGE_TOTAL")"
    clen=${#counter}
  fi
  printf '\n'
  # "▎ " is two cells wide, so the name gets everything the counter does not.
  printf '%s%s▎%s %s%-*s%s%s%s\n' \
    "$C_BOLD" "$C_BLUE" "$C_RESET" "$C_BOLD" "$((UI_WIDTH - 2 - clen))" "$1" "$C_RESET" \
    "$C_DIM$counter" "$C_RESET"
  ui_rule
}

# Closes a stage with how long it took. Cheap, and it makes "is it stuck?"
# answerable at a glance on the long compositor build.
stage_done() {
  local took=$(( $(date +%s) - ${_stage_started:-$(date +%s)} ))
  if (( took >= 60 )); then
    ok "${1:-done} ${C_DIM}($((took / 60))m $((took % 60))s)${C_RESET}"
  elif (( took > 2 )); then
    ok "${1:-done} ${C_DIM}(${took}s)${C_RESET}"
  else
    ok "${1:-done}"
  fi
}

# bash's printf turns \uXXXX into a character only under a UTF-8 locale; under
# any other it prints the escape itself, and every marker in the log reads
# "\uf00c". LANG naming a locale nobody generated is the usual way to get there
# (glibc falls back to C), so the installer borrows a UTF-8 locale that does
# exist and preflight says how to generate the real one. VITRUM_LOCALE_MISSING
# keeps the names that failed: one bad variable sinks them all (glibc refuses
# the whole set), so LC_CTYPE=C.UTF-8 next to an ungenerated LANG still lands
# in C, and it is LANG that has to be named.
_utf8_ok() { [[ "$(printf '\u2713')" != '\u2713' ]]; }
# _locale_known <name> \u2014 locale -a spells en_US.UTF-8 as en_US.utf8.
_locale_known() {
  local want="${1,,}"; want="${want//-/}"
  [[ "$want" == c || "$want" == posix ]] && return 0
  locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '-' | grep -qxF "$want"
}
if ! _utf8_ok; then
  VITRUM_LOCALE_MISSING=""
  for _v in LC_ALL LC_CTYPE LANG; do
    if [[ -z "${!_v:-}" ]] || _locale_known "${!_v}"; then continue; fi
    [[ "$VITRUM_LOCALE_MISSING" == *"${!_v} "* ]] && continue
    VITRUM_LOCALE_MISSING+="${VITRUM_LOCALE_MISSING:+, }${!_v} ($_v)"
  done
  : "${VITRUM_LOCALE_MISSING:=${LANG:-C}}"
  unset _v
  # LC_ALL is about to name a borrowed locale; the language the user asked
  # for is still the one the messages should speak.
  : "${VITRUM_DEVICE_LOCALE:=${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}"
  export VITRUM_DEVICE_LOCALE
  for _loc in C.UTF-8 C.utf8 $(locale -a 2>/dev/null | grep -iE '\.utf-?8$'); do
    export LC_ALL="$_loc"
    _utf8_ok && break
    unset LC_ALL
  done
  unset _loc
fi

# The status markers, in their safe form. ui_icons() upgrades them to real
# icons further down, once there is something that can tell whether this
# machine has a font capable of drawing one. Without any UTF-8 locale they
# stay ASCII.
if _utf8_ok; then
  G_OK=$(printf '\u2713'); G_ERR=$(printf '\u2717')
  G_WARN='!';               G_STEP=$(printf '\u00b7')
else
  G_OK='+'; G_ERR='x'; G_WARN='!'; G_STEP='-'
fi

info()   { printf '    %s\n' "$*"; }
# Under the progress view (VITRUM_RUN_DIR) the step is also the state shown
# beside the stage's name.
step() {
  printf '  %s%s%s %s\n' "$C_BLUE" "$G_STEP" "$C_RESET" "$*"
  if [[ -n "${VITRUM_RUN_DIR:-}" && -n "${VITRUM_STAGE_KEY:-}" ]]; then
    printf '%s\n' "$*" > "$VITRUM_RUN_DIR/$VITRUM_STAGE_KEY.step" 2>/dev/null || true
  fi
}
ok()     { printf '  %s%s%s %s\n' "$C_GREEN" "$G_OK" "$C_RESET" "$*"; }
dim()    { printf '%s    %s%s\n' "$C_DIM" "$*" "$C_RESET"; }

# Everything that went wrong, kept so it can be replayed at the end. On a long
# install the interesting lines scroll past twenty minutes before you look.
# Under the progress view each stage runs in a subshell, whose arrays die
# with it, so the lines also go to files in VITRUM_RUN_DIR for the final
# screen to read.
VITRUM_WARNINGS=()
VITRUM_ERRORS=()

# _run_note <file> <text> — append to that file of the run directory, if any.
_run_note() {
  [[ -n "${VITRUM_RUN_DIR:-}" ]] || return 0
  printf '%s\n' "$2" >> "$VITRUM_RUN_DIR/$1" 2>/dev/null || true
}

# warn <template> [args...] — the template is formatted through L, so it is
# shown in the device's language with %s taking the arguments in turn. A lone
# argument is printed as it is.
warn() {
  local msg; msg="$(L "$@")"
  VITRUM_WARNINGS+=("$msg")
  _run_note warnings "$msg"
  printf '  %s%s%s %s\n' "$C_YELLOW" "$G_WARN" "$C_RESET" "$msg" >&2
}
err() {
  local msg; msg="$(L "$@")"
  VITRUM_ERRORS+=("$msg")
  _run_note errors "$msg"
  printf '  %s%s%s %s\n' "$C_RED" "$G_ERR" "$C_RESET" "$msg" >&2
}

# die — the message, where to resume and the log, then exit 1. Under the
# progress view the message is also the stage's .error, which the failure
# prompt shows.
die() {
  err "$@"
  if [[ -n "${VITRUM_RUN_DIR:-}" && -n "${VITRUM_STAGE_KEY:-}" ]]; then
    L "$@" > "$VITRUM_RUN_DIR/$VITRUM_STAGE_KEY.error" 2>/dev/null || true
    # The failure prompt says where to resume and where the log is; printed
    # here as well they would be all the tail it shows of the stage.
    [[ "${VITRUM_PROGRESS:-0}" == 1 ]] && exit 1
  fi
  # The two labels line up, in whichever language they come out; ${#} counts
  # characters, which printf's field width would not.
  local resume log
  resume="$(L 'Resume with:')" log="$(L 'Full log:')"
  while (( ${#resume} < ${#log} )); do resume+=' '; done
  while (( ${#log} < ${#resume} )); do log+=' '; done
  if [[ -n "$_stage_name" ]]; then
    printf '\n%s%s%s %s\n' "$C_BOLD" "$(L 'Stage that failed:')" "$C_RESET" "$_stage_name" >&2
    printf '%s %s./install.sh --from %s%s\n' "$resume" "$C_DIM" "${VITRUM_STAGE_KEY:-$_stage_name}" "$C_RESET" >&2
  fi
  if [[ -n "${VITRUM_LOG:-}" ]]; then
    printf '%s %s%s%s\n\n' "$log" "$C_DIM" "$VITRUM_LOG" "$C_RESET" >&2
  else
    printf '\n' >&2
  fi
  exit 1
}

# ---------------------------------------------------------------- modes -----

DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"

# run <cmd...> — honours --dry-run, dies with the command on failure.
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    dim "would run: $*"
    return 0
  fi
  "$@" || die 'command failed: %s' "$*"
}

# run_ok <cmd...> — same, but a non-zero exit is a return value, not fatal.
run_ok() {
  if [[ "$DRY_RUN" == "1" ]]; then
    dim "would run: $*"
    return 0
  fi
  "$@"
}

# confirm <prompt> [y|n] — ask on the terminal. Under the progress view
# (VITRUM_PROGRESS=1) nothing may stop for an answer: the questions were asked
# on the confirmation screen, so one still asked here takes its default and
# says so in the log.
confirm() {
  local prompt="$1" default="${2:-n}" reply
  [[ "$ASSUME_YES" == "1" ]] && return 0
  [[ "$DRY_RUN" == "1" ]] && return 0
  if [[ "${VITRUM_PROGRESS:-0}" == 1 ]]; then
    dim "(asked: $prompt — took $default)"
    [[ "$default" == y ]]
    return
  fi
  local hint="[y/N]"; [[ "$default" == "y" ]] && hint="[Y/n]"
  read -r -p "  $prompt $hint " reply </dev/tty || reply=""
  reply="${reply:-$default}"
  [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

# trap_cmd <signal> — the command of the trap now set for it, if any, so a
# new trap can run it too instead of replacing it. trap -p prints it quoted
# for the shell; set -- unquotes it the same way.
trap_cmd() {
  local out; out="$(trap -p "$1")"
  [[ -n "$out" ]] || return 0
  eval "set -- ${out#trap }"
  printf '%s' "$2"
}

# Number of CPUs, without assuming coreutils' nproc.
cpu_count() {
  local n
  n="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
  [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 )) || n=2
  printf '%s\n' "$n"
}

# Half the CPUs, at least one — for builds on machines without swap.
half_jobs() { local n; n=$(( $(cpu_count) / 2 )); (( n < 1 )) && n=1; printf '%s\n' "$n"; }

# Is a font family installed?
#
# Not `fc-list | grep -q`, which is what this used to be, and which was wrong
# in a way that took a whole install to notice. `grep -q` exits at the first
# match; fc-list is still writing; the pipe closes under it; fc-list dies of
# SIGPIPE with status 141 — and `set -o pipefail` turns that into a failed
# pipeline. So the test reports "not installed" precisely when the font *is*
# installed and matches early, on any machine with enough fonts to overflow the
# 64K pipe buffer. Every font check in this repo failed that way at once,
# fontconfig was written for Inter, and the desktop shipped with the wrong
# typography while the log claimed the fonts were missing.
#
# Reading the whole list into a variable has no pipeline and no early exit.
have_font() {
  local list
  list="$(fc-list 2>/dev/null)" || return 1
  [[ "${list,,}" == *"${1,,}"* ]]
}

# Upgrade the status markers to Nerd Font icons, if this terminal can draw one.
#
# Two conditions, both necessary. A Linux virtual console has no Nerd Font and
# never will — reaching a TTY is what you do when the desktop is broken, and
# printing tofu at exactly that moment would be perverse. And on a fresh
# install the fonts stage has not run yet, so a graphical terminal is not
# evidence of anything either: ask fontconfig.
#
# Called once, after the fonts stage, so the second half of a first install and
# every run after it get the icons.
ui_icons() {
  case "${TERM:-}" in linux|dumb|"") return 0 ;; esac
  _utf8_ok || return 0
  have_font 'Symbols Nerd Font' || return 0
  G_OK=$(printf '\uf00c')      # check
  G_ERR=$(printf '\uf00d')     # times
  G_WARN=$(printf '\uf071')    # warning triangle
  G_STEP=$(printf '\uf111')    # small filled circle
}

# Refresh the sudo timestamp with the prompt visible.
#
# Any sudo command whose stderr is suppressed can ask for a password nobody can
# see, and a hidden prompt is indistinguishable from a hang. Call this before a
# block of quiet sudo work so the asking happens somewhere you can see it.
sudo_refresh() {
  [[ "$DRY_RUN" == "1" ]] && return 0
  sudo -v || die "sudo is required"
}

# Ask for the password once and keep the timestamp alive until the installer
# exits, so hours of building never end at a second prompt. Started before the
# first stage whatever --from or --only says; a second call does nothing.
# install.sh asks before the progress view takes the screen, so the prompt is
# seen. Its EXIT trap runs the one set before it (the screens' own, which gives
# the terminal back) rather than replacing it.
sudo_keepalive() {
  [[ "$DRY_RUN" == "1" || -n "${SUDO_KEEPALIVE:-}" ]] && return 0
  sudo -v || die "sudo is required"
  ( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
  SUDO_KEEPALIVE=$!
  local prev; prev="$(trap_cmd EXIT)"
  # shellcheck disable=SC2064  # the earlier command is meant to be fixed now
  trap "kill \"\$SUDO_KEEPALIVE\" 2>/dev/null || true${prev:+; $prev}" EXIT
}

# --------------------------------------------------------------- backup -----

# backup_path <path> — copy an existing file or directory aside, once, keeping
# its position relative to $HOME so uninstall can put it straight back.
backup_path() {
  # First touch only, ever. A path vitrum is about to write is either the
  # user's ("saved": copied here, restored by uninstall) or new ("created":
  # removed by uninstall). Later runs find it in the manifest and leave the
  # record alone — so a second install never mistakes our own file for theirs.
  local target="$1"
  local rel="${target#"$HOME"/}"
  local manifest="$BACKUP_DIR/.manifest"
  if [[ -f "$manifest" ]] && grep -qxF -e "saved $rel" -e "created $rel" "$manifest"; then return 0; fi
  if [[ "$DRY_RUN" == "1" ]]; then
    [[ -e "$target" || -L "$target" ]] && dim "would save the original $target"
    return 0
  fi
  mkdir -p "$BACKUP_DIR"
  if [[ -e "$target" || -L "$target" ]]; then
    mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
    cp -a "$target" "$BACKUP_DIR/$rel" || die 'could not back up %s' "$target"
    printf 'saved %s\n' "$rel" >> "$manifest"
  else
    printf 'created %s\n' "$rel" >> "$manifest"
  fi
}

# install_tree <src-dir> <dest-dir> — back up dest, then mirror src into it.
install_tree() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || die 'missing source tree: %s' "$src"
  backup_path "$dest"
  if [[ "$DRY_RUN" == "1" ]]; then
    dim "would sync $src -> $dest"
    return 0
  fi
  mkdir -p "$dest"
  # macOS leaves debris on anything it copies to a foreign filesystem: a
  # `._Name` AppleDouble sidecar beside every file, and .DS_Store in every
  # directory. Installing a checkout made that way used to put a `._Foo.qml`
  # next to every real one, which Quickshell has no reason to read and this
  # project's own QML check spent a screenful complaining about.
  if have rsync; then
    rsync -a --delete-after \
          --exclude '._*' --exclude '.DS_Store' \
          "$src"/ "$dest"/ || die 'rsync failed: %s -> %s' "$src" "$dest"
  else
    rm -rf "${dest:?}"/* 2>/dev/null || true
    cp -a "$src"/. "$dest"/ || die 'copy failed: %s -> %s' "$src" "$dest"
    find "$dest" \( -name '._*' -o -name '.DS_Store' \) -delete 2>/dev/null || true
  fi
}

# install_file <src> <dest> [mode]
install_file() {
  local src="$1" dest="$2" mode="${3:-0644}"
  [[ -f "$src" ]] || die 'missing source file: %s' "$src"
  backup_path "$dest"
  if [[ "$DRY_RUN" == "1" ]]; then
    dim "would install $dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  install -m "$mode" "$src" "$dest" || die 'could not install %s' "$dest"
}

# write_file <dest> <<'EOF' ... EOF — back up then write stdin.
write_file() {
  local dest="$1" content
  content="$(cat)"
  backup_path "$dest"
  if [[ "$DRY_RUN" == "1" ]]; then
    dim "would write $dest ($(wc -l <<<"$content") lines)"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$content" > "$dest" || die 'could not write %s' "$dest"
}

# sudo_write <dest> [mode] — same, for root-owned destinations.
sudo_write() {
  local dest="$1" mode="${2:-0644}" content
  content="$(cat)"
  if [[ "$DRY_RUN" == "1" ]]; then
    dim "would write (root) $dest"
    return 0
  fi
  sudo mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$content" | sudo tee "$dest" >/dev/null || die 'could not write %s' "$dest"
  sudo chmod "$mode" "$dest"
}

# ----------------------------------------------------------------- misc -----

# fetch <url> <dest> — curl with retries.
fetch() {
  local url="$1" dest="$2"
  if [[ "$DRY_RUN" == "1" ]]; then dim "would download $url"; return 0; fi
  mkdir -p "$(dirname "$dest")"
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 \
       -o "$dest" "$url" || return 1
}

# gh_release_asset <owner/repo> <name-substring> — echoes a download URL.
gh_release_asset() {
  local repo="$1" match="$2"
  curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
    | grep -o '"browser_download_url": *"[^"]*"' \
    | cut -d'"' -f4 \
    | grep -i -- "$match" \
    | head -n1
}


# install_tree_keep <src> <dest> [relative-path-to-keep...]
#
# install_tree mirrors and deletes, which is right for files this project owns
# and wrong for the few places a user is invited to put their own. Anything
# named here survives the sync.
install_tree_keep() {
  local src="$1" dest="$2"; shift 2
  [[ -d "$src" ]] || die 'missing source tree: %s' "$src"
  backup_path "$dest"
  if [[ "$DRY_RUN" == "1" ]]; then
    dim "would sync $src -> $dest (keeping: $*)"
    return 0
  fi
  mkdir -p "$dest"
  if have rsync; then
    local excludes=()
    local keep
    for keep in "$@"; do excludes+=(--exclude "$keep"); done
    rsync -a --delete-after "${excludes[@]}" "$src"/ "$dest"/ \
      || die 'rsync failed: %s -> %s' "$src" "$dest"
  else
    # Without rsync, copy over the top rather than clearing first: leaving a
    # stale file behind is better than deleting something we promised to keep.
    cp -a "$src"/. "$dest"/ || die 'copy failed: %s -> %s' "$src" "$dest"
  fi
}

# --------------------------------------------------------------- version ----

vitrum_repo_version() {
  if [[ -f "$VITRUM_DIR/VERSION" ]]; then
    tr -d '[:space:]' < "$VITRUM_DIR/VERSION"
  else
    printf 'unknown'
  fi
}

vitrum_installed_version() {
  local f="$VITRUM_STATE/install.json"
  [[ -f "$f" ]] || return 1
  have python3 || return 1
  python3 - "$f" <<'PY' 2>/dev/null
import json, sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8")).get("version", ""))
except Exception:
    raise SystemExit(1)
PY
}

# Compare two dotted versions. Prints -1, 0 or 1 for a<b, a==b, a>b.
version_cmp() {
  python3 - "$1" "$2" <<'PY' 2>/dev/null || printf '0'
import sys
def parts(v):
    out = []
    for chunk in str(v).split("."):
        digits = "".join(c for c in chunk if c.isdigit())
        out.append(int(digits) if digits else 0)
    return out
a, b = parts(sys.argv[1]), parts(sys.argv[2])
n = max(len(a), len(b))
a += [0] * (n - len(a)); b += [0] * (n - len(b))
print(-1 if a < b else (1 if a > b else 0))
PY
}

# _install_json_field <field> — a string field of install.json, empty when
# there is none. Plain sed: install.json is written below, one field a line.
_install_json_field() {
  local f="$VITRUM_STATE/install.json"
  [[ -f "$f" ]] || return 0
  sed -n "s/^ *\"$1\": *\"\([^\"]*\)\".*/\1/p" "$f" 2>/dev/null | head -n 1 || true
}

# vitrum_checkout_revision — the commit the checkout is at, empty for a copy
# that is not a git checkout.
vitrum_checkout_revision() {
  git -C "$VITRUM_DIR" rev-parse HEAD 2>/dev/null || true
}

# vitrum_install_pending — 0 when the checkout holds something the last
# complete run did not install: vitrum update pulled it and the run was
# cancelled, or a stage was skipped or failed. A copy without git cannot say.
vitrum_install_pending() {
  local head; head="$(vitrum_checkout_revision)"
  [[ -n "$head" && "$head" != "$(_install_json_field revision)" ]]
}

# record_install [partial] — install.json: the version and the checkout's
# revision this run installed. A partial run (a stage skipped or failed, or
# left out with --only, --from or --skip) is not the new version installed:
# it keeps the version and revision of the last complete one, or names no
# revision on a first install, so vitrum update sees what is still to do and
# runs the installer again.
record_install() {
  if [[ "$DRY_RUN" == "1" ]]; then dim "would record the install manifest"; return 0; fi
  mkdir -p "$VITRUM_STATE"
  local version revision complete=true old
  version="$(vitrum_repo_version)"
  revision="$(vitrum_checkout_revision)"
  if [[ -n "${1:-}" ]]; then
    complete=false
    old="$(vitrum_installed_version 2>/dev/null)" || old=""
    version="${old:-$version}"
    revision="$(_install_json_field revision)"
  fi
  cat > "$VITRUM_STATE/install.json" <<EOF
{
  "version": "$version",
  "revision": "$revision",
  "complete": $complete,
  "installed": "$(date -Iseconds)",
  "repo": "$VITRUM_DIR",
  "backup": "$BACKUP_DIR"
}
EOF
}

# The optional parts and the stored choices (components.json).
# shellcheck source=lib/components.sh
source "$VITRUM_DIR/lib/components.sh"
