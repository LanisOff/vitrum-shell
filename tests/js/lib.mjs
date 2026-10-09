// Helpers for the shell's pure JS library tests. shell/lib/*.js start with
// `.pragma library` (QML) and define top-level functions; load() strips the
// pragma and returns every top-level function by name.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

export const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");

export function load(name) {
  const src = readFileSync(join(root, "shell", "lib", name), "utf8").replace(/^\.pragma library.*$/m, "");
  const names = [...src.matchAll(/^(?:function|var)\s+([A-Za-z_]\w*)/gm)].map(m => m[1]);
  return new Function(src + `\nreturn { ${names.join(", ")} };`)();
}
export function readJson(rel) { return JSON.parse(readFileSync(join(root, rel), "utf8")); }

export const stats = { passes: 0, failures: 0, current: "" };
export function eq(a, b, msg = "") {
  if (a === b) { stats.passes++; return; }
  stats.failures++; console.log(`FAIL ${stats.current}: ${msg} — expected ${JSON.stringify(b)} got ${JSON.stringify(a)}`);
}
export function ok(v, msg = "") {
  if (v) { stats.passes++; return; }
  stats.failures++; console.log(`FAIL ${stats.current}: ${msg}`);
}
