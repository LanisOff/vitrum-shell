import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { eq, ok, root, readJson } from "./lib.mjs";

const dir = join(root, "apps/settings/panes");
const files = readdirSync(dir).filter(f => f.endsWith("Pane.qml"));
const text = Object.fromEntries(files.map(f => [f, readFileSync(join(dir, f), "utf8")]));

// key: "x.y" → the files that bind a row to it.
const owners = {};
for (const [f, t] of Object.entries(text))
    for (const m of t.matchAll(/\bkey: "([\w.]+)"/g)) (owners[m[1]] = owners[m[1]] || new Set()).add(f);
for (const [k, fs] of Object.entries(owners)) eq(fs.size, 1, `${k} in one pane only (${[...fs].join(", ")})`);

// Every default leaf key is named somewhere in the panes (a row, or a pane that edits a whole list).
const leaves = [];
(function walk(o, p) {
    for (const [k, v] of Object.entries(o)) {
        const q = p ? p + "." + k : k;
        if (v && typeof v === "object" && !Array.isArray(v) && Object.keys(v).length) walk(v, q); else leaves.push(q);
    }
})(readJson("shell/data/settings.defaults.json"), "");
const named = new Set();
for (const t of Object.values(text)) for (const m of t.matchAll(/"([A-Za-z][\w.]*)"/g)) named.add(m[1]);
for (const k of leaves)
    ok([...named].some(u => u === k || k.startsWith(u + ".") || u.startsWith(k + ".")), `${k} has a home in some pane`);
