# shellcheck shell=bash
# Every shader's compiled .qsb (what Qt loads) is built from the shader as it is.
test_every_qsb_matches_its_shader() {
  local f sum n=0
  while IFS= read -r f; do
    [[ -f "$f.qsb" ]] || { echo "$f has no .qsb: run tools/build-shaders"; return 1; }
    sum="$(shasum -a 256 "$f" 2>/dev/null || sha256sum "$f")"
    assert_eq "$(cat "$f.sum" 2>/dev/null)" "${sum%% *}" || { echo "$f changed since its .qsb: run tools/build-shaders"; return 1; }
    n=$((n + 1))
  done < <(find "$VITRUM_DIR/shell" -name '*.frag')
  [[ $n -gt 0 ]]
}
