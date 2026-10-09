#!/usr/bin/env bash
#
#  A git pill for the tmux status bar.
#
#  Prints nothing at all outside a repository, so the bar simply gets shorter
#  rather than showing an empty box. Colours come from tmux, which got them
#  from the theme, which got them from System Settings — one source.
#
#  Icons are ANSI-C quoted escapes rather than literal characters: Private Use
#  Area glyphs do not survive being copied around, and this way the name of
#  each icon is right there next to it.
#
#  Usage: git.sh <path>
#
set -u

dir="${1:-$PWD}"
[[ -d "$dir" ]] || exit 0
command -v git >/dev/null 2>&1 || exit 0

cd "$dir" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# ------------------------------------------------------------------ glyphs --
CAP_L=$''       # left half circle
CAP_R=$''       # right half circle
I_BRANCH=$''    # nf-dev-git_branch
I_COMMIT=$''    # nf-dev-git_commit
I_STAGED=$''    # nf-fa-plus_circle
I_MOD=$''       # nf-fa-pencil
I_UNTRACKED=$'' # nf-fa-question
I_AHEAD=$''     # nf-fa-arrow_up
I_BEHIND=$''    # nf-fa-arrow_down

# ----------------------------------------------------------------- colours --
opt() { tmux show -gqv "$1" 2>/dev/null; }

PILL="$(opt @vitrum_pill)";     PILL="${PILL:-#22262f}"
PURPLE="$(opt @vitrum_purple)"; PURPLE="${PURPLE:-#bf5af2}"
YELLOW="$(opt @vitrum_yellow)"; YELLOW="${YELLOW:-#ffd60a}"
GREEN="$(opt @vitrum_green)";   GREEN="${GREEN:-#30d158}"
RED="$(opt @vitrum_red)";       RED="${RED:-#ff453a}"
DIM="$(opt @vitrum_dim)";       DIM="${DIM:-#98989d}"

# ------------------------------------------------------------------ branch --
branch="$(git branch --show-current 2>/dev/null)"
if [[ -n "$branch" ]]; then
  label="$I_BRANCH $branch"
else
  # Detached HEAD: the short hash, with the commit glyph instead.
  short="$(git rev-parse --short HEAD 2>/dev/null)" || exit 0
  [[ -n "$short" ]] || exit 0
  label="$I_COMMIT $short"
fi

# ------------------------------------------------------------------ status --
# One porcelain pass; counting in awk beats four more calls to git.
counts="$(git status --porcelain=v1 2>/dev/null | awk '
  { x = substr($0, 1, 1); y = substr($0, 2, 1) }
  x == "?" { untracked++; next }
  x != " " && x != "" { staged++ }
  y != " " && y != "" { modified++ }
  END { printf "%d %d %d", staged + 0, modified + 0, untracked + 0 }
')"
read -r staged modified untracked <<<"$counts"

status=""
[[ "${staged:-0}"    -gt 0 ]] && status+=" #[fg=$GREEN]$I_STAGED $staged"
[[ "${modified:-0}"  -gt 0 ]] && status+=" #[fg=$YELLOW]$I_MOD $modified"
[[ "${untracked:-0}" -gt 0 ]] && status+=" #[fg=$DIM]$I_UNTRACKED $untracked"

# Ahead of / behind the upstream, if there is one.
if upstream="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)" && [[ -n "$upstream" ]]; then
  read -r ahead behind <<<"$(git rev-list --left-right --count "HEAD...$upstream" 2>/dev/null)"
  [[ "${ahead:-0}"  -gt 0 ]] && status+=" #[fg=$GREEN]$I_AHEAD$ahead"
  [[ "${behind:-0}" -gt 0 ]] && status+=" #[fg=$RED]$I_BEHIND$behind"
fi

printf '#[fg=%s,bg=default]%s#[fg=%s,bg=%s] %s%s #[fg=%s,bg=default]%s ' \
  "$PILL" "$CAP_L" "$PURPLE" "$PILL" "$label" "$status" "$PILL" "$CAP_R"
