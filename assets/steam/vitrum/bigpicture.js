// vitrum for Steam: dress Big Picture's side windows.
//
// Quick Access, the main menu and Big Picture's toasts are small windows Big
// Picture opens for itself. Steam's popup manager does not list them, so
// Millennium's window hook, and with it skin.json's patches, never reach them
// (seen on Millennium 3.6.2: no theme links in them, whatever the regex).
// Steam's gamepad navigation does know them, as the windows it takes input
// from, so this finds them there and links the theme into each one once.
//
// It looks a few times while Big Picture starts and then stops: nothing runs
// afterwards. New colours reach these windows the next time Big Picture opens.
(function () {
  "use strict";
  if (window.__vitrumSideWindows) return;
  window.__vitrumSideWindows = true;

  var BASE = "https://millennium.host/v1/themes/vitrum/";
  var FILES = ["colors.css", "base.css", "steam.css", "bigpicture.css"];
  var NAMES = /^(QuickAccess_|MainMenu_|notificationtoasts_)/;
  var WANTED = 3;
  var EVERY = 1500;
  var TRIES = 20;

  function controller() {
    return window.FocusNavController || (window.opener && window.opener.FocusNavController) || null;
  }

  function dress(doc) {
    if (doc.getElementById("vitrum-side-window")) return;
    FILES.forEach(function (name, i) {
      var link = doc.createElement("link");
      if (i === 0) link.id = "vitrum-side-window";
      link.rel = "stylesheet";
      link.href = BASE + name;
      doc.head.appendChild(link);
    });
  }

  // How many side windows are dressed.
  function scan() {
    var c = controller();
    var found = 0;
    ((c && c.m_rgGamepadInputSources) || []).forEach(function (source) {
      try {
        var doc = source.m_targetWindow.document;
        if (doc.head && NAMES.test(doc.title)) {
          dress(doc);
          found++;
        }
      } catch (e) {
        // A source without a window, or one going away.
      }
    });
    return found;
  }

  var tries = 0;
  var timer = setInterval(function () {
    if (scan() >= WANTED || ++tries >= TRIES) clearInterval(timer);
  }, EVERY);
})();
