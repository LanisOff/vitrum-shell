.pragma library
// The graphics card's load and temperature: the one long-lived process SysInfo
// runs for them, and what it prints turned into figures. Pure, and the command
// is run against a fake sysfs (tests/js/gpu.test.mjs).
//
// One process, not one every two seconds: a nvidia-smi started each time
// brought NVML up each time, a hitch in every game. NVIDIA samples on its own
// loop (-l). amdgpu has no such tool, so sh loops over its sysfs files with
// the builtin read, and only sleep forks.

function _nvidia(secs) { return "nvidia-smi -i 0 --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits -l " + secs; }
var _number = /^\d+(\.\d+)?$/;

function _quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

// The sh script for ["sh", "-c", …]. It prints "usage, temp" every `seconds`
// (2 when not given; lite mode's slower figures pass more) and nothing at all
// without a card to read.
//   NVIDIA first, on a hybrid machine too, but only if nvidia-smi answers: a
//   binary left behind with no driver falls through to AMD.
//   Of the amdgpu cards the one with the most VRAM: discrete over integrated.
//   runtime_status is read first, as it does not wake the card: reading the
//   load or the temperature resumes a sleeping one on older kernels, so asleep
//   it says "0, " and the other files stay shut. A load that cannot be read
//   (the card resetting) prints nothing for that round.
//   Each read restarts amdgpu's 5 s autosuspend timer, so a load of 0 skips the
//   next three rounds (6 s) and repeats that sample, letting an idle card sleep.
function command(sysRoot, seconds) {
    var secs = Math.max(1, Math.round(Number(seconds) || 2));
    return [
        "if command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1; then",
        "    exec " + _nvidia(secs),
        "fi",
        "dev='' top=-1",
        "for f in " + _quote(sysRoot || "/sys") + "/class/drm/card*/device/gpu_busy_percent; do",
        "    [ -e \"$f\" ] || continue",
        "    d=${f%/*} v=''",
        "    { read -r v < \"$d/mem_info_vram_total\"; } 2>/dev/null",
        "    case $v in ''|*[!0-9]*) v=0 ;; esac",
        "    if [ \"$v\" -gt \"$top\" ]; then top=$v dev=$d; fi",
        "done",
        "[ -n \"$dev\" ] || exit 0",
        "hot=''",
        "for f in \"$dev\"/hwmon/hwmon*/temp1_input; do",
        "    if [ -e \"$f\" ]; then hot=$f; break; fi",
        "done",
        "idle=0 last=''",
        "while :; do",
        "    s='' b='' m='' t=''",
        "    { read -r s < \"$dev/power/runtime_status\"; } 2>/dev/null",
        "    if [ \"$s\" = suspended ]; then",
        "        idle=0",
        "        printf '0, \\n' || exit 0",
        "    elif [ \"$idle\" -gt 0 ]; then",
        "        idle=$((idle - 1))",
        "        printf '0, %s\\n' \"$last\" || exit 0",
        "    else",
        "        { read -r b < \"$dev/gpu_busy_percent\"; read -r m < \"$hot\"; } 2>/dev/null",
        "        case $m in ''|*[!0-9]*) ;; *) t=$((m / 1000)) ;; esac",
        "        case $b in ''|*[!0-9]*) ;; *) printf '%s, %s\\n' \"$b\" \"$t\" || exit 0 ;; esac",
        "        if [ \"$b\" = 0 ]; then idle=3 last=$t; fi",
        "    fi",
        "    sleep " + secs + " || exit 0",
        "done"
    ].join("\n");
}

// One line of that output → { available, usage 0..1, temp °C }. A temperature
// that is missing or "[N/A]" is 0, which the surfaces read as not known.
function parse(line) {
    var p = String(line || "").split(",").map(function (s) { return s.trim(); });
    if (p.length > 2 || !_number.test(p[0])) return { available: false, usage: 0, temp: 0 };
    return { available: true, usage: Number(p[0]) / 100, temp: _number.test(p[1]) ? Number(p[1]) : 0 };
}
