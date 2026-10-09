import { load, eq } from "./lib.mjs";
const s = load("screencast.js");

const screens = [{ name: "DP-2" }, { name: "HDMI-A-1" }];
const windows = [{ id: 7, appId: "firefox", focusTime: 5 }, { id: 9, appId: "firefox", focusTime: 9 }, { id: 3, appId: "kitty", focusTime: 1 }];

// What to remember: a screen by its connector, a window by its app (window ids do not last).
eq(JSON.stringify(s.entryFor({ kind: "monitor", name: "DP-2" }, true)), JSON.stringify({ type: "monitor", connector: "DP-2", cursor: true }), "screen");
eq(JSON.stringify(s.entryFor({ kind: "window", win: { id: 9, appId: "firefox" } }, false)), JSON.stringify({ type: "window", appId: "firefox", cursor: false }), "window by app");

// The answer for a remembered app, when what it remembered is there and allowed.
{
  const a = s.rememberedAnswer({ "vesktop": { type: "monitor", connector: "HDMI-A-1", cursor: true } }, { app: "vesktop", types: 3 }, screens, windows);
  eq(JSON.stringify(a), JSON.stringify({ ok: true, cursor: true, sources: [{ type: "monitor", connector: "HDMI-A-1" }] }), "remembered screen");
}
{
  const a = s.rememberedAnswer({ "obs": { type: "window", appId: "firefox", cursor: false } }, { app: "obs", types: 2 }, screens, windows);
  eq(JSON.stringify(a), JSON.stringify({ ok: true, cursor: false, sources: [{ type: "window", id: 9 }] }), "the app's most recent window");
}
eq(s.rememberedAnswer({ "vesktop": { type: "monitor", connector: "DP-3" } }, { app: "vesktop", types: 1 }, screens, windows), null, "screen gone: ask");
eq(s.rememberedAnswer({ "vesktop": { type: "monitor", connector: "DP-2" } }, { app: "vesktop", types: 2 }, screens, windows), null, "screens not allowed this time: ask");
eq(s.rememberedAnswer({ "obs": { type: "window", appId: "mpv" } }, { app: "obs", types: 2 }, screens, windows), null, "no such window open: ask");
eq(s.rememberedAnswer({}, { app: "x", types: 3 }, screens, windows), null, "nothing remembered");
eq(s.rememberedAnswer({ "": { type: "monitor", connector: "DP-2" } }, { app: "", types: 1 }, screens, windows), null, "an app without an id is never remembered");
eq(s.rememberedAnswer(null, { app: "x", types: 3 }, screens, windows), null, "no map");

// Several picked at once (apps that allow it): every one, in order.
eq(JSON.stringify(s.sourcesOf([{ kind: "monitor", name: "DP-2" }, { kind: "window", win: { id: 3 } }])),
   JSON.stringify([{ type: "monitor", connector: "DP-2" }, { type: "window", id: 3 }]), "several sources");

// Describing it for the "sharing" toast.
eq(s.describe({ sources: [{ type: "monitor", connector: "DP-2" }] }, windows), "DP-2", "a screen");
eq(s.describe({ sources: [{ type: "window", id: 3 }] }, windows), "a kitty window", "a window");
eq(s.describe({ sources: [{ type: "monitor", connector: "DP-2" }, { type: "window", id: 3 }] }, windows), "2 sources", "several");
