.pragma library
// Quickshell's crash reports (~/.cache/quickshell/crashes/<id>/report.txt) turned
// into one line of cause, and which of them are news. Pure, so it is tested
// (tests/js/crashes.test.mjs). vitrum doctor reads the same reports from bash:
// _doc_crash in lib/stages/90-doctor.sh picks the same frame, and both are
// tested on tests/fixtures/crashes.

// Frames that only report the crash: the C library, the runtime, the allocator
// and Qt's fatal path. The frame above them is the one that says something.
var _NOISE_LIB = /(^|\/)(libc|libpthread|libgcc_s|libstdc\+\+|libjemalloc|ld-linux[^/]*)\.so/;
var _NOISE_SYM = /^(raise|abort|gsignal|pthread_kill|__pthread_kill\w*|__restore_rt|__assert\w*|__libc\w*|__GI_\w*|__cxa\w*|__cxxabiv1\S*|__gnu_cxx::\S*|std::terminate|std::__terminate|qt_assert\w*|qt_message\w*|qFatal|QMessageLogger::\S*|QDebug::~QDebug|qs::crash::\S*)$/;

// "void Foo<int>::bar<long>(int) const::{lambda()#1}" → "Foo::bar".
function shortFrame(symbol) {
    var s = String(symbol || "").replace(/\(anonymous namespace\)::/g, "").replace(/\boperator\(\)/g, "operator@");
    for (var was = ""; was !== s;) { was = s; s = s.replace(/<[^<>]*>/g, ""); }
    var paren = s.indexOf("(");
    if (paren >= 0) s = s.slice(0, paren);
    return s.trim().split(/\s+/).pop().replace(/operator@/, "operator()");
}

// "#1  0x7f… in Foo::bar(int) at /usr/lib/libQt6Quick.so.6" → { symbol, file }.
// Frames without a symbol read "#3  0x7f… at /usr/lib/libQt6Quick.so.6".
function _frame(line) {
    var m = /^#\d+\s+(?:0x[0-9a-fA-F]+|\(inlined\))\s+(.*)$/.exec(line);
    if (!m) return null;
    var rest = m[1];
    if (rest.indexOf("at ") === 0) return { symbol: "", file: rest.slice(3) };
    if (rest.indexOf("in ") !== 0) return null;
    var at = rest.lastIndexOf(" at ");
    return { symbol: shortFrame(at < 0 ? rest.slice(3) : rest.slice(3, at)), file: at < 0 ? "" : rest.slice(at + 4) };
}

// A report's text → { signal, config, frame, library }. frame is the top frame
// that means something; library is the top library when no frame has a symbol.
function parseReport(text) {
    var r = { signal: "", config: "", frame: "", library: "" };
    var section = "";
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.indexOf("===== ") === 0) { section = line; continue; }
        if (section.indexOf("Instance Information") >= 0) {
            var m = /^Signal: (.*?)(?: \(\d+\))?$/.exec(line);
            if (m) r.signal = m[1];
            else if (line.indexOf("Config Path: ") === 0) r.config = line.slice(13).trim();
        } else if (section.indexOf("Stacktrace") >= 0 && !r.frame) {
            var f = _frame(line);
            if (!f || _NOISE_LIB.test(f.file)) continue;
            if (f.symbol && !_NOISE_SYM.test(f.symbol)) r.frame = f.symbol;
            else if (!f.symbol && f.file && !r.library) r.library = f.file.split("/").pop().replace(/\.so.*$/, ".so");
        }
    }
    return r;
}

// One line: "Segmentation fault in QQuickListView::viewportMoved".
function cause(report) {
    var signal = report.signal || "Unknown signal";
    if (report.frame) return signal + " in " + report.frame;
    if (report.library) return signal + " in " + report.library + " (no symbols)";
    return signal + " (no usable stack in the report)";
}

// The crash folder is shared by every Quickshell config: Settings runs as its
// own. A crash early enough has no config path yet, and may be ours.
function isShell(report) {
    return !report.config || /\/quickshell\/vitrum\/shell\.qml$/.test(report.config);
}

// The service's scan, newest first: "@@ <mtime>", then that report.
function parseScan(text) {
    return String(text || "").split(/^@@ /m).slice(1).map(function (part) {
        var r = parseReport(part);
        r.time = parseInt(part, 10) || 0;
        return r;
    });
}

// What is news, given the time of the last crash told (null when nothing is
// remembered: a first start, whose old reports are not news). Time and not id:
// a crash without a run id always lands on the same report.txt. A report under
// two seconds old may still be being written, and waits for the next look.
function step(list, seen, now) {
    var done = list.filter(function (r) { return isShell(r) && now - r.time >= 2; });
    if (seen === null || seen === undefined) return { fresh: [], seen: done.length ? done[0].time : 0 };
    var fresh = done.filter(function (r) { return r.time > seen; });
    return { fresh: fresh, seen: fresh.length ? fresh[0].time : seen };
}

// The notification for the new crashes, newest first; when is the newest's time.
function notice(fresh, when) {
    var n = fresh.length;
    return {
        summary: n > 1 ? "The shell crashed " + n + " times and restarted" : "The shell crashed and restarted",
        body: (n > 1 ? "The last one: " : "") + cause(fresh[0]) + ", at " + when + ". See vitrum doctor."
    };
}
