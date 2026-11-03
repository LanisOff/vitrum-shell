import { load, eq, ok, root } from "./lib.mjs";
import { execFileSync, spawn } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
const g = load("gpu.js");
const j = JSON.stringify;

// The parser
eq(j(g.parse("37, 52")), j({ available: true, usage: 0.37, temp: 52 }), "usage and temperature");
eq(j(g.parse(" 100 , 85 ")), j({ available: true, usage: 1, temp: 85 }), "spaces");
eq(j(g.parse("0, ")), j({ available: true, usage: 0, temp: 0 }), "a card asleep: no temperature");
eq(j(g.parse("37,")), j({ available: true, usage: 0.37, temp: 0 }), "no temperature, no space");
eq(j(g.parse("37")), j({ available: true, usage: 0.37, temp: 0 }), "no comma");
eq(j(g.parse("37, [N/A]")), j({ available: true, usage: 0.37, temp: 0 }), "nvidia-smi without a sensor");
eq(g.parse("[N/A], 52").available, false, "no usage");
eq(g.parse("Failed to initialize NVML: Driver/library version mismatch").available, false, "nvidia-smi's error");
eq(g.parse("9 GPUs have fallen off the bus, 3").available, false, "text starting with a digit");
eq(g.parse("").available, false, "an empty line");
eq(g.parse(undefined).available, false, "no line");
eq(g.parse("1, 2, 3").available, false, "too many fields");
for (const l of ["", "0, ", "x, y", "37, [N/A]", "[N/A], [N/A]", ","]) {
  const p = g.parse(l);
  ok(Number.isFinite(p.usage) && Number.isFinite(p.temp), `never NaN: "${l}"`);
}

// The command, as text
const text = g.command();
ok(text.includes("'/sys'/class/drm/card*/device/gpu_busy_percent"), "/sys by default");
ok(text.includes("nvidia-smi -i 0 --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits -l 2"), "nvidia-smi samples on its own loop");
ok(!/\$\([^(]|`|\bcat\b/.test(text), "no command substitution: only sleep forks");

// The command, run. Each scenario gets its own fake sysfs under `base`, whose
// name needs quoting. PATH holds only sleep, and nvidia-smi when a test wants it.
const shells = ["/bin/sh", "/bin/dash", "/usr/bin/dash", "/bin/bash"].filter(s => existsSync(s));
const base = mkdtempSync(join(tmpdir(), "vitrum gpu's-"));
const bin = join(base, "bin");
mkdirSync(bin);
symlinkSync(execFileSync("/bin/sh", ["-c", "command -v sleep"], { encoding: "utf8" }).trim(), join(bin, "sleep"));

let trees = 0;
function tree() { const d = join(base, `sys${trees++}`); mkdirSync(d); return d; }

function put(path, text) { mkdirSync(join(path, ".."), { recursive: true }); writeFileSync(path, text + "\n"); }
function fifo(path) { mkdirSync(join(path, ".."), { recursive: true }); execFileSync("mkfifo", [path]); }
function swap(path, v) { rmSync(path, { force: true }); if (v === "fifo") fifo(path); else put(path, v); }

// A card's files; undefined leaves one out, and a FIFO stands for a file that
// must not be touched: opening it blocks, so a read of it hangs the sampler.
function card(sys, name, { busy, vram, temp, status = "active" }) {
  const dev = join(sys, "class", "drm", name, "device");
  const set = (file, v) => {
    const p = join(dev, file);
    if (v === "fifo") fifo(p);
    else if (v !== undefined) put(p, v);
  };
  set("gpu_busy_percent", busy);
  set("mem_info_vram_total", vram);
  set("hwmon/hwmon3/temp1_input", temp);
  set("power/runtime_status", status);
  return dev;
}

function nvidiaStub(listExit) {
  const dir = mkdtempSync(join(base, "stub-"));
  writeFileSync(join(dir, "nvidia-smi"), `#!/bin/sh\n[ "$1" = -L ] && exit ${listExit}\necho "51, 63"\n`, { mode: 0o755 });
  return dir;
}
const nvidia = nvidiaStub(0), noDriver = nvidiaStub(9);

// Runs the sampler until it has printed `want` lines, has exited or `ms` have
// gone by, then kills it and its sleep. `after(lines)` runs on each new line.
// The long default only costs time on a failure: macOS scans a script it has
// not run before, which took over 1.5 s here. Only a test that expects silence
// passes a short `ms`.
function run(shell, sys, { path = bin, want = 1, ms = 20000, after } = {}) {
  return new Promise(resolve => {
    const child = spawn(shell, ["-c", g.command(sys)], { detached: true, env: { PATH: path }, stdio: ["ignore", "pipe", "pipe"] });
    let out = "", err = "", seen = 0, done = false;
    const lines = () => out.split("\n").slice(0, -1);
    const finish = async exited => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      const got = lines();
      // A line means the sampler is about to fork its sleep. On macOS a SIGKILL
      // in that instant can leave the fork spinning at 100% CPU for good, so
      // the kill waits until the sleep is running.
      if (!exited) {
        await new Promise(r => setTimeout(r, 100));
        try { process.kill(-child.pid, "SIGKILL"); } catch (e) { /* gone */ }
      }
      child.stdout.destroy();
      child.stderr.destroy();
      resolve({ lines: got, exited, err });
    };
    const timer = setTimeout(() => finish(false), ms);
    child.stdout.on("data", d => {
      out += d;
      const l = lines();
      if (l.length > seen) { seen = l.length; if (after) after(l); }
      if (l.length >= want) finish(false);
    });
    child.stderr.on("data", d => { err += d; });
    child.on("close", () => finish(true));
  });
}

const GIB = 1073741824;

try {
  for (const sh of shells) {
    const tag = m => `${sh}: ${m}`;

    // One card, read as nvidia-smi prints it
    let sys = tree();
    card(sys, "card1", { busy: 37, vram: 8 * GIB, temp: 52000 });
    let r = await run(sh, sys);
    eq(j(r.lines), j(["37, 52"]), tag("an AMD card"));
    eq(r.err, "", tag("nothing on stderr"));
    eq(g.parse(r.lines[0]).usage, 0.37, tag("the parser reads it"));

    // The integrated card first, as it usually is: card0
    sys = tree();
    card(sys, "card0", { busy: 5, vram: 512 * 1048576, temp: 41000 });
    card(sys, "card1", { busy: 80, vram: 16 * GIB, temp: 66000 });
    r = await run(sh, sys);
    eq(j(r.lines), j(["80, 66"]), tag("the larger VRAM wins, listed last"));
    sys = tree();
    card(sys, "card0", { busy: 80, vram: 16 * GIB, temp: 66000 });
    card(sys, "card1", { busy: 5, vram: 512 * 1048576, temp: 41000 });
    r = await run(sh, sys);
    eq(j(r.lines), j(["80, 66"]), tag("the larger VRAM wins, listed first"));

    // Connectors and other drivers are not cards
    sys = tree();
    card(sys, "card0", { vram: 16 * GIB, temp: 66000 });
    card(sys, "card1", { busy: 5, temp: 41000 });
    mkdirSync(join(sys, "class", "drm", "card1-DP-1"));
    r = await run(sh, sys);
    eq(j(r.lines), j(["5, 41"]), tag("a card without gpu_busy_percent is skipped, and a missing VRAM file is no failure"));
    eq(r.err, "", tag("the missing VRAM file is silent"));

    // Asleep: the FIFOs prove the load and the temperature stay shut
    sys = tree();
    card(sys, "card1", { busy: "fifo", vram: 8 * GIB, temp: "fifo", status: "suspended" });
    r = await run(sh, sys);
    eq(j(r.lines), j(["0, "]), tag("a suspended card prints no temperature and reads neither file"));
    eq(g.parse(r.lines[0] || "").available, true, tag("a suspended card is still a card"));

    // Files that are missing or hold nonsense
    sys = tree();
    card(sys, "card1", { busy: 37, vram: 8 * GIB });
    r = await run(sh, sys);
    eq(j(r.lines), j(["37, "]), tag("no hwmon: no temperature"));
    eq(r.err, "", tag("no hwmon is silent"));
    sys = tree();
    card(sys, "card1", { busy: 37, vram: "x", temp: "n/a" });
    r = await run(sh, sys);
    eq(j(r.lines), j(["37, "]), tag("nonsense in the temperature and VRAM does not stop the shell"));
    sys = tree();
    card(sys, "card1", { busy: 37, vram: 8 * GIB, temp: 52000, status: undefined });
    r = await run(sh, sys);
    eq(j(r.lines), j(["37, 52"]), tag("no runtime_status: awake"));
    sys = tree();
    card(sys, "card1", { busy: "", vram: 8 * GIB, temp: 52000 });
    r = await run(sh, sys, { ms: 300 });
    eq(j(r.lines), j([]), tag("a load that cannot be read prints nothing"));
    eq(r.exited, false, tag("and the sampler goes on"));

    // Neither vendor
    r = await run(sh, tree());
    eq(j(r.lines), j([]), tag("no card: no output"));
    eq(r.exited, true, tag("no card: it exits"));
    eq(r.err, "", tag("no card: silently"));

    // nvidia-smi
    sys = tree();
    card(sys, "card1", { busy: 37, vram: 8 * GIB, temp: 52000 });
    r = await run(sh, sys, { path: `${nvidia}:${bin}` });
    eq(j(r.lines), j(["51, 63"]), tag("NVIDIA wins on a hybrid machine"));
    r = await run(sh, sys, { path: `${noDriver}:${bin}` });
    eq(j(r.lines), j(["37, 52"]), tag("a nvidia-smi that does not answer falls through to AMD"));
    r = await run(sh, tree(), { path: `${noDriver}:${bin}` });
    eq(j(r.lines), j([]), tag("a leftover nvidia-smi and no AMD card: no output"));
    eq(r.exited, true, tag("a leftover nvidia-smi and no AMD card: it exits"));
  }

  // The FIFO has teeth: an awake card does read it, so the sampler hangs.
  const hang = tree();
  card(hang, "card1", { busy: "fifo", vram: 8 * GIB, temp: 52000 });
  const hung = await run(shells[0], hang, { ms: 300 });
  eq(hung.exited, false, "a FIFO blocks a sampler that reads it");
  eq(j(hung.lines), j([]), "and it prints nothing");

  // The rounds, each two seconds on, side by side so the suite waits only once.
  const files = dev => ({ busy: join(dev, "gpu_busy_percent"), temp: join(dev, "hwmon", "hwmon3", "temp1_input"), status: join(dev, "power", "runtime_status") });
  await Promise.all(shells.flatMap(sh => [
    (async () => {
      const sys = tree();
      const f = files(card(sys, "card1", { busy: 37, vram: 8 * GIB, temp: 52000, status: "suspended" }));
      const r = await run(sh, sys, { want: 2, after: () => put(f.status, "active") });
      eq(j(r.lines), j(["0, ", "37, 52"]), `${sh}: the card woken up shows on the next round`);
    })(),
    (async () => {
      const sys = tree();
      const f = files(card(sys, "card1", { busy: 37, vram: 8 * GIB, temp: 52000 }));
      const r = await run(sh, sys, { want: 2, after: () => swap(f.busy, 38) });
      eq(j(r.lines), j(["37, 52", "38, 52"]), `${sh}: a working card is read every round`);
    })(),
    // A load of 0: FIFOs for the three skipped rounds, so a read of either file
    // hangs there; real files again for the fourth round, which does read.
    (async () => {
      const sys = tree();
      const f = files(card(sys, "card1", { busy: 0, vram: 8 * GIB, temp: 41000 }));
      const after = l => {
        if (l.length === 1) { swap(f.busy, "fifo"); swap(f.temp, "fifo"); }
        if (l.length === 4) { swap(f.busy, 50); swap(f.temp, 44000); }
      };
      const r = await run(sh, sys, { want: 5, after });
      eq(j(r.lines), j(["0, 41", "0, 41", "0, 41", "0, 41", "50, 44"]), `${sh}: an idle card is left alone for three rounds, then read`);
    })(),
    // runtime_status is still read while skipping, and waking ends the skip.
    (async () => {
      const sys = tree();
      const f = files(card(sys, "card1", { busy: 0, vram: 8 * GIB, temp: 41000 }));
      const after = l => {
        if (l.length === 1) put(f.status, "suspended");
        if (l.length === 2) { put(f.status, "active"); swap(f.busy, 50); swap(f.temp, 44000); }
      };
      const r = await run(sh, sys, { want: 3, after });
      eq(j(r.lines), j(["0, 41", "0, ", "50, 44"]), `${sh}: asleep in a skipped round, and read as soon as it wakes`);
    })()
  ]));

  // About's VRAM: SysInfo's own lines, on the same pick as the load.
  const qml = readFileSync(join(root, "shell", "services", "SysInfo.qml"), "utf8");
  const vramLines = qml.match(/if \[ -z "\$v" \]; then\n[\s\S]*?\n\s*fi\n/)[0];
  const vram = (sh, sys) => execFileSync(sh, ["-c", `v=''\n${vramLines.replace("/sys/class", `'${sys.replace(/'/g, "'\\''")}'/class`)}printf %s "$v"`], { encoding: "utf8", env: { PATH: bin }, stdio: ["ignore", "pipe", "pipe"] });
  for (const sh of shells) {
    let sys = tree();
    card(sys, "card0", { busy: 5, vram: 512 * 1048576 });
    card(sys, "card1", { busy: 80, vram: 16 * GIB });
    eq(vram(sh, sys), "16384", `${sh}: About's VRAM is the larger card's, listed last`);
    sys = tree();
    card(sys, "card0", { busy: 80, vram: 16 * GIB });
    card(sys, "card1", { busy: 5, vram: 512 * 1048576 });
    eq(vram(sh, sys), "16384", `${sh}: About's VRAM is the larger card's, listed first`);
    sys = tree();
    card(sys, "card0", { busy: 80, vram: "x" });
    card(sys, "card1", { busy: 5, vram: 512 * 1048576 });
    eq(vram(sh, sys), "512", `${sh}: nonsense in one card's file is skipped`);
    eq(vram(sh, tree()), "", `${sh}: no card, no VRAM`);
  }
} finally {
  rmSync(base, { recursive: true, force: true });
}

// Lite mode's slower figures: the same loop, at another pace (whole seconds, at least one).
const slow = g.command("", 6);
ok(slow.includes("--format=csv,noheader,nounits -l 6"), "nvidia-smi at the slower pace");
ok(slow.includes("sleep 6 || exit 0"), "amdgpu's loop at the slower pace");
ok(g.command("", 0.2).includes("sleep 1 ||"), "never under a second");
ok(g.command().includes("sleep 2 ||"), "two seconds by default");
