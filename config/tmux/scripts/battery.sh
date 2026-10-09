#!/usr/bin/env bash
#
#  A battery pill for the tmux status bar.
#
#  Silent on a desktop — no battery, no pill. The glyph follows the charge the
#  way the menu bar's does, and the colour turns amber then red rather than
#  relying on you reading the number.
#
set -u

bat=""
for d in /sys/class/power_supply/BAT*; do
  [[ -r "$d/capacity" ]] && { bat="$d"; break; }
done
[[ -n "$bat" ]] || exit 0

cap="$(cat "$bat/capacity" 2>/dev/null)" || exit 0
[[ "$cap" =~ ^[0-9]+$ ]] || exit 0
state="$(cat "$bat/status" 2>/dev/null || echo Unknown)"

# ------------------------------------------------------------------ glyphs --
CAP_L=$''     # left half circle
CAP_R=$''     # right half circle
I_BOLT=$''    # nf-fa-bolt          charging
I_FULL=$''    # nf-fa-battery_full
I_3Q=$''      # nf-fa-battery_three_quarters
I_HALF=$''    # nf-fa-battery_half
I_1Q=$''      # nf-fa-battery_quarter
I_EMPTY=$''   # nf-fa-battery_empty

# ----------------------------------------------------------------- colours --
opt() { tmux show -gqv "$1" 2>/dev/null; }

PILL="$(opt @vitrum_pill)";     PILL="${PILL:-#22262f}"
FG="$(opt @vitrum_fg)";         FG="${FG:-#e8eaed}"
GREEN="$(opt @vitrum_green)";   GREEN="${GREEN:-#30d158}"
YELLOW="$(opt @vitrum_yellow)"; YELLOW="${YELLOW:-#ffd60a}"
RED="$(opt @vitrum_red)";       RED="${RED:-#ff453a}"

if [[ "$state" == "Charging" || "$state" == "Full" ]]; then
  icon="$I_BOLT"; colour="$GREEN"
elif (( cap >= 90 )); then icon="$I_FULL";  colour="$FG"
elif (( cap >= 65 )); then icon="$I_3Q";    colour="$FG"
elif (( cap >= 40 )); then icon="$I_HALF";  colour="$FG"
elif (( cap >= 15 )); then icon="$I_1Q";    colour="$YELLOW"
else                       icon="$I_EMPTY"; colour="$RED"
fi

# The percent sign is doubled for printf and emitted once, which is what tmux
# then draws. It is not a strftime specifier, so tmux leaves it alone.
printf '#[fg=%s,bg=default]%s#[fg=%s,bg=%s] %s %s%% #[fg=%s,bg=default]%s ' \
  "$PILL" "$CAP_L" "$colour" "$PILL" "$icon" "$cap" "$PILL" "$CAP_R"
