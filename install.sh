#!/usr/bin/env bash
#
#  vitrum — a glass shell for niri (Gentoo with OpenRC or systemd, Arch with systemd)
#
#  Usage:
#    ./install.sh                 install, or update an existing install
#    ./install.sh --dry-run       print every action, change nothing
#    ./install.sh --doctor        check an existing install, change nothing
#    ./install.sh --check         only put back missing packages and fonts, then exit
#    ./install.sh --only shell    run one stage
#    ./install.sh --from niri     run from a stage onwards
#    ./install.sh --skip niri     run everything except a stage (repeatable)
#    ./install.sh --yes           never prompt
#
#  Optional parts:
#    --with-sddm / --no-sddm            SDDM with the vitrum login theme
#    --replace-dm                       let SDDM replace another active login screen
#    --with-plymouth / --no-plymouth    boot splash
#    --with-live-wallpaper / --no-live-wallpaper   video wallpapers (mpvpaper)
#    --with-extras / --no-extras        game mode + HUD, mic noise filter, calendar sync, VPN, sensors, mixer, archives
#    --with-phone / --no-phone          KDE Connect
#    --with-tmux / --no-tmux            tmux, themed, with your plugins
#    --with-nvim / --no-nvim            Neovim, themed, with your config
#    --tmux-autostart / --no-tmux-autostart
#    --tmux-keys=vitrum|default   vitrum's tmux keys (Ctrl+a, | and - splits) or tmux's own
#                                       start tmux with every interactive fish
#
#  Updating:
#    Run a newer checkout's ./install.sh. It reuses the choices you made the
#    first time, keeps your settings, and skips the compositor build unless
#    the pinned revision moved. --fresh forces everything to be redone.
#
set -euo pipefail

VITRUM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export VITRUM_DIR

# ------------------------------------------------------------------ log -----
#
# Everything from here on is written to a file as well as the screen. A build
# this long scrolls the interesting line out of the scrollback twenty minutes
# before anyone reads it, and "there were a lot of errors" is not something
# anyone can act on. Now there is one file to look at, or to send.
#
# Set up before common.sh is sourced so nothing escapes it. VITRUM_TTY carries
# the fact that we really are on a terminal across the pipe, so colours are not
# lost to tee.
if [[ -z "${VITRUM_LOG:-}" ]]; then
  _vitrum_state="${XDG_DATA_HOME:-$HOME/.local/share}/vitrum"
  # A dry run promises to change nothing — its log goes to the temp dir.
  case " $* " in *" --dry-run "*) _vitrum_state="${TMPDIR:-/tmp}/vitrum-dry-run" ;; esac
  mkdir -p "$_vitrum_state"
  VITRUM_LOG="$_vitrum_state/install-$(date +%Y%m%d-%H%M%S).log"
  export VITRUM_LOG
  [[ -t 1 ]] && export VITRUM_TTY=1
  exec > >(tee -a "$VITRUM_LOG") 2>&1
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

NIRI_TAG_LABEL="v26.04"

# Icons in the status markers, if this machine can already draw them. Asked
# again after the fonts stage, which is when a fresh install gains the font.
ui_icons

# ------------------------------------------------------------ stage list -----
#
# Order matters: fonts before themes (fontconfig is read at theme build time),
# fonts before terminal (the prompt is made of glyphs), niri before session,
# everything before doctor.
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

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
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
    --only)     ONLY="${2:?--only needs a stage}"; shift ;;
    --from)     FROM="${2:?--from needs a stage}"; shift ;;
    --skip)     SKIP+=("${2:?--skip needs a stage}"); shift ;;
    --with-tmux)    WANT_TMUX=1 ;;
    --no-tmux)      WANT_TMUX=0 ;;
    --with-nvim)    WANT_NVIM=1 ;;
    --no-nvim)      WANT_NVIM=0 ;;
    --replace-dm)   REPLACE_DM=1 ;;
    --with-sddm)    WANT_SDDM=1 ;;
    --no-sddm)      WANT_SDDM=0 ;;
    --with-plymouth) WANT_PLYMOUTH=1 ;;
    --no-plymouth)  WANT_PLYMOUTH=0 ;;
    --with-extras)  WANT_EXTRAS=1 ;;
    --no-extras)    WANT_EXTRAS=0 ;;
    --with-phone)   WANT_PHONE=1 ;;
    --no-phone)     WANT_PHONE=0 ;;
    --with-live-wallpaper) WANT_LIVE_WALLPAPER=1 ;;
    --no-live-wallpaper)   WANT_LIVE_WALLPAPER=0 ;;
    --tmux-autostart)    WANT_TMUX_AUTOSTART=1 ;;
    --no-tmux-autostart) WANT_TMUX_AUTOSTART=0 ;;
    --tmux-keys=vitrum|--tmux-keys=default) WANT_TMUX_KEYS="${1#*=}" ;;
    --version|-V) printf 'vitrum %s\n' "$(vitrum_repo_version)"; exit 0 ;;
    --help|-h)  usage ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done
export DRY_RUN ASSUME_YES REPLACE_DM

_known_stage() { local x; for x in "${STAGES[@]}"; do [[ "$x" == "$1" ]] && return 0; done; return 1; }
for _s in "$ONLY" "$FROM" "${SKIP[@]:-}"; do
  [[ -z "$_s" ]] && continue
  _known_stage "$_s" || die "unknown stage: $_s (stages: ${STAGES[*]})"
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

# --------------------------------------------------------------- banner ------

REPO_VERSION="$(vitrum_repo_version)"
INSTALLED_VERSION="$(vitrum_installed_version 2>/dev/null || true)"
MODE_LABEL="Install"
if [[ -n "$INSTALLED_VERSION" && "$FRESH" != "1" ]]; then
  MODE_LABEL="Update"
fi

banner() {
  local sub="a glass shell for niri"
  local ver="version $REPO_VERSION"
  [[ "$MODE_LABEL" == "Update" ]] && ver="$INSTALLED_VERSION  ->  $REPO_VERSION"
  printf '\n'
  ui_box "vitrum" "$sub" "" "$MODE_LABEL   $ver"
  printf '\n'
}

banner
dim "log: $VITRUM_LOG"

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
# Asked once. After that the answers live in components.json and an update
# repeats them silently, which is the difference between "run the newer
# installer" being a chore and being a habit.

load_components || true

# name|default|question|explanation — default is what a non-interactive run takes.
COMPONENT_QUESTIONS=(
  "TMUX|1|install tmux and its configuration?|tmux — your prefix, binds and plugins, with a vitrum status bar."
  "NVIM|1|install Neovim and its configuration?|Neovim — your plugins and keymaps, with a colourscheme from the vitrum palette."
  "SDDM|1|use SDDM with the vitrum login theme?|The login screen in the same style as the lock screen; other sessions stay listed."
  "PLYMOUTH|0|install the Plymouth boot splash?|A boot splash. On Gentoo the initramfs is regenerated with dracut, if dracut is your tool."
  "LIVE_WALLPAPER|1|allow video wallpapers?|Live wallpapers through mpvpaper. Static ones work either way."
  "EXTRAS|1|install the extras?|Game mode with its HUD (gamemode, MangoHud), the microphone noise filter, calendar sync (vdirsyncer, khal), WireGuard, hardware sensors, a sound mixer (pavucontrol) and an archive manager (Ark)."
  "PHONE|0|connect your phone (KDE Connect)?|Notifications from the phone, its battery, a shared clipboard and files. Pulls in part of KDE Frameworks."
)

pick_components() {
  local entry name def question explain var
  local interactive=1
  [[ "$ASSUME_YES" == "1" || ! -t 0 ]] && interactive=0
  local asked=0
  for entry in "${COMPONENT_QUESTIONS[@]}"; do
    IFS='|' read -r name def question explain <<<"$entry"
    var="WANT_$name"
    [[ -n "${!var}" ]] && continue          # decided by a flag or a previous install
    if [[ $interactive == 0 ]]; then printf -v "$var" '%s' "$def"; continue; fi
    [[ $asked == 0 ]] && { printf '  %sOptional parts%s\n\n' "$C_BOLD" "$C_RESET"; asked=1; }
    info "$explain"
    if confirm "$question" "$([[ $def == 1 ]] && echo y || echo n)"; then printf -v "$var" 1; else printf -v "$var" 0; fi
    printf '\n'
  done
  if [[ -z "$WANT_TMUX_KEYS" ]]; then
    if [[ "$WANT_TMUX" == "1" && $interactive == 1 ]]; then
      info "tmux keys: vitrum's — Ctrl+a prefix, | and - split, H J K L resize, vi copy-mode — or tmux's own (Ctrl+b, % and \")."
      confirm "use vitrum's tmux keys?" y && WANT_TMUX_KEYS=vitrum || WANT_TMUX_KEYS=default
    else
      WANT_TMUX_KEYS=vitrum
    fi
  fi
  if [[ -z "$WANT_TMUX_AUTOSTART" ]]; then
    if [[ "$WANT_TMUX" == "1" && $interactive == 1 ]]; then
      info "Opening a terminal can drop you straight into a tmux session instead of a bare shell."
      confirm "start tmux automatically with fish?" y && WANT_TMUX_AUTOSTART=1 || WANT_TMUX_AUTOSTART=0
    else
      WANT_TMUX_AUTOSTART="$WANT_TMUX"
    fi
  fi
}

pick_components
save_components   # an update repeats these answers instead of the defaults
export WANT_TMUX WANT_NVIM WANT_TMUX_AUTOSTART WANT_TMUX_KEYS WANT_FISH WANT_STARSHIP WANT_SDDM WANT_PLYMOUTH WANT_LIVE_WALLPAPER WANT_EXTRAS WANT_PHONE

printf '  %sThis run%s\n' "$C_BOLD" "$C_RESET"
ui_kv "mode" "$([[ "$MODE_LABEL" == "Update" ]] && echo "update from $INSTALLED_VERSION" || echo "fresh install")"
ui_kv "system" "packages: $PKG_BACKEND, init: $INIT_BACKEND"
ui_kv "compositor" "niri $NIRI_TAG_LABEL with liquid glass"
ui_kv "shell + apps" "Quickshell — bar, dock, launcher, Settings, Disk Utility"
ui_kv "terminal" "fish + Starship$([[ "$WANT_TMUX" == 1 ]] && echo ", tmux")$([[ "$WANT_NVIM" == 1 ]] && echo ", Neovim")"
ui_kv "backups" "$BACKUP_DIR"
printf '\n'

if [[ "$CHECK_ONLY" == "1" ]]; then
  prereqs_check
  exit 0
fi

if [[ "$MODE_LABEL" == "Install" && "$DRY_RUN" != "1" ]]; then
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

# Missing packages and fonts, whatever --only/--from/--skip left out. It warms
# sudo up itself (sudo_keepalive) when it has something to install.
prereqs_check

# ----------------------------------------------------------- the stages ------

# Count what will actually run, so the counter in each header is honest.
STAGE_TOTAL=0
for s in "${STAGES[@]}"; do should_run "$s" && STAGE_TOTAL=$((STAGE_TOTAL + 1)); done
STAGE_INDEX=0
export STAGE_TOTAL STAGE_INDEX

RUN_STARTED="$(date +%s)"

# One password for the whole run, also when preflight is skipped (--from, --only).
for s in "${STAGES[@]}"; do
  if [[ "$s" != doctor ]] && should_run "$s"; then sudo_keepalive; break; fi
done

for s in "${STAGES[@]}"; do
  should_run "$s" || { dim "skipping stage: $s"; continue; }
  VITRUM_STAGE_KEY="$s"   # what --from takes; die() prints it
  case "$s" in
    preflight) source "$VITRUM_DIR/lib/stages/00-preflight.sh";  stage_preflight ;;
    packages)  source "$VITRUM_DIR/lib/stages/10-packages.sh";   stage_packages ;;
    fonts)     source "$VITRUM_DIR/lib/stages/20-fonts.sh";      stage_fonts ;;
    niri)      source "$VITRUM_DIR/lib/stages/30-niri.sh";       stage_niri ;;
    shell)     source "$VITRUM_DIR/lib/stages/40-shell.sh";      stage_shell ;;
    apps)      source "$VITRUM_DIR/lib/stages/50-apps.sh";       stage_apps ;;
    terminal)  source "$VITRUM_DIR/lib/stages/45-terminal.sh";   stage_terminal ;;
    theming)   source "$VITRUM_DIR/lib/stages/60-theming.sh";    stage_theming ;;
    boot)      source "$VITRUM_DIR/lib/stages/70-boot.sh";       stage_boot ;;
    session)   source "$VITRUM_DIR/lib/stages/80-session.sh";    stage_session ;;
    doctor)    source "$VITRUM_DIR/lib/stages/90-doctor.sh";     stage_doctor || true ;;
  esac
done

record_install

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
  for line in "${VITRUM_ERRORS[@]:-}";   do [[ -n "$line" ]] && err "$line"; done
  for line in "${VITRUM_WARNINGS[@]:-}"; do [[ -n "$line" ]] && printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$line"; done
  printf '\n'
  ui_kv "full log" "$VITRUM_LOG"
  printf '\n'
fi


