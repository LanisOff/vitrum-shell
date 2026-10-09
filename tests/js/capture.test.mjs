import { load, eq } from "./lib.mjs";
const c = load("capture.js");
const j = JSON.stringify;

// A drag in any direction becomes a rectangle, clamped to the screen.
const b = { w: 1920, h: 1080 };
eq(j(c.normRect(100, 200, 50, 20, b)), j({ x: 50, y: 20, w: 50, h: 180 }), "drag up-left");
eq(j(c.normRect(-10, 1000, 30, 1200, b)), j({ x: 0, y: 1000, w: 30, h: 80 }), "clamped to the screen");
eq(j(c.normRect(5.4, 5.6, 105.4, 105.6, b)), j({ x: 5, y: 6, w: 100, h: 100 }), "whole logical pixels");

// Resizing by a handle keeps the opposite edge fixed and never inverts.
const r = { x: 100, y: 100, w: 200, h: 100 };
eq(j(c.resize(r, "br", 50, 20, b)), j({ x: 100, y: 100, w: 250, h: 120 }), "bottom-right handle");
eq(j(c.resize(r, "tl", -30, -10, b)), j({ x: 70, y: 90, w: 230, h: 110 }), "top-left handle");
eq(j(c.resize(r, "l", 500, 0, b)), j({ x: 299, y: 100, w: 1, h: 100 }), "left edge past the right one stops at 1px");
eq(j(c.resize(r, "move", 2000, 0, b)), j({ x: 1720, y: 100, w: 200, h: 100 }), "moving stays on screen");

// grim and wf-recorder geometry: "x,y wxh" in global logical coordinates.
eq(c.geometry({ x: 10, y: 20, w: 300, h: 40 }, { x: 1920, y: 0 }), "1930,20 300x40", "geometry adds the output origin");
eq(c.gsrRegion({ x: 10, y: 20, w: 300, h: 40 }, { x: 1920, y: 0 }), "300x40+1930+20", "gpu-screen-recorder region");

// File names sort by time and carry no colons.
const d = new Date(2026, 9, 2, 9, 5, 7);
eq(c.fileName("photo", d), "Screenshot 2026-10-02 09-05-07.png", "screenshot name");
eq(c.fileName("video", d), "Recording 2026-10-02 09-05-07.mp4", "recording name");

// Recorder command lines.
const area = { output: "DP-1", origin: { x: 0, y: 0 }, rect: { x: 1, y: 2, w: 30, h: 40 }, file: "/v/a.mp4", audio: "", fps: 60 };
eq(j(c.recorderCommand("gpu-screen-recorder", area)),
   j(["gpu-screen-recorder", "-w", "region", "-region", "30x40+1+2", "-f", "60", "-o", "/v/a.mp4"]), "gsr area");
eq(j(c.recorderCommand("gpu-screen-recorder", Object.assign({}, area, { rect: null, audio: "system" }))),
   j(["gpu-screen-recorder", "-w", "DP-1", "-f", "60", "-a", "default_output", "-o", "/v/a.mp4"]), "gsr screen with system sound");
eq(j(c.recorderCommand("gpu-screen-recorder", Object.assign({}, area, { audio: "both" }))).indexOf('"default_output|default_input"') > 0, true, "gsr mixes both itself");
eq(j(c.recorderCommand("wf-recorder", area)),
   j(["wf-recorder", "-y", "-g", "1,2 30x40", "-r", "60", "-f", "/v/a.mp4"]), "wf-recorder area");
eq(j(c.recorderCommand("wf-recorder", Object.assign({}, area, { rect: null, audio: "system" }))),
   j(["wf-recorder", "-y", "-o", "DP-1", "-r", "60", "--audio=@DEFAULT_MONITOR@", "-f", "/v/a.mp4"]), "wf-recorder: system sound is the output's monitor");
eq(j(c.recorderCommand("wf-recorder", Object.assign({}, area, { audio: "mic" }))).indexOf('"--audio=@DEFAULT_SOURCE@"') > 0, true, "wf-recorder: the microphone");
// wf-recorder takes one device: both go through a mix the capture service sets up.
eq(j(c.recorderCommand("wf-recorder", Object.assign({}, area, { audio: "both" }))).indexOf('"--audio=vitrum_rec.monitor"') > 0, true, "wf-recorder: the mix");
// What to record from the two switches.
eq(c.audioMode(true, false), "system", "system sound");
eq(c.audioMode(false, true), "mic", "microphone");
eq(c.audioMode(true, true), "both", "both");
eq(c.audioMode(false, false), "", "silent");
eq(c.needsMix("wf-recorder", "both"), true, "wf-recorder needs the mix for both");
eq(c.needsMix("gpu-screen-recorder", "both"), false, "gsr mixes itself");
eq(c.needsMix("wf-recorder", "mic"), false, "one device needs no mix");

// Which recorder: the setting, or the first one installed.
// wf-recorder by default: it uses the compositor's screencopy, which niri has
// everywhere; gpu-screen-recorder hung silently on niri + NVIDIA (no file, no log).
eq(c.pickRecorder("auto", { "gpu-screen-recorder": true, "wf-recorder": true }), "wf-recorder", "auto prefers wf-recorder");
eq(c.pickRecorder("auto", { "gpu-screen-recorder": true, "wf-recorder": false }), "gpu-screen-recorder", "auto falls back to gsr");
// A recorder that writes nothing after starting is replaced by the other one, once.
eq(c.otherRecorder("wf-recorder", { "gpu-screen-recorder": true, "wf-recorder": true }), "gpu-screen-recorder", "the other one");
eq(c.otherRecorder("gpu-screen-recorder", { "gpu-screen-recorder": true, "wf-recorder": true }), "wf-recorder", "and back");
eq(c.otherRecorder("wf-recorder", { "wf-recorder": true }), "", "nothing else installed");
eq(c.pickRecorder("wf-recorder", { "gpu-screen-recorder": true, "wf-recorder": true }), "wf-recorder", "explicit choice");
eq(c.pickRecorder("auto", {}), "", "none installed");

// A selection too small to mean anything is a click, not an area.
eq(c.isClick({ x: 0, y: 0, w: 3, h: 2 }), true, "tiny drag is a click");
eq(c.isClick({ x: 0, y: 0, w: 3, h: 40 }), false, "thin but long is an area");

// Toolbar size label.
eq(c.sizeLabel({ x: 0, y: 0, w: 640, h: 480 }, 1.5), "960 × 720", "physical pixels");
