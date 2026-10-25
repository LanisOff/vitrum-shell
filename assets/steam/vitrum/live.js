// vitrum for Steam: follow vitrum's palette without restarting Steam.
//
// colors.css is linked by skin.json when the window opens; vitrum-theme
// rewrites it when the palette (the wallpaper's colours, the accent) changes.
// This re-reads it every few seconds while the window is visible and, only
// when the text changed, puts the new colours in a <style> after the link.
// Nothing runs while the window is hidden, and nothing is redrawn while the
// colours stay the same.
(function () {
  "use strict";
  if (window.__vitrumLive) return;
  window.__vitrumLive = true;

  var URL = "https://millennium.host/v1/themes/vitrum/colors.css";
  var EVERY = 4000;
  var last = null;
  var style = null;

  function put(text) {
    if (!style) {
      style = document.createElement("style");
      style.id = "vitrum-live-colors";
      document.head.appendChild(style);
    }
    style.textContent = text;
  }

  function check() {
    if (document.visibilityState === "hidden") return;
    fetch(URL + "?t=" + Date.now(), { cache: "no-store" })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (text) {
        // Only a real stylesheet: an error page must not replace the colours.
        if (!text || text.indexOf(":root") < 0 || text.indexOf("--vt-accent") < 0) return;
        if (last === null) { last = text; return; }   // what the link already has
        if (text !== last) { last = text; put(text); }
      })
      .catch(function () {});
  }

  check();
  setInterval(check, EVERY);
  document.addEventListener("visibilitychange", check);
})();
