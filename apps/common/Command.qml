import QtQuick
import Quickshell
import Quickshell.Io

// A command run for its answer: exec(argv, input, then) runs it (after any
// still running), feeds `input` to its stdin, and calls then(code, out, err)
// once it has exited *and* both its outputs have ended — reading a collector
// in onExited alone can see the previous run's text.
Process {
    id: cmd
    property var _queue: []
    property var _then: null
    property string _input: ""
    property int _code: -1
    property bool _outDone: false
    property bool _errDone: false
    property string _out: ""
    property string _err: ""
    readonly property bool busy: running || _queue.length > 0

    function exec(argv, input, then) {
        _queue = _queue.concat([{ argv: argv, input: input || "", then: then || null }]);
        if (!running && _then === null) _next();
    }
    function _next() {
        if (!_queue.length) return;
        const job = _queue[0];
        _queue = _queue.slice(1);
        _then = job.then || (() => {});
        _input = job.input;
        _code = -1; _outDone = false; _errDone = false; _out = ""; _err = "";
        stdinEnabled = _input.length > 0;
        command = job.argv;
        running = true;
    }
    function _check() {
        if (_code < 0 || !_outDone || !_errDone || _then === null) return;
        const f = _then, c = _code, o = _out, e = _err;
        _then = null;
        Qt.callLater(_next);
        f(c, o, e);
    }
    onStarted: if (_input.length) { write(_input + "\n"); stdinEnabled = false; }
    stdout: StdioCollector { onStreamFinished: { cmd._out = text; cmd._outDone = true; cmd._check(); } }
    stderr: StdioCollector { onStreamFinished: { cmd._err = text; cmd._errDone = true; cmd._check(); } }
    onExited: code => { cmd._code = code; cmd._check(); }
}
