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
