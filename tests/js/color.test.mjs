import { load, eq, ok } from "./lib.mjs";
const c = load("color.js");
eq(c.toHex(c.parse("#0a84ff")), "#0a84ff", "roundtrip");
eq(c.toHex(c.parse("#fff")), "#ffffff", "short form");
eq(c.toHex(c.parse("#800a84ff")), "#800a84ff", "alpha form keeps alpha");
ok(Math.abs(c.contrast(c.parse("#ffffff"), c.parse("#000000")) - 21) < 0.01, "white/black 21:1");
const fixed = c.ensureContrast("#777777", "#808080", 4.5);
ok(c.contrast(c.parse(fixed), c.parse("#808080")) >= 4.5, "guard reaches 4.5");
eq(c.ensureContrast("#ffffff", "#000000", 4.5), "#ffffff", "already fine unchanged");
eq(c.toHex(c.mix(c.parse("#000000"), c.parse("#ffffff"), 0.5)), "#808080", "mix midpoint");
eq(c.toHex(c.withAlpha(c.parse("#102030"), 0.5)), "#80102030", "withAlpha");
// Dichroic: the second hue is the accent turned by the shift, saturation 0.72,
// lightness per scheme; the shift is clamped and a bad one falls back to −100.
const near = (a, b) => Math.abs(a - b) < 1e-9;
{
  const d = c.dichroic(310 / 360, -100, true);
  ok(near(d.h, 210 / 360) && d.s === 0.72 && d.l === 0.74, `pink → cyan in the dark: ${JSON.stringify(d)}`);
  const l = c.dichroic(20 / 360, -100, false);
  ok(near(l.h, 280 / 360) && l.l === 0.42, `peach → violet in the light, wraps round: ${JSON.stringify(l)}`);
  ok(near(c.dichroic(-1, -100, true).h, 260 / 360), "a grey accent counts as hue 0");
  ok(near(c.dichroic(0.5, "x", true).h, c.dichroic(0.5, -100, true).h) && near(c.dichroic(0.5, "50", true).h, c.dichroic(0.5, -100, true).h), "a shift that is not a number falls back to −100");
  ok(near(c.dichroic(0.5, 999, true).h, 0), "the shift is clamped to 180");
  const m = c.companion(0.01, 0.8, 0.6);
  ok(near(m.h, 0.01 - 30 / 360 + 1) && m.s === 0.8 && near(m.l, 0.68), `a meaning colour keeps its family: ${JSON.stringify(m)}`);
  ok(c.companion(0.1, 0.5, 0.88).l === 0.9, "companion lightness capped");
}
