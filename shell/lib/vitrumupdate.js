.pragma library
// When the bar tells about a new vitrum, and in what words. Pure, so it is
// tested (tests/js/vitrumupdate.test.mjs). It tells once enough commits have
// piled up, or at once for a major version: the first or second number of
// VERSION grew. A version that cannot be read is never major, so the count
// decides then. With no commits missing from the install there is nothing to
// tell; a pull that was cancelled before installing still counts as missing.

// "0.6.0" → [0, 6, 0]; a hotfix's fourth number ("0.6.2.1") is read and
// dropped, since only the first two decide; anything else → null.
function parseVersion(v) {
    var m = /^(\d+)\.(\d+)\.(\d+)(?:\.\d+)?$/.exec(String(v || "").trim());
    return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
}

// An older remote (a local build ahead of it) is not major.
function isMajor(installed, remote) {
    var a = parseVersion(installed), b = parseVersion(remote);
    if (!a || !b) return false;
    return b[0] !== a[0] ? b[0] > a[0] : b[1] > a[1];
}

// { due, major, version }. A threshold of 0 or 1 means any commit.
function decide(behind, threshold, installed, remote) {
    var n = Number(behind) || 0;
    var major = n > 0 && isMajor(installed, remote);
    return { due: major || n >= Math.max(1, Number(threshold) || 0), major: major,
             version: major ? String(remote).trim() : "" };
}

// The island's few characters: the version, or the count.
function badge(notice, behind) { return notice.major ? notice.version : "+" + behind; }

// The panel's headline: why the island is there.
function title(notice, behind) {
    if (notice.major) return "vitrum " + notice.version + " is out";
    return behind === 1 ? "1 new commit in vitrum" : behind + " new commits in vitrum";
}
