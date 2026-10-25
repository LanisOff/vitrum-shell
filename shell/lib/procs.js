.pragma library
// The busiest processes, from two readings of /proc a few seconds apart.
// A reading is what the top-processes widget's command prints:
//   page <bytes>            the page size (getconf PAGESIZE)
//   MemTotal: <n> kB        from /proc/meminfo
//   cpu  <user> <nice> …    the first line of /proc/stat (every core, USER_HZ)
//   <pid> (<comm>) <state> … one /proc/<pid>/stat each (kernel threads left out)
// A process's share of the processor is its ticks over the machine's ticks
// between the two readings: 0..1 of the whole machine, so a meter never runs
// past full on a many-core processor.

// → { total, page, memTotal, procs: { pid: { name, ticks, rss } } }
function parseSample(text) {
    var out = { total: 0, page: 4096, memTotal: 0, procs: {} };
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        if (!l) continue;
        if (l.indexOf("page ") === 0) { var pg = parseInt(l.slice(5), 10); if (pg > 0) out.page = pg; continue; }
        if (l.indexOf("MemTotal:") === 0) { out.memTotal = (parseInt(l.slice(9), 10) || 0) * 1024; continue; }
        if (l.indexOf("cpu ") === 0) {
            // user nice system idle iowait irq softirq steal: guest is in user already.
            var c = l.slice(4).trim().split(/\s+/), t = 0;
            for (var k = 0; k < Math.min(8, c.length); k++) t += parseInt(c[k], 10) || 0;
            out.total = t;
            continue;
        }
        // The name sits in brackets and may hold spaces and brackets of its own:
        // it ends at the last ") ".
        var open = l.indexOf(" ("), close = l.lastIndexOf(") ");
        if (open <= 0 || close < open) continue;
        var pid = l.slice(0, open);
        if (!/^\d+$/.test(pid)) continue;
        var f = l.slice(close + 2).split(" ");   // f[0] is field 3 (state)
        if (f.length < 22) continue;
        // Kernel threads (PF_KTHREAD in flags, field 9) are not anyone's program.
        if ((parseInt(f[6], 10) || 0) & 0x00200000) continue;
        out.procs[pid] = { name: l.slice(open + 2, close), ticks: (parseInt(f[11], 10) || 0) + (parseInt(f[12], 10) || 0),
                           rss: parseInt(f[21], 10) || 0 };
    }
    return out;
}

// The top `n` by "cpu" or "memory", from the reading before (`prev`, null at
// first: no processor shares yet) and this one. group: processes of one name
// are added up (a browser's many). → [{ name, cpu, mem, bytes, count }],
// cpu and mem 0..1 of the machine.
function top(prev, cur, by, n, group) {
    if (!cur) return [];
    var dt = prev ? cur.total - prev.total : 0;
    var rows = [], byName = {};
    for (var pid in cur.procs) {
        var p = cur.procs[pid], cpu = 0;
        if (dt > 0) {
            var was = prev.procs[pid];
            // A pid seen before under another name was reused: start from nothing.
            var from = was && was.name === p.name ? was.ticks : 0;
            cpu = Math.max(0, Math.min(1, (p.ticks - from) / dt));
        }
        var bytes = p.rss * cur.page;
        var mem = cur.memTotal > 0 ? Math.min(1, bytes / cur.memTotal) : 0;
        if (group) {
            var g = byName[p.name];
            if (!g) { g = byName[p.name] = { name: p.name, cpu: 0, mem: 0, bytes: 0, count: 0 }; rows.push(g); }
            g.cpu = Math.min(1, g.cpu + cpu); g.mem = Math.min(1, g.mem + mem); g.bytes += bytes; g.count++;
        } else rows.push({ name: p.name, cpu: cpu, mem: mem, bytes: bytes, count: 1 });
    }
    var key = by === "memory" ? "mem" : "cpu";
    rows.sort(function (a, b) { return b[key] - a[key] || b.bytes - a.bytes || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0); });
    return rows.slice(0, Math.max(0, n));
}

// A share as a percentage: one decimal under 10, whole above.
function percent(v) {
    var p = Math.max(0, v) * 100;
    return (p < 10 ? (Math.round(p * 10) / 10).toFixed(1) : String(Math.round(p))) + "%";
}

// Bytes as memory is read: MB under a gigabyte, GB with one decimal above.
function size(bytes) {
    var b = Math.max(0, bytes || 0);
    if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB";
    return Math.round(b / 1048576) + " MB";
}
