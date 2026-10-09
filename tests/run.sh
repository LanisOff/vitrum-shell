#!/usr/bin/env bash
# Runs every tests/sh/test_*.sh. A test is a function named test_*; each runs in
# its own bash with a temp HOME and a stub directory first on PATH (tests/sh/lib.sh).
# A failure is any non-zero return. Optional args: test files to run.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
pass=0 fail=0
files=("$@"); [[ ${#files[@]} -eq 0 ]] && files=(tests/sh/test_*.sh)
for f in "${files[@]}"; do
  for t in $(bash -c "source '$f'; declare -F" | awk '{print $3}' | grep '^test_'); do
    if out=$(bash -c "set -euo pipefail; export VITRUM_DIR='$PWD'; source tests/sh/lib.sh; source '$f'; $t" 2>&1 </dev/null); then
      pass=$((pass+1))
    else
      fail=$((fail+1)); printf 'FAIL %s::%s\n%s\n' "$f" "$t" "$out"
    fi
  done
done
printf '%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
