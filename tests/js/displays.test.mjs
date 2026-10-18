import { load, eq } from "./lib.mjs";
const d = load("displays.js");

eq(d.outputsKdl([]), "// Written by vitrum Settings → Displays.\n", "nothing set");
eq(d.outputsKdl([{ name: "DP-1", mode: "2560x1440@143.912", scale: 1.25 }]),
   '// Written by vitrum Settings → Displays.\noutput "DP-1" {\n    mode "2560x1440@143.912"\n    scale 1.25\n}\n', "mode and scale");
eq(d.outputsKdl([{ name: "HDMI-A-1", scale: 1 }]),
   '// Written by vitrum Settings → Displays.\noutput "HDMI-A-1" {\n    scale 1.0\n}\n', "KDL floats keep a decimal point");
eq(d.outputsKdl([{ name: "eDP-1", off: true }]),
   '// Written by vitrum Settings → Displays.\noutput "eDP-1" {\n    off\n}\n', "off");
eq(d.outputsKdl([{ name: 'we"ird', scale: 2 }]).indexOf('output "we\\"ird"') > 0, true, "quotes escaped");

// niri's outputs JSON → modes as "WxH@R" strings, the current first.
const o = { name: "DP-1", current_mode: 1, modes: [{ width: 1920, height: 1080, refresh_rate: 60000 }, { width: 2560, height: 1440, refresh_rate: 143912 }], logical: { scale: 1.25 } };
eq(JSON.stringify(d.modes(o)), JSON.stringify(["2560x1440@143.912", "1920x1080@60.000"]), "modes, current first");
eq(d.scaleOf(o), 1.25, "scale");

// Variable refresh rate: always on, or only while a game asks (on-demand).
eq(d.outputsKdl([{ name: "DP-2", vrr: "on" }]),
   '// Written by vitrum Settings → Displays.\noutput "DP-2" {\n    variable-refresh-rate\n}\n', "vrr on");
eq(d.outputsKdl([{ name: "DP-2", vrr: "on-demand" }]),
   '// Written by vitrum Settings → Displays.\noutput "DP-2" {\n    variable-refresh-rate on-demand=true\n}\n', "vrr on demand");
eq(d.outputsKdl([{ name: "DP-2", vrr: "off" }]),
   '// Written by vitrum Settings → Displays.\noutput "DP-2" {\n}\n', "vrr off writes nothing");
eq(d.vrrSupported({ vrr_supported: true }), true, "supported");
eq(d.vrrSupported({}), false, "unknown is unsupported");

// Resolution and refresh rate, apart: each size once (largest first), its rates
// rounded to whole Hz (the best exact mode kept for each), highest first.
const m = (w, h, r) => ({ width: w, height: h, refresh_rate: r });
const g = { current_mode: 0, modes: [m(1920, 1080, 239760), m(1920, 1080, 60000), m(1920, 1080, 119880), m(1920, 1080, 119982),
                                     m(1680, 1050, 59954), m(2560, 1440, 143912), m(1920, 1080, 59940)] };
eq(JSON.stringify(d.resolutions(g)), JSON.stringify(["2560x1440", "1920x1080", "1680x1050"]), "sizes, largest first");
eq(JSON.stringify(d.rates(g, "1920x1080").map(r => r.hz)), JSON.stringify([240, 120, 60]), "rates rounded, deduped, highest first");
eq(d.rates(g, "1920x1080")[1].mode, "1920x1080@119.982", "the best exact mode per rounded rate");
eq(d.rates(g, "1920x1080")[2].mode, "1920x1080@60.000", "60.000 beats 59.940");
eq(d.rates(g, "800x600").length, 0, "no such size");
// A new size keeps the rate if it has it, otherwise its highest.
eq(d.pick(g, "1680x1050", 240), "1680x1050@59.954", "no 240 there: its highest");
eq(d.pick(g, "1920x1080", 60), "1920x1080@60.000", "same rate kept");
// The usual sizes: the native one's shape, at least 1280 wide; the one in use always.
const h = { modes: [m(1920, 1080, 60000), m(1680, 1050, 60000), m(1600, 900, 60000), m(1280, 1024, 60000), m(1280, 720, 60000), m(1024, 768, 60000), m(640, 480, 60000)] };
eq(JSON.stringify(d.usualResolutions(h, "")), JSON.stringify(["1920x1080", "1600x900", "1280x720"]), "same shape, big enough");
eq(JSON.stringify(d.usualResolutions(h, "1024x768")), JSON.stringify(["1920x1080", "1600x900", "1280x720", "1024x768"]), "the current one kept");

// Rotation, position, the screen focused at startup.
eq(d.outputsKdl([{ name: "DP-1", transform: "90", position: { x: 1920.4, y: 0 }, primary: true }]),
   '// Written by vitrum Settings → Displays.\noutput "DP-1" {\n    transform "90"\n    position x=1920 y=0\n    focus-at-startup\n}\n', "transform, position, primary");
eq(d.outputsKdl([{ name: "DP-1", transform: "normal" }]).indexOf("transform"), -1, "normal writes nothing");
eq(d.outputsKdl([{ name: "DP-1", off: true, primary: true, position: { x: 0, y: 0 } }]),
   '// Written by vitrum Settings → Displays.\noutput "DP-1" {\n    off\n}\n', "an output that is off has nothing else");
// A mirror: a window rule for wl-mirror's window on the target.
const mk = d.outputsKdl([{ name: "HDMI-A-1", mirror: "eDP-1" }]);
eq(mk.indexOf('match app-id="^at\\\\.yrlf\\\\.wl_mirror$" title="^vitrum mirror eDP-1 on HDMI-A-1$"') > 0, true, "rule matches the mirror's title");
eq(mk.indexOf('open-on-output "HDMI-A-1"') > 0 && mk.indexOf("open-fullscreen true") > 0, true, "fullscreen on the target");
eq(d.outputsKdl([{ name: "HDMI-A-1", mirror: "eDP-1", off: true }]).indexOf("window-rule"), -1, "no rule for a screen that is off");
eq(JSON.stringify(d.mirrors({ "HDMI-A-1": { mirror: "eDP-1" }, "DP-2": { mirror: "DP-9" }, "DP-3": { mirror: "DP-3" }, "DP-4": { mirror: "eDP-1", off: true } }, ["eDP-1", "HDMI-A-1", "DP-2", "DP-3", "DP-4"])),
   JSON.stringify([{ source: "eDP-1", target: "HDMI-A-1" }]), "mirrors: both there, not itself, target on");

eq(d.transformOf({ logical: { transform: "Normal" } }), "normal", "transform from JSON");
eq(d.transformOf({ logical: { transform: "270" } }), "270", "270");
eq(d.transformOf({ logical: { transform: "Flipped90" } }), "flipped-90", "flipped-90");
eq(d.transformOf({ logical: null }), "normal", "off: normal");

const out1 = { current_mode: 0, modes: [m(2560, 1440, 144000)], logical: { x: 0, y: 0, width: 2048, height: 1152, scale: 1.25, transform: "Normal" } };
eq(JSON.stringify(d.logicalSize(out1)), JSON.stringify({ w: 2048, h: 1152 }), "mode over scale");
eq(JSON.stringify(d.logicalSize(out1, { transform: "90", scale: 1 })), JSON.stringify({ w: 1440, h: 2560 }), "turned");
eq(JSON.stringify(d.logicalSize(out1, { mode: "1920x1080@60.000", scale: 1 })), JSON.stringify({ w: 1920, h: 1080 }), "a chosen mode");

// Dropping a screen: against the nearest edge, lined up when close, never overlapping.
const A = { x: 0, y: 0, w: 1920, h: 1080 }, B = { x: 1920, y: 0, w: 1920, h: 1080 };
eq(JSON.stringify(d.snap([A, B], 1, 2100, 60)), JSON.stringify({ x: 1920, y: 0 }), "back to the right edge, top aligned");
eq(JSON.stringify(d.snap([A, B], 1, -1700, 500)), JSON.stringify({ x: -1920, y: 500 }), "to the left, where it was dropped");
eq(JSON.stringify(d.snap([A, B], 1, 900, -900)), JSON.stringify({ x: 900, y: -1080 }), "above");
eq(JSON.stringify(d.snap([A, B], 1, 30, 1000)), JSON.stringify({ x: 0, y: 1080 }), "below, left aligned");
eq(JSON.stringify(d.snap([A], 0, 500, 500)), JSON.stringify({ x: 0, y: 0 }), "alone: at the origin");
const C = { x: 0, y: 0, w: 1080, h: 1920 };
eq(JSON.stringify(d.snap([A, C], 1, 1900, 400)), JSON.stringify({ x: 1920, y: 400 }), "a portrait screen beside");
eq(JSON.stringify(d.normalize([{ x: -1920, y: 200, w: 1, h: 1 }, { x: 0, y: 0, w: 1, h: 1 }])),
   JSON.stringify([{ x: 0, y: 200, w: 1, h: 1 }, { x: 1920, y: 0, w: 1, h: 1 }]), "normalized to 0,0");
