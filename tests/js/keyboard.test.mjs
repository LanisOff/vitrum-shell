import { load, eq } from "./lib.mjs";
const k = load("keyboard.js");
const layouts = ["English (US)", "Russian"];
// Focus moves to an app: its last layout, if it had one and it is not already on.
eq(k.switchTo({ "org.telegram.desktop": "Russian" }, "org.telegram.desktop", layouts, 0), 1, "telegram was Russian");
eq(k.switchTo({ "org.telegram.desktop": "Russian" }, "org.telegram.desktop", layouts, 1), -1, "already Russian");
eq(k.switchTo({}, "kitty", layouts, 1), -1, "a new app keeps what is on");
eq(k.switchTo({ kitty: "German" }, "kitty", layouts, 0), -1, "a layout that is gone");
eq(k.switchTo({ kitty: "English (US)" }, "", layouts, 1), -1, "no app");
// What is remembered: the layout an app was left in.
eq(JSON.stringify(k.remember({ a: "Russian" }, "kitty", "English (US)")), JSON.stringify({ a: "Russian", kitty: "English (US)" }), "remembered");
eq(JSON.stringify(k.remember({ a: "Russian" }, "", "English (US)")), JSON.stringify({ a: "Russian" }), "nothing without an app");
