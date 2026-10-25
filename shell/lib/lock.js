.pragma library
// The lock screen's decisions, apart from its looks: the greeting, what the
// notifications under the clock may say, when the screen goes quiet, which
// power buttons need a second press, the picture, Caps Lock and the status row.

function greeting(hour, name) {
    const part = hour >= 5 && hour < 12 ? "morning"
               : hour >= 12 && hour < 17 ? "afternoon"
               : hour >= 17 && hour < 22 ? "evening" : "night";
    return "Good " + part + (name ? ", " + name : "");
}

// What the greeting calls you: the first word of the real name (GECOS), else
// the user name with a capital.
function firstName(realName, user) {
    const real = String(realName || "").split(",")[0].trim().split(/\s+/)[0] || "";
    const u = real || String(user || "");
    return u ? u.charAt(0).toUpperCase() + u.slice(1) : "";
}

function initial(name) {
    const s = String(name || "").trim();
    return s ? s.charAt(0).toUpperCase() : "?";
}

function _plain(s) {
    return String(s || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
}

// Notifications that arrived since the lock, grouped by app (newest first), at
// most `max` groups. mode: "off" — none; "apps" — app and count only;
// "full" — also the latest title and text.
function lockNotifications(history, since, mode, max) {
    if (mode === "off") return [];
    const from = since instanceof Date ? since.getTime() : Number(since) || 0;
    const groups = [];
    const byApp = {};
    for (const item of history || []) {
        const t = item.time instanceof Date ? item.time.getTime() : Number(item.time) || 0;
        if (t < from) continue;
        const app = item.appName || "Notification";
        let g = byApp[app];
        if (!g) {
            if (groups.length >= max) continue;
            g = byApp[app] = { app: app, icon: item.appIcon || "", count: 0,
                               title: mode === "full" ? _plain(item.summary) : "",
                               body: mode === "full" ? _plain(item.body) : "", items: [] };
            groups.push(g);
        }
        g.count++;
        // Full text: the group opens to its newest few.
        if (mode === "full" && g.items.length < 5) g.items.push({ title: _plain(item.summary), body: _plain(item.body) });
    }
    return groups;
}

// Ambient: quiet long enough, and not while a password is half typed.
function ambientActive(now, lastInput, seconds, typing) {
    return seconds > 0 && !typing && now - lastInput >= seconds * 1000;
}

// In the quiet (ambient) screen the field, the power buttons, the status row
// and the rest recede to this, so the clock and the player stand out.
var QUIET_OPACITY = 0.35;

/// How much of a block that is not the clock or the player shows: `amb`
/// (0..1, the quiet mode coming in) takes it down to QUIET_OPACITY, `leave`
/// (0..1, the unlock) takes it out entirely.
function chrome(amb, leave) {
    const a = Math.max(0, Math.min(1, Number(amb) || 0));
    const l = Math.max(0, Math.min(1, Number(leave) || 0));
    return (1 - (1 - QUIET_OPACITY) * a) * (1 - l);
}

/// The entrance: 0 → 1 for the block with this `order` as `enter` goes 0 → 1.
/// The blocks start one after another and every one is in place when `enter`
/// is 1, however many there are (`last` is the highest order). Eased out
/// (quintic: fast, then settling; no overshoot).
function rise(enter, order, last) {
    const n = Math.max(1, Number(last) || 1);
    const span = 0.5, step = (1 - span) / n;
    const t = Math.max(0, Math.min(1, (Number(enter) - Math.min(order, n) * step) / span));
    return 1 - Math.pow(1 - t, 5);
}

// The picture for the avatar, in the order it is looked for: the user's own
// ~/.face, the ~/.face.icon some desktops write, then AccountsService's copy
// (what GNOME, KDE and the greeters set).
function faceCandidates(home, user) {
    const out = [];
    if (home) out.push(home + "/.face", home + "/.face.icon");
    if (user) out.push("/var/lib/AccountsService/icons/" + user);
    return out;
}

/// Caps Lock from the keyboards' LEDs (/sys/class/leds/*::capslock/brightness,
/// one number per keyboard): on when any of them is lit.
function capsLockOn(text) {
    return String(text || "").split(/\s+/).some(s => /^\d+$/.test(s) && Number(s) > 0);
}

/// The network island's words: the Wi-Fi network's name, "Ethernet" for a
/// cable (not the interface's name), "Offline" without either.
function networkLabel(kind, name, online) {
    if (!online || kind === "none") return "Offline";
    if (kind === "wired") return "Ethernet";
    return String(name || "") || "Wi-Fi";
}

/// …and its icon (names from shell/data/icons.json).
function networkIcon(kind, strength, online) {
    if (!online) return "network-off";
    if (kind === "wired") return "ethernet";
    if (kind !== "wifi") return "network-off";
    return strength > 0.66 ? "wifi-high" : strength > 0.33 ? "wifi-medium" : "wifi-low";
}

// The power buttons' words: what each one is (shown under the pointer), and
// what an armed one asks for (short: the button shows which).
function powerLabel(action, armed) {
    const names = { suspend: "Sleep", reboot: "Restart", poweroff: "Power off" };
    const n = names[action] || "";
    return armed && action !== "suspend" ? "Again to " + n.toLowerCase() : n;
}

// Suspend acts at once; restart and power off fire on a second press of the
// same button within windowMs. → { fire: action or "", pending }
function powerPress(pending, action, now, windowMs) {
    if (action === "suspend") return { fire: "suspend", pending: null };
    if (pending && pending.action === action && now - pending.at <= windowMs)
        return { fire: action, pending: null };
    return { fire: "", pending: { action: action, at: now } };
}

function formatDuration(seconds) {
    let s = Math.floor(Number(seconds));
    if (!(s > 0)) s = 0;
    const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
    const pad = n => (n < 10 ? "0" : "") + n;
    return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : m + ":" + pad(sec);
}

// The lock's background picture: the wallpaper if it is an image, the poster
// frame vitrum-theme cut from it if it is a video, else nothing.
function lockBackground(path, poster) {
    const p = String(path || "");
    if (!p) return "";
    return /\.(mp4|mkv|webm|mov|avi|m4v|gif)$/i.test(p) ? String(poster || "") : p;
}
