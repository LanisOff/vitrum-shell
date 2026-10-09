# shellcheck shell=bash disable=SC1090,SC1091
# Shared test helpers: a temp HOME and a stub directory first on PATH.
HOME="$(mktemp -d)"; export HOME
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_CACHE_HOME="$HOME/.cache"
unset VITRUM_LOG DRY_RUN
STUBS="$(mktemp -d)"; export PATH="$STUBS:$PATH"
stub() { printf '#!/usr/bin/env bash\n%s\n' "${2:-exit 0}" > "$STUBS/$1"; chmod +x "$STUBS/$1"; }
assert_eq() { [[ "$1" == "$2" ]] || { echo "expected [$2] got [$1]"; return 1; }; }
assert_contains() { [[ "$1" == *"$2"* ]] || { echo "[$1] does not contain [$2]"; return 1; }; }
