# shellcheck shell=bash disable=SC1090,SC1091
# Shared test helpers: a temp HOME and a stub directory first on PATH.
HOME="$(mktemp -d)"; export HOME
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_CACHE_HOME="$HOME/.cache"
unset VITRUM_LOG DRY_RUN
# The tests read English messages whatever the machine running them is set to;
# a test about Russian sets the locale itself.
unset VITRUM_LANG VITRUM_MSG_LANG
export VITRUM_DEVICE_LOCALE=en_US.UTF-8
# The test hooks (a fake root, the screens in a file, every stage skipped)
# work only with this set; see lib/common.sh.
export VITRUM_TEST=1
STUBS="$(mktemp -d)"; export PATH="$STUBS:$PATH"
# Backend detection looks for the package tools among the stubs only, not in
# the /usr/bin of the machine running the tests (lib/backend/detect.sh).
export VITRUM_DETECT_PATH="$STUBS"
stub() { printf '#!/usr/bin/env bash\n%s\n' "${2:-exit 0}" > "$STUBS/$1"; chmod +x "$STUBS/$1"; }
assert_eq() { [[ "$1" == "$2" ]] || { echo "expected [$2] got [$1]"; return 1; }; }
assert_contains() { [[ "$1" == *"$2"* ]] || { echo "[$1] does not contain [$2]"; return 1; }; }
