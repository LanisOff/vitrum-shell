# shellcheck shell=bash
# The guard that runs inside every privileged Disk Utility command (shell/lib/disks.js).
_guard() { node -e '
  const fs = require("fs"); const src = fs.readFileSync(process.argv[1], "utf8").replace(/^\.pragma library.*$/m, "");
  const lib = new Function(src + "\nreturn { guardScript };")();
  process.stdout.write(lib.guardScript(process.argv[2]));' "$VITRUM_DIR/shell/lib/disks.js" "$1"; }
_stubs() {
  # / is an LVM volume inside LUKS on sda; nothing else is mounted.
  stub findmnt 'for a; do t="$a"; done; [ "$t" = / ] && echo /dev/mapper/vg-root; true'
  stub lsblk 'for a; do d="$a"; done; case "$d" in
    /dev/mapper/vg-root) printf "vg-root lvm\nluks crypt\nsda2 part\nsda disk\n";;
    /dev/sda1) printf "sda1 part\nsda disk\n";;
    /dev/sdb1) printf "sdb1 part\nsdb disk\n";;
    *) ;; esac'
}
test_guard_refuses_a_partition_of_the_disk_under_an_lvm_in_luks_root() {
  _stubs
  sh -c "$(_guard /dev/sda1) echo REACHED" > "$HOME/out" 2>&1 && { cat "$HOME/out"; return 1; }
  ! grep -q REACHED "$HOME/out"
  assert_contains "$(cat "$HOME/out")" "running system"
}
test_guard_lets_another_disk_through() {
  _stubs
  assert_contains "$(sh -c "$(_guard /dev/sdb1) echo REACHED" 2>&1)" "REACHED"
}
test_guard_refuses_an_unknown_device() {
  _stubs
  ! sh -c "$(_guard /dev/nothing) echo REACHED" > /dev/null 2>&1
}
