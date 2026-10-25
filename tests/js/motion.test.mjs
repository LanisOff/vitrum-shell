import { load, eq, ok } from "./lib.mjs";
const m = load("motion.js");
// Simulate both springs from 1 → 0 and compare settling (|x|<0.001 and |v|<0.001).
function settleNiri(z, k) { let x = 1, v = 0, t = 0, dt = 1 / 1000, c = 2 * z * Math.sqrt(k);
  while (t < 5) { const a = -k * x - c * v; v += a * dt; x += v * dt; t += dt; if (Math.abs(x) < 1e-3 && Math.abs(v) < 1e-3) return t; } return t; }
function settleQt(p) { let x = 1, v = 0, t = 0, dt = 1 / 1000;
  while (t < 5) { const a = (-p.spring * x * 100 - p.damping * 100 * v) / p.mass; v += a * dt; x += v * dt; t += dt; if (Math.abs(x) < 1e-3 && Math.abs(v) < 1e-3) return t; } return t; }
// The lowest x a spring from 1 → 0 reaches: below 0 is an overshoot (a bounce).
function lowest(p) { let x = 1, v = 0, lo = 1, dt = 1 / 2000;
  for (let t = 0; t < 3; t += dt) { const a = (-p.spring * x * 100 - p.damping * 100 * v) / p.mass; v += a * dt; x += v * dt; lo = Math.min(lo, x); } return lo; }
for (const [name, [z, k]] of Object.entries(m.SPRINGS)) {
  const a = settleNiri(z, k), b = settleQt(m.qtSpring(z, k));
  ok(Math.abs(a - b) / a < 0.2, `settling ${name} ζ=${z} k=${k}: niri ${a.toFixed(3)}s qt ${b.toFixed(3)}s`);
  eq(z, 1, `${name} is critically damped`);
  ok(lowest(m.spring(name, 1)) > -1e-3, `${name} never overshoots`);
}
eq(Object.keys(m.SPRINGS).sort().join(","), "smooth,snappy", "no bouncy spring");
eq(m.spring("smooth", 1).spring, 6, "smooth at speed 1");
eq(m.spring("smooth", 2).spring, 24, "stiffness scales with speed²");
eq(m.spring("nope", 1).spring, 6, "unknown token → smooth");
// The drift's ease: a cubic bezier ending at (1, 1) whose y never passes 1.
eq(m.GLIDE.length, 6, "glide is one Qt bezier segment");
ok(m.GLIDE.slice(0, 4).every(v => v >= 0 && v <= 1) && m.GLIDE[4] === 1 && m.GLIDE[5] === 1, "glide has no overshoot");
eq(m.scaled(m.DRIFT_MS, 1, false), 1200, "drift ~1.2 s");
eq(m.scaled(m.SWEEP_MS, 1, false), 1000, "the switch-on sweep ~1 s");
eq(m.scaled(300, 2, false), 150, "speed 2 halves");
eq(m.scaled(300, 1, true), 0, "reduce → 0");
