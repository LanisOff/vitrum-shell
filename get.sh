#!/usr/bin/env bash
# The one-line start: curl -fsSL .../get.sh | bash -s -- [installer flags]
# It finds or fetches the repository and hands over to install.sh. It prints in
# English because it runs before any language is chosen.
set -euo pipefail

REPO="${VITRUM_REPO:-https://github.com/LanisOff/vitrum-shell}"
BRANCH="${VITRUM_BRANCH:-main}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

# _need_sudo — git is installed through sudo, and the installer runs as you
# with sudo per command, so without it nothing can start. A minimal system
# (Void especially) may not have it: say how to get it here, rather than
# leave a bare "sudo: command not found".
_need_sudo() {
  command -v sudo >/dev/null 2>&1 && return 0
  local how
  if command -v pacman >/dev/null 2>&1; then how="pacman -S sudo"
  elif command -v emerge >/dev/null 2>&1; then how="emerge app-admin/sudo"
  elif command -v dnf >/dev/null 2>&1; then how="dnf install sudo"
  elif command -v xbps-install >/dev/null 2>&1; then how="xbps-install -Sy sudo"
  else return 0; fi   # no package manager known: the git message below says it all
  {
    echo "vitrum needs sudo: the installer runs as your user and uses sudo for each system change."
    echo "As root, install it with: $how"
    echo "then let your user use it: usermod -aG wheel <user>, and enable the %wheel line with visudo."
    echo "Log in again as that user and run this again."
  } >&2
  exit 1
}

# git comes first: without it there is nothing to fetch.
# pacman: a refresh without the upgrade (-Sy alone) is Arch's partial upgrade,
# which can leave git linked against libraries the system does not have yet.
# So git comes from the lists as they are. The -Syu fallback is a full system
# upgrade, taken only when that plain install fails, for example because the
# lists are missing or too old to find git.
# xbps: -S syncs the index, and -y accepts the repository's key on a first
# sync. xbps installs nothing while a newer xbps is waiting, so that one goes
# first.
if ! command -v git >/dev/null 2>&1; then
  _need_sudo
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm git || sudo pacman -Syu --needed --noconfirm git
  elif command -v emerge >/dev/null 2>&1; then
    sudo emerge --noreplace dev-vcs/git
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y git
  elif command -v xbps-install >/dev/null 2>&1; then
    sudo xbps-install -Sy
    if xbps-install -un 2>/dev/null | awk '$1 ~ /^xbps-[0-9]/ { due = 1 } END { exit !due }'; then
      sudo xbps-install -uy xbps
    fi
    sudo xbps-install -y git
  else
    echo "vitrum needs git; install it and run this again" >&2
    exit 1
  fi
fi

# _pull <dir> — bring the checkout up to date, as vitrum update does: fast
# forward only, and never over local changes (yours, or the author's work in
# progress), which are left as they are and installed from as they stand.
_pull() {
  if [[ -n "$(git -C "$1" status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
    echo "$1 has local changes; not updating it, installing from it as it is" >&2
    return 0
  fi
  git -C "$1" pull --ff-only || echo "could not update $1; going on with what is there" >&2
}

# An earlier install remembers its checkout; reuse it so there is only one copy.
dir=""
if [[ -r "$DATA/vitrum/source" ]]; then
  dir="$(head -n 1 "$DATA/vitrum/source")"
  [[ -f "$dir/install.sh" && -e "$dir/.git" ]] || dir=""
fi

if [[ -n "$dir" ]]; then
  _pull "$dir"
else
  dir="$DATA/vitrum-src"
  if [[ -e "$dir/.git" ]]; then
    _pull "$dir"
  else
    mkdir -p "$DATA"
    # A half-finished earlier clone would make git clone refuse; set it aside.
    [[ ! -e "$dir" ]] || mv "$dir" "$dir.broken.$$"
    git clone --depth 1 --branch "$BRANCH" "$REPO" "$dir"
  fi
fi

# Under curl | bash stdin is the script, so the questions need the terminal.
# With no terminal (ssh -T, a container) the installer runs on its defaults.
if { : </dev/tty; } 2>/dev/null; then
  exec "$dir/install.sh" "$@" </dev/tty
fi
exec "$dir/install.sh" "$@"
