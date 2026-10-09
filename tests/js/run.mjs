// Runs tests/js/*.test.mjs (or the files given). Exit 1 on any failure.
import { readdirSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join, resolve } from "node:path";
import { stats } from "./lib.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const files = args.length ? args.map(a => resolve(a)) : readdirSync(here).filter(f => f.endsWith(".test.mjs")).sort().map(f => join(here, f));
for (const f of files) {
  stats.current = f.split("/").pop();
  try { await import(pathToFileURL(f).href); }
  catch (e) { stats.failures++; console.log(`FAIL ${stats.current}: threw ${String(e && e.message || e).split("\n")[0]}`); }
}
console.log(`${stats.passes} passed, ${stats.failures} failed`);
process.exit(stats.failures ? 1 : 0);
