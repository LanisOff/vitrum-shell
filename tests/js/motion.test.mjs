import { load, eq, ok } from "./lib.mjs";
const m = load("motion.js");
// Simulate both springs from 1 → 0 and compare settling (|x|<0.001 and |v|<0.001).
function settleNiri(z, k) { let x = 1, v = 0, t = 0, dt = 1 / 1000, c = 2 * z * Math.sqrt(k);
  while (t < 5) { const a = -k * x - c * v; v += a * dt; x += v * dt; t += dt; if (Math.abs(x) < 1e-3 && Math.abs(v) < 1e-3) return t; } return t; }
function settleQt(p) { let x = 1, v = 0, t = 0, dt = 1 / 1000;
  while (t < 5) { const a = (-p.spring * x * 100 - p.damping * 100 * v) / p.mass; v += a * dt; x += v * dt; t += dt; if (Math.abs(x) < 1e-3 && Math.abs(v) < 1e-3) return t; } return t; }
for (const [z, k] of [[1.0, 900], [1.0, 600], [0.75, 520]]) {
  const a = settleNiri(z, k), b = settleQt(m.qtSpring(z, k));
  ok(Math.abs(a - b) / a < 0.2, `settling ζ=${z} k=${k}: niri ${a.toFixed(3)}s qt ${b.toFixed(3)}s`);
}
eq(m.scaled(300, 2, false), 150, "speed 2 halves");
eq(m.scaled(300, 1, true), 0, "reduce → 0");
