import { load, eq } from "./lib.mjs";
const p = load("pointer.js");
eq(JSON.stringify(p.overridden("")), '{"mouse":false,"touchpad":false}', "empty");
eq(p.overridden("input {\n  mouse {\n    accel-speed 0.75\n  }\n}").mouse, true, "mouse block");
eq(p.overridden("input { touchpad { tap } }").touchpad, true, "touchpad on one line");
eq(p.overridden("// input {\n//     mouse {\n// }").mouse, false, "commented out (the starter file)");
eq(p.overridden("/* mouse { } */").mouse, false, "block comment");
eq(p.overridden('window-rule { match app-id="mouse" }').mouse, false, "the word, not a block");
