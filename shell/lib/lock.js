.pragma library
// The lock screen's decisions, apart from its looks: the greeting, what the
// notifications under the clock may say, when the screen goes ambient, and
// which power buttons need a second press.

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
