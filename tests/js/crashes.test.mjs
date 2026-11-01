import { readFileSync } from "node:fs";
import { join } from "node:path";
import { load, eq, root } from "./lib.mjs";
const c = load("crashes.js");
const j = JSON.stringify;
const fixture = n => readFileSync(join(root, "tests", "fixtures", "crashes", n), "utf8");

// A symbol → the name a person can look up
eq(c.shortFrame("QQuickListView::viewportMoved(QFlags<Qt::Orientation>)"), "QQuickListView::viewportMoved", "arguments go");
eq(c.shortFrame("QPlatformScreen::screen() const"), "QPlatformScreen::screen", "const goes");
eq(c.shortFrame("void Foo<int, QList<int>>::bar<long>(int) const::{lambda()#1}::operator()() const"), "Foo::bar", "return type, templates and the lambda go");
eq(c.shortFrame("QtPrivate::QCallableObject<Fn, List<>, void>::operator()(int)"), "QtPrivate::QCallableObject::operator()", "a call operator stays one");
eq(c.shortFrame("qs::(anonymous namespace)::run()"), "qs::run", "anonymous namespaces go");
eq(c.shortFrame(""), "", "no symbol");

// The real shape: libc on top with no symbol, then the frame that matters
const segv = c.parseReport(fixture("segv.txt"));
eq(segv.signal, "Segmentation fault", "signal without its number");
eq(segv.frame, "QQuickListView::viewportMoved", "frame #0 in libc is skipped");
eq(segv.config, "/home/test/.config/quickshell/vitrum/shell.qml", "config");
eq(c.cause(segv), "Segmentation fault in QQuickListView::viewportMoved", "one line");

// An abort: everything between the signal and the caller is machinery
const abrt = c.parseReport(fixture("abort.txt"));
eq(abrt.signal, "Aborted", "abort");
eq(abrt.frame, "qs::service::Node::bind", "the frames that only report the crash are skipped");

const stack = (...frames) => "===== Instance Information =====\nSignal: Bus error (7)\n\n===== Stacktrace =====\n" + frames.join("\n") + "\n\n===== Log Tail =====\nx\n";
// No symbols anywhere: the library is what is left to say
const nosym = c.parseReport(stack("#0  0x00007f at /usr/lib/libc.so.6", "#1  0x00007f at /usr/lib/libnvidia-glcore.so.575.64"));
eq(nosym.frame, "", "no symbol, no frame");
eq(nosym.library, "libnvidia-glcore.so", "the library");
eq(c.cause(nosym), "Bus error in libnvidia-glcore.so (no symbols)", "says so");
// A frame with file and line
eq(c.parseReport(stack("#0  0x00007f in foo::bar(int) at /src/foo.cpp:12:3")).frame, "foo::bar", "debug info");
eq(c.parseReport(stack("#0  (inlined) in foo::inner() at /src/foo.cpp:9", "#1  0x00007f in foo::bar()")).frame, "foo::inner", "an inlined frame counts");
// Nothing usable
const empty = c.parseReport(stack("(no trace available)"));
eq(c.cause(empty), "Bus error (no usable stack in the report)", "falls back to the signal");
eq(c.cause(c.parseReport(stack("#0  0x00007f at /usr/lib/libc.so.6"))), "Bus error (no usable stack in the report)", "only libc");
eq(c.cause(c.parseReport("")), "Unknown signal (no usable stack in the report)", "an empty or cut off report");
// Text after the stack is not a stack
eq(c.parseReport("===== Stacktrace =====\n(no trace available)\n\n===== Log Tail =====\n#1  0x00007f in log::line()\n").frame, "", "the log tail is not read");
eq(c.parseReport("===== Build Information =====\nSignal: nope\n").signal, "", "Signal outside the instance section");

// Whose crash: Settings runs as its own Quickshell config, in the same folder
eq(c.isShell({ config: "/home/x/.config/quickshell/vitrum/shell.qml" }), true, "the shell");
eq(c.isShell({ config: "/home/x/.config/quickshell/vitrum-settings/shell.qml" }), false, "Settings is not the shell");
eq(c.isShell({ config: "/home/x/.config/quickshell/other/shell.qml" }), false, "someone else's config");
eq(c.isShell({ config: "" }), true, "a crash before the config was known may be ours");

// The scan: "@@ <mtime>" and then that report
const scan = "@@ 2000\n" + fixture("segv.txt") + "@@ 1000\n" + fixture("abort.txt") + "@@ 900\n";
const list = c.parseScan(scan);
eq(j(list.map(r => r.time)), "[2000,1000,900]", "each report");
eq(list[1].frame, "qs::service::Node::bind", "parsed");
eq(list[2].signal, "", "a report with nothing in it");
eq(j(c.parseScan("")), "[]", "no reports");

const r = (time, config) => ({ time, config: config === undefined ? "/x/quickshell/vitrum/shell.qml" : config });
const NOW = 5000;
// First start on a machine: old reports are not news, and a first crash later is
let s = c.step([r(2000), r(1000)], null, NOW);
eq(j(s.fresh), "[]", "first start says nothing");
eq(s.seen, 2000, "and remembers the newest");
s = c.step([], null, NOW);
eq(s.seen, 0, "no reports: remembers that");
eq(s.fresh.length, 0, "nothing to say");
eq(c.step([r(2000)], 0, NOW).fresh.length, 1, "so the first crash ever is told");
// Normal restarts: nothing new
s = c.step([r(2000), r(1000)], 2000, NOW);
eq(s.fresh.length, 0, "the same crash is not told twice");
eq(s.seen, 2000, "seen stays");
// New ones, newest first
s = c.step([r(3000), r(2500), r(2000)], 2000, NOW);
eq(j(s.fresh.map(x => x.time)), "[3000,2500]", "every new one");
eq(s.seen, 3000, "the newest is remembered");
// A report still being written is left for the next look
s = c.step([r(NOW - 1)], 2000, NOW);
eq(s.fresh.length, 0, "too young");
eq(s.seen, 2000, "and not remembered");
eq(c.step([r(NOW - 2)], 2000, NOW).fresh.length, 1, "two seconds on it is done");
// Settings crashing is neither told nor remembered
s = c.step([r(3000, "/x/quickshell/vitrum-settings/shell.qml"), r(2000)], 2000, NOW);
eq(s.fresh.length, 0, "Settings is not told");
eq(s.seen, 2000, "nor remembered");

// The notification
let n = c.notice([segv], "12:58");
eq(n.summary, "The shell crashed and restarted", "one crash");
eq(n.body, "Segmentation fault in QQuickListView::viewportMoved, at 12:58. See vitrum doctor.", "cause and time");
n = c.notice([segv, abrt, abrt], "12:58");
eq(n.summary, "The shell crashed 3 times and restarted", "several");
eq(n.body, "The last one: Segmentation fault in QQuickListView::viewportMoved, at 12:58. See vitrum doctor.", "the newest is the one told");
