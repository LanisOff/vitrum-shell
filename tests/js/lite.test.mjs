import { load, eq, ok, readJson } from "./lib.mjs";
const L = load("lite.js");
const j = JSON.stringify;
const defaults = readJson("shell/data/settings.defaults.json").lite;
const lite = over => Object.assign(JSON.parse(j(defaults)), over);
const auto = a => lite({ auto: Object.assign({}, defaults.auto, a) });
const laptop = (pluggedIn, percentage, saver) => ({ hasBattery: true, pluggedIn, percentage, saver: !!saver });
const desktop = { hasBattery: false, pluggedIn: true, percentage: 100, saver: false };

// Every part has its default switch, and the defaults cut nothing.
eq(j(L.PARTS.slice().sort()), j(Object.keys(defaults).filter(k => k !== "enabled" && k !== "auto").sort()), "a switch per part in the defaults");
for (const p of L.NIRI_PARTS) ok(L.PARTS.indexOf(p) >= 0, `${p} is a part`);
const off = L.resolve(defaults, desktop);
eq(off.active, false, "off by default");
eq(off.reason, "", "no reason");
eq(L.PARTS.some(p => off.cut[p]), false, "nothing cut by default");

// The master switch cuts everything.
const on = L.resolve(lite({ enabled: true }), desktop);
eq(on.active, true, "master on");
eq(on.reason, "manual", "manual");
eq(L.PARTS.every(p => on.cut[p]), true, "all cut");

// A switch works on its own, with lite mode off.
const one = L.resolve(lite({ blur: true }), desktop);
eq(one.active, false, "one switch: lite mode itself stays off");
eq(j(L.PARTS.filter(p => one.cut[p])), j(["blur"]), "only blur");

// Automatic: on battery.
eq(L.automatic(auto({ onBattery: true }), laptop(false, 80)), "battery", "on battery");
eq(L.automatic(auto({ onBattery: true }), laptop(true, 80)), "", "plugged in: no");
eq(L.automatic(auto({ onBattery: true }), desktop), "", "a desktop is never on battery");
eq(L.automatic(auto({ onBattery: true }), { hasBattery: true, percentage: 50 }), "", "unknown plug state: no");
// Below a level, only on battery (charging at 15 % is no reason).
eq(L.automatic(auto({ lowBattery: true, below: 30 }), laptop(false, 30)), "low", "at the level");
eq(L.automatic(auto({ lowBattery: true, below: 30 }), laptop(false, 31)), "", "above it");
eq(L.automatic(auto({ lowBattery: true, below: 30 }), laptop(true, 10)), "", "low but charging");
eq(L.automatic(auto({ lowBattery: true }), laptop(false, 29)), "low", "the default level is 30");
eq(L.automatic(auto({ onBattery: true, lowBattery: true }), laptop(false, 10)), "battery", "on battery comes first");
// The Saver profile, plugged in or not, desktops too.
eq(L.automatic(auto({ powerSaver: true }), Object.assign({}, desktop, { saver: true })), "saver", "saver on a desktop");
eq(L.automatic(auto({ powerSaver: true }), laptop(true, 90, false)), "", "another profile");
eq(L.automatic(auto({}), laptop(false, 5, true)), "", "nothing chosen: no reason");
eq(L.automatic(null, null), "", "no settings yet");
eq(L.automatic({ auto: { onBattery: "yes" } }, laptop(false, 50)), "", "only true counts");

const ar = L.resolve(auto({ onBattery: true }), laptop(false, 60));
eq(ar.active && ar.reason === "battery" && L.PARTS.every(p => ar.cut[p]), true, "an automatic reason cuts everything");
eq(L.resolve(lite({ enabled: true, auto: { onBattery: true } }), laptop(false, 60)).reason, "manual", "the master switch wins");

// What the shell writes for vitrum-theme: the automatic reason only.
eq(L.stateText(ar), "battery\n", "battery");
eq(L.stateText(on), "\n", "manual: vitrum-theme reads the switch itself");
eq(L.stateText(off), "\n", "off");
eq(L.stateText(null), "\n", "nothing");

// Polling.
eq(L.interval(2000, false), 2000, "as it is");
eq(L.interval(2000, true), 6000, "three times slower");

// The held line, one per reason.
for (const r of ["manual", "battery", "low", "saver"]) ok(L.heldText(r).length > 0, `held text for ${r}`);
eq(L.heldText(""), "", "not held");
