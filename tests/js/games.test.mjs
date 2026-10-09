import { load, eq } from "./lib.mjs";
const g = load("games.js");

// What counts as a game: Steam games, gamescope, and the user's own list.
eq(g.isGame({ appId: "steam_app_570" }, []), true, "a Steam game");
eq(g.isGame({ appId: "gamescope" }, []), true, "gamescope");
eq(g.isGame({ appId: "steam" }, []), false, "the Steam client is not a game");
eq(g.isGame({ appId: "firefox" }, []), false, "a browser is not a game");
eq(g.isGame({ appId: "org.prismlauncher.PrismLauncher" }, []), false, "a launcher is not a game");
eq(g.isGame({ appId: "Minecraft* 1.21" }, ["minecraft"]), true, "the user's list, case-insensitive substring");
eq(g.isGame({ appId: "", title: "" }, ["x"]), false, "nothing is not a game");
eq(g.isGame(null, []), false, "no window");

// Fullscreen: the window is as big as its output (niri has no flag for it).
const out = { width: 1920, height: 1080 };
eq(g.isFullscreen({ layout: { window_size: [1920, 1080] } }, out), true, "covers the output");
eq(g.isFullscreen({ layout: { window_size: [1920, 1026] } }, out), false, "maximized is not fullscreen");
eq(g.isFullscreen({ layout: { window_size: [945, 1014] } }, out), false, "a column");
eq(g.isFullscreen({ layout: null }, out), false, "no layout");
eq(g.isFullscreen({ layout: { window_size: [1920, 1080] } }, null), false, "no output");
// Scaled outputs report logical sizes; the window size is logical too.
eq(g.isFullscreen({ layout: { window_size: [1280, 720] } }, { width: 1280, height: 720 }), true, "scaled output");
