#!/usr/bin/env bash
#
#  vitrum — a glass shell for niri (Gentoo with OpenRC or systemd, Arch with systemd,
#  Fedora 43 or newer with systemd, Void (glibc) with runit and elogind)
#
#  Usage:
#    ./install.sh                 install; on a machine with vitrum, update it
#    ./install.sh --dry-run       print every action, change nothing
#    ./install.sh --doctor        check an existing install, change nothing
#    ./install.sh --check         only put back missing packages and fonts, then exit
#    ./install.sh --only shell    run one stage
#    ./install.sh --from niri     run from a stage onwards
#    ./install.sh --skip niri     run everything except a stage (repeatable)
#    ./install.sh --update        update: ask only about parts new or not installed
#    ./install.sh --choose        the whole choice screen again, with your choices
#    ./install.sh --fresh         the first-run screens again; everything is redone
#    ./install.sh --yes           no screens, never prompt: new parts take defaults
#
#  On a terminal the installer shows its screens: the language, what to
#  install, a confirmation, then a progress view. Without one (a pipe, ssh -T,
#  TERM=dumb) or with --yes it prints line by line instead.
#
#  Optional parts, the same as on the choice screen:
#    --with-sddm / --no-sddm                     login screen (SDDM)
#    --replace-dm                                let SDDM replace another login screen
#    --with-plymouth / --no-plymouth             boot splash
#    --with-live-wallpaper / --no-live-wallpaper video wallpapers (mpvpaper)
#    --with-phone / --no-phone                   KDE Connect
#    --with-tmux / --no-tmux                     tmux, themed, with plugins
#    --with-games / --no-games                   game mode + HUD (gamemode, MangoHud)
#    --with-utilities / --no-utilities           mic noise filter, VPN, sensors, mixer, archives
#    --with-cli-tools / --no-cli-tools           eza, bat, fzf, zoxide, delta
#    --with-file-manager / --no-file-manager     Dolphin
#    --with-ocr / --no-ocr                       text from screenshots (tesseract)
#  The author's own setup, off unless asked for:
#    --with-author-nvim / --no-author-nvim       Neovim with the author's config
#    --with-author-tmux-keys / --no-author-tmux-keys   Ctrl+a, | and - splits, H J K L
#    --with-tmux-autostart / --no-tmux-autostart start tmux with every terminal
#  Older names that still work:
#    --with-extras / --no-extras                 games and utilities together
#    --with-nvim / --no-nvim                     --with-author-nvim / --no-author-nvim
#    --tmux-keys=vitrum|default                  the author's tmux keys, or tmux's own
#    --tmux-autostart                            --with-tmux-autostart
#
#  Updating:
#    vitrum update pulls the checkout and runs ./install.sh --update. Your
#    choices are kept; the choice screen comes up only for parts that are new
#    or still not installed (Esc there keeps the choices and goes on), and not
#    at all with --only, --from or --skip. Settings are kept, and the
#    compositor is rebuilt only when its pinned revision moved.
#
set -euo pipefail

VITRUM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export VITRUM_DIR

# The device's locale, read before common.sh can replace an ungenerated one
# with a UTF-8 locale that exists: the messages follow what the user set, not
# what this run borrowed. A value already in the environment is kept.
export VITRUM_DEVICE_LOCALE="${VITRUM_DEVICE_LOCALE:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}"

# ------------------------------------------------------------------ log -----
#
# Everything from here on is written to a file as well as the screen. A build
# this long scrolls the interesting line out of the scrollback twenty minutes
# before anyone reads it, and "there were a lot of errors" is not something
# anyone can act on. Now there is one file to look at, or to send.
#
# Set up before common.sh is sourced so nothing escapes it. VITRUM_TTY carries
# the fact that we really are on a terminal across the pipe, so colours are not
# lost to tee. tee ignores Ctrl+C (-i): it is in the terminal's foreground
# group with the installer, and if it died first the installer's last words
# (and the log's) would go nowhere.
if [[ -z "${VITRUM_LOG:-}" ]]; then
  _vitrum_state="${XDG_DATA_HOME:-$HOME/.local/share}/vitrum"
  # A dry run promises to change nothing — its log goes to the temp dir.
  case " $* " in *" --dry-run "*) _vitrum_state="${TMPDIR:-/tmp}/vitrum-dry-run" ;; esac
  mkdir -p "$_vitrum_state"
  VITRUM_LOG="$_vitrum_state/install-$(date +%Y%m%d-%H%M%S).log"
  export VITRUM_LOG
  [[ -t 1 ]] && export VITRUM_TTY=1
  exec > >(tee -ia "$VITRUM_LOG") 2>&1
fi

# shellcheck source=lib/common.sh
source "$VITRUM_DIR/lib/common.sh"
# shellcheck source=lib/backend/detect.sh
source "$VITRUM_DIR/lib/backend/detect.sh"
# shellcheck source=lib/packages.sh
source "$VITRUM_DIR/lib/packages.sh"
# shellcheck source=lib/assets.sh
source "$VITRUM_DIR/lib/assets.sh"
# shellcheck source=lib/prereqs.sh
source "$VITRUM_DIR/lib/prereqs.sh"
# shellcheck source=lib/dm.sh
source "$VITRUM_DIR/lib/dm.sh"
# The screens, and the progress view under them (lib/progress.sh, through finish.sh).
# shellcheck source=lib/screens/language.sh
source "$VITRUM_DIR/lib/screens/language.sh"
# shellcheck source=lib/screens/finish.sh
source "$VITRUM_DIR/lib/screens/finish.sh"
# shellcheck source=lib/stages/00-preflight.sh
source "$VITRUM_DIR/lib/stages/00-preflight.sh"

NIRI_TAG_LABEL="v26.04"

# Icons in the status markers, if this machine can already draw them. Asked
# again after the fonts stage, which is when a fresh install gains the font.
ui_icons

# ------------------------------------------------------------ stage list -----
#
# Order matters: fonts before themes (fontconfig is read at theme build time),
# fonts before terminal (the prompt is made of glyphs), niri before session,
# everything before doctor. Each one's file is in STAGE_FILE (lib/progress.sh).
#
STAGES=(
  preflight   # sanity checks, sudo warm-up, backup dir
  packages    # through the detected package backend
  fonts       # Inter, JetBrains Mono, Material Symbols, Nerd Font symbols
  niri        # patched compositor build
  shell       # Quickshell shell
  apps        # Settings / Disk Utility / About
  terminal    # kitty, fish, Starship, fastfetch, GTK colours; optionally tmux and Neovim
  theming     # GTK, Qt (Kvantum), cursor, Dolphin
  boot        # SDDM theme + Plymouth theme
  session     # wayland session, systemd units, autostart
  doctor      # verification pass
)

declare -a SKIP=()
ONLY=""
FROM=""
DOCTOR_ONLY=0
CHECK_ONLY=0
FRESH=0
CHOOSE=0

# The header of this file, up to the first line that is not a comment.
usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
  printf '\nStages: %s\n' "${STAGES[*]}"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=1 ;;
    --yes|-y)   ASSUME_YES=1 ;;
    --doctor)   DOCTOR_ONLY=1 ;;
    --check)    CHECK_ONLY=1 ;;
    --fresh)    FRESH=1 ;;
    # An update is what a run on a machine with vitrum does anyway; the flag
    # says so for vitrum update, which no longer passes --yes.
    --update)   ;;
    --choose)   CHOOSE=1 ;;
    --only)     ONLY="${2:?--only needs a stage}"; shift ;;
    --from)     FROM="${2:?--from needs a stage}"; shift ;;
    --skip)     SKIP+=("${2:?--skip needs a stage}"); shift ;;
    --replace-dm)   REPLACE_DM=1 ;;
    --version|-V) printf 'vitrum %s\n' "$(vitrum_repo_version)"; exit 0 ;;
    --help|-h)  usage ;;
    # --with-* / --no-* for every optional part, and the older flags
    # (--with-extras, --tmux-keys=…): lib/components.sh.
    *) components_flag "$1" || die 'unknown option: %s (try --help)' "$1" ;;
  esac
  shift
done
export DRY_RUN ASSUME_YES REPLACE_DM

_known_stage() { local x; for x in "${STAGES[@]}"; do [[ "$x" == "$1" ]] && return 0; done; return 1; }
for _s in "$ONLY" "$FROM" "${SKIP[@]:-}"; do
  [[ -z "$_s" ]] && continue
  _known_stage "$_s" || die 'unknown stage: %s (stages: %s)' "$_s" "${STAGES[*]}"
done

should_run() {
  local s="$1"
  for x in "${SKIP[@]:-}"; do [[ "$x" == "$s" ]] && return 1; done
  if [[ -n "$ONLY" ]]; then [[ "$ONLY" == "$s" ]] && return 0 || return 1; fi
  if [[ -n "$FROM" ]]; then
    local seen=0
    for x in "${STAGES[@]}"; do
      [[ "$x" == "$FROM" ]] && seen=1
      [[ "$x" == "$s" ]] && { [[ $seen -eq 1 ]] && return 0 || return 1; }
    done
  fi
  return 0
}

# ------------------------------------------------------------------ mode -----
#
# fresh: no install yet, or --fresh — the language, the whole choice screen
# and the confirmation. choose (--choose): the whole choice screen with the
# stored choices. update: the rest, a plain re-run included — the choice
# screen only for the parts that are new or still not installed.

REPO_VERSION="$(vitrum_repo_version)"
INSTALLED_VERSION="$(vitrum_installed_version 2>/dev/null || true)"
if [[ "$FRESH" == 1 || ! -f "$VITRUM_STATE/install.json" ]]; then INSTALL_MODE=fresh
elif [[ "$CHOOSE" == 1 ]]; then INSTALL_MODE=choose
else INSTALL_MODE=update
fi
export INSTALL_MODE REPO_VERSION
MODE_LABEL="Update"
[[ "$INSTALL_MODE" == fresh ]] && MODE_LABEL="Install"

# The screens, when there is a terminal for them; --doctor and --check never
# ask anything.
USE_TUI=0
if [[ "$DOCTOR_ONLY" != 1 && "$CHECK_ONLY" != 1 ]] && tui_available; then USE_TUI=1; fi

# The stages this run will run. PARTIAL: some were left out on purpose
# (--only, --from, --skip), the way the author reinstalls the shell after an
# edit; such a run is about those stages, not about the choices.
RUN_STAGES=()
for _s in "${STAGES[@]}"; do should_run "$_s" && RUN_STAGES+=("$_s"); done
PARTIAL=""
[[ -n "$ONLY$FROM" || ${#SKIP[@]} -gt 0 ]] && PARTIAL=1

# --------------------------------------------------------------- banner ------

banner() {
  local sub="a glass shell for niri"
  local ver="version $REPO_VERSION"
  [[ "$MODE_LABEL" == "Update" ]] && ver="${INSTALLED_VERSION:-?}  ->  $REPO_VERSION"
  printf '\n'
  ui_box "vitrum" "$sub" "" "$MODE_LABEL   $ver"
  printf '\n'
}

# The banner belongs to the line-by-line run; the screens have their own
# title, and under them it goes to the log only (with the run's summary, once
# the choices are known).
if (( ! USE_TUI )); then
  banner
  dim "log: $VITRUM_LOG"
fi

# Which package manager and init system — every stage goes through these.
load_backends

if [[ "$DOCTOR_ONLY" == "1" ]]; then
  source "$VITRUM_DIR/lib/stages/90-doctor.sh"
  stage_doctor
  exit $?
fi

[[ "$DRY_RUN" == "1" ]] && warn "dry run — nothing will be modified"

# ------------------------------------------------------------ components -----
#
# Chosen on the screens, then remembered in components.json, so an update
# repeats the choices instead of asking again: the difference between "run
# the newer installer" being a chore and being a habit. A flag given on this
# run wins over the file; what neither decides takes the default.

components_load || true
# What was installed before this run: unticked now, it is no longer managed.
CONFIRM_INSTALLED="$COMPONENTS_STORED_ON"
components_defaults

# The screens' language: the stored one in an update, or the device's for a
# file migrated from an installer that never asked.
if [[ "$INSTALL_MODE" != fresh ]]; then
  VITRUM_LANG="${VITRUM_LANG_STORED:-}"
  [[ -n "$VITRUM_LANG" && -z "${COMPONENTS_MIGRATED:-}" ]] || VITRUM_LANG="$(i18n_guess)"
  export VITRUM_LANG
fi

# Fish as the login shell is the confirmation's question, and only an answer
# given there counts. A first install takes the stored answer (--fresh) or the
# old default, fish, also under --yes. An update or --choose changes the login
# shell only when the row was ticked on this very run: a stored yes is no
# reason to undo a switch to another shell made since, and a run that showed
# no row (--yes, --check, no terminal, fish being the login shell already)
# has no answer to give. LOGIN_SHELL_ANSWERED says the row was answered.
if [[ "$INSTALL_MODE" == fresh ]]; then
  WANT_LOGIN_SHELL="${WANT_LOGIN_SHELL:-${COMPONENTS_LOGIN_SHELL:-1}}"
else
  WANT_LOGIN_SHELL=0
fi
LOGIN_SHELL_ANSWERED=""

# _install_nothing — Cancel, or no one at the keyboard: leave, nothing done.
# vitrum update pulls before it asks, so an update left here is in the
# checkout but not installed; the next vitrum update installs it.
_install_nothing() {
  tui_end
  printf '\n  %s\n' "$(T "Nothing done.")"
  if [[ "$INSTALL_MODE" != fresh ]] && vitrum_install_pending; then
    printf '  %s\n' "$(T "The update is not installed yet; to install it later: %s" "vitrum update")"
  fi
  printf '\n'
  exit 0
}

# The choices as they were before the screens, for Esc on the update's short
# list: it keeps them and goes on.
_INSTALL_KEPT=()
_install_remember() {
  local v
  _INSTALL_KEPT=()
  for v in $(components_vars) WANT_LOGIN_SHELL REPLACE_DM ACCEPT_LOW_DISK; do
    _INSTALL_KEPT+=("$v=${!v:-}")
  done
}
_install_restore() {
  local kv
  for kv in "${_INSTALL_KEPT[@]}"; do printf -v "${kv%%=*}" '%s' "${kv#*=}"; done
  _components_tmux_keys
}

# install_screens <language|choose> [id…] — the screens before anything runs.
# Change on the confirmation goes back to the choice. Esc on the choice goes
# back to the language on a first install; on the update's short list it
# keeps the choices as they were and goes on without the confirmation (3);
# under --choose it leaves. Cancel, or the end of the input, leaves with
# nothing done. The ids are the update's short list; none means the whole
# screen.
install_screens() {
  local first="$1" step="$1" rc
  shift
  tui_begin || return 1
  while :; do
    case "$step" in
      language)
        language_run
        step=choose
        ;;
      choose)
        rc=0; choose_run "$@" || rc=$?
        case "$rc" in
          0) step=confirm ;;
          1)
            if [[ "$first" == language ]]; then step=language
            elif [[ "$INSTALL_MODE" == update ]]; then
              _install_restore
              tui_end
              return 3
            else _install_nothing
            fi
            ;;
          *) _install_nothing ;;
        esac
        ;;
      confirm)
        rc=0; confirm_run || rc=$?
        case "$rc" in
          0) break ;;
          1) step=choose ;;
          *) _install_nothing ;;
        esac
        ;;
    esac
  done
  tui_end
}

if (( USE_TUI )); then
  # What the update has to ask about: the parts this version added, and the
  # ones still unticked. A choices file that is missing (install.json is there,
  # so vitrum is) or unreadable says nothing, so then everything is asked.
  _screen=""
  _ids=()
  case "$INSTALL_MODE" in
    fresh)  _screen=language ;;
    choose) _screen=choose ;;
    update)
      # A partial run asks nothing; --choose is the way to the screen then.
      if [[ -n "$PARTIAL" ]]; then
        :
      elif [[ ! -f "$(components_file)" || "${COMPONENTS_LOAD_FAILED:-}" == 1 ]]; then
        _screen=choose
      else
        mapfile -t _ids < <(components_new; components_unticked)
        (( ${#_ids[@]} )) && _screen=choose
      fi
      ;;
  esac
  if [[ -n "$_screen" ]]; then
    preflight_facts
    # The disk space for the niri build matters only when niri runs now.
    [[ " ${RUN_STAGES[*]} " == *" niri "* ]] || FACT_NIRI_BUILD=0
    CONFIRM_STAGES=("${RUN_STAGES[@]}")
    _install_remember
    _rc=0; install_screens "$_screen" "${_ids[@]}" || _rc=$?
    case "$_rc" in
      0)
        COMPONENTS_CHOSEN=1
        [[ " ${CONFIRM_ANSWERED:-} " == *" WANT_LOGIN_SHELL "* ]] && LOGIN_SHELL_ANSWERED=1
        ;;
      3) printf '\n  %s\n\n' "$(T "Your choices are kept as they were; the update goes on.")" ;;
      *)
        # No terminal after all (tui_begin failed): the line-by-line run.
        USE_TUI=0
        banner
        ;;
    esac
  fi
fi
export WANT_LOGIN_SHELL

# After the confirmation, before the stages: an interrupted run remembers.
# Not under --check, which asks nothing and installs no choice: it would only
# write down defaults as if they had been chosen.
[[ "$CHECK_ONLY" == 1 ]] || components_save
export WANT_SDDM WANT_PLYMOUTH WANT_LIVE_WALLPAPER WANT_PHONE WANT_TMUX WANT_GAMES WANT_UTILITIES \
  WANT_CLI_TOOLS WANT_FILE_MANAGER WANT_OCR WANT_NVIM WANT_AUTHOR_TMUX_KEYS WANT_TMUX_AUTOSTART \
  WANT_TMUX_KEYS WANT_FISH WANT_STARSHIP VITRUM_TERMINAL VITRUM_SHELL VITRUM_FASTFETCH_LOGO

# This run, in short: on the screen in the line-by-line run, and under the
# screens in the log only, so the log of every run says what it was asked to do.
run_summary() {
  local _parts="" _id
  for _id in $(component_ids); do [[ "$(component_get "$_id")" == 1 ]] && _parts+="${_parts:+ }$_id"; done
  printf '  %sThis run%s\n' "$C_BOLD" "$C_RESET"
  ui_kv "mode" "$([[ "$MODE_LABEL" == "Update" ]] && echo "update from ${INSTALLED_VERSION:-?}" || echo "fresh install")"
  ui_kv "system" "packages: $PKG_BACKEND, init: $INIT_BACKEND"
  ui_kv "compositor" "niri $NIRI_TAG_LABEL with liquid glass"
  ui_kv "shell + apps" "Quickshell — bar, dock, launcher, Settings, Disk Utility"
  ui_kv "terminal" "$VITRUM_TERMINAL, $VITRUM_SHELL + Starship$([[ "$WANT_TMUX" == 1 ]] && echo ", tmux")$([[ "$WANT_NVIM" == 1 ]] && echo ", Neovim")"
  ui_kv "parts" "$_parts"
  ui_kv "tmux keys" "$WANT_TMUX_KEYS"
  ui_kv "backups" "$BACKUP_DIR"
  printf '\n'
}
if (( USE_TUI )); then
  { banner; printf '  log: %s\n\n' "$VITRUM_LOG"; run_summary; } >> "$VITRUM_LOG" 2>/dev/null || true
else
  run_summary
fi

if [[ "$CHECK_ONLY" == "1" ]]; then
  prereqs_check
  exit 0
fi

if (( ! USE_TUI )) && [[ "$MODE_LABEL" == "Install" && "$DRY_RUN" != "1" ]]; then
  confirm "go ahead?" y || die "nothing done"
fi

if [[ "$DRY_RUN" != "1" ]]; then
  mkdir -p "$BUILD_DIR" "$VITRUM_STATE"
  # Where to update from (vitrum update), and the configs as they were, so an
  # update that goes wrong can be undone (vitrum rollback).
  printf '%s\n' "$VITRUM_DIR" > "$VITRUM_STATE/source"
  if [[ "$MODE_LABEL" == "Update" ]]; then
    "$VITRUM_DIR/tools/vitrum" snapshot before-update --unless-within 600 >/dev/null 2>&1 && dim "configs saved: vitrum rollback puts them back"
  fi
fi

# One password for the whole run, also when preflight is skipped (--from,
# --only). Under the screens it is asked here, on the main screen, before the
# progress view takes it.
_install_sudo() {
  local s
  for s in "${RUN_STAGES[@]}"; do
    if [[ "$s" != doctor ]]; then sudo_keepalive; return 0; fi
  done
}

RUN_STARTED="$(date +%s)"
export RUN_STARTED

# ------------------------------------------------ the stages, under the view -----

if (( USE_TUI )); then
  _install_sudo
  # What warn and err say from here on is kept for the final screen.
  VITRUM_RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vitrum-run.XXXXXX")"
  export VITRUM_RUN_DIR
  # Missing packages and fonts, whatever --only/--from/--skip left out.
  prereqs_check
  if ! progress_run "${RUN_STAGES[@]}"; then
    rm -rf "$VITRUM_RUN_DIR"
    exit 1
  fi
  # A stage skipped (or one that could not run without it) leaves the
  # version not fully installed: vitrum update tries again.
  progress_all_ok || PARTIAL=1
  record_install "$PARTIAL"
  finish_run
  # The welcome tour, on the first login after a first install (the shell
  # reads and removes the marker). It needs the session, which is what logging
  # in to vitrum starts: a stage skipped elsewhere is no reason to go without
  # the tour, as the runs after this one are updates and never write it.
  if [[ "$INSTALL_MODE" == fresh && "$DRY_RUN" != 1 && "$(_progress_status session)" == ok ]]; then
    touch "$VITRUM_STATE/welcome"
  fi
  rm -rf "$VITRUM_RUN_DIR"
  exit 0
fi

# ------------------------------------------------ the stages, line by line -----

# Missing packages and fonts, whatever --only/--from/--skip left out. It warms
# sudo up itself (sudo_keepalive) when it has something to install.
prereqs_check

# Count what will actually run, so the counter in each header is honest.
STAGE_TOTAL=${#RUN_STAGES[@]}
STAGE_INDEX=0
export STAGE_TOTAL STAGE_INDEX

_install_sudo

for s in "${STAGES[@]}"; do
  should_run "$s" || { dim "skipping stage: $s"; continue; }
  VITRUM_STAGE_KEY="$s"   # what --from takes; die() prints it
  # VITRUM_SKIP_STAGES_FOR_TEST=1 is a test hook (see lib/progress.sh; only
  # with VITRUM_TEST=1, lib/common.sh).
  [[ "${VITRUM_SKIP_STAGES_FOR_TEST:-}" == 1 ]] && continue
  # shellcheck source=/dev/null
  source "$VITRUM_DIR/lib/stages/${STAGE_FILE[$s]}"
  if [[ -n "${STAGE_SOFT[$s]:-}" ]]; then "stage_$s" || true; else "stage_$s"; fi
done

# Reaching here, every stage that ran went through (a failure dies); a run
# that left stages out is still partial.
record_install "$PARTIAL"
# The tour needs the session.
if [[ "$INSTALL_MODE" == fresh && "$DRY_RUN" != 1 ]] && should_run session; then touch "$VITRUM_STATE/welcome"; fi

# --------------------------------------------------------------- summary -----

TOTAL_MIN=$(( ( $(date +%s) - RUN_STARTED ) / 60 ))

printf '\n'
ui_box "Done" \
  "$MODE_LABEL finished in ${TOTAL_MIN}m." \
  "" \
  "Log out, then pick \"vitrum\" in your login manager."
printf '\n'

printf '  %sAfterwards%s\n' "$C_BOLD" "$C_RESET"
ui_kv "./install.sh --doctor" "re-check everything"
ui_kv "./install.sh --only shell" "reinstall the shell after editing QML"
ui_kv "vitrum-theme" "re-render colours and materials after a change"
ui_kv "./uninstall.sh" "put everything back"
printf '\n'
ui_kv "originals of replaced files" "$BACKUP_DIR"
printf '\n'

# Everything that went wrong, once more, where it can actually be read.
if [[ ${#VITRUM_ERRORS[@]} -gt 0 || ${#VITRUM_WARNINGS[@]} -gt 0 ]]; then
  printf '  %sWhat did not go cleanly%s\n\n' "$C_BOLD" "$C_RESET"
  for line in "${VITRUM_ERRORS[@]:-}";   do [[ -n "$line" ]] && err '%s' "$line"; done
  for line in "${VITRUM_WARNINGS[@]:-}"; do [[ -n "$line" ]] && printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$line"; done
  printf '\n'
  ui_kv "full log" "$VITRUM_LOG"
  printf '\n'
fi
