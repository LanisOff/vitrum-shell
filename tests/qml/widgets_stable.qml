import QtQuick
import Quickshell
import qs.services
import "modules/desktop/widgets"

// Live widgets keep their pieces across samples: a sample updates a meter or a
// rate in place. A model rebuilt per sample made every piece again each time,
// and each new meter played its light — an animation, which wakes every
// window of the shell for a frame.
ShellRoot {
    FloatingWindow {
        visible: false
        implicitWidth: 400; implicitHeight: 520
        SystemWidget { id: system; width: 336; height: 160; options: ({ cpu: true, memory: true, temperature: true, style: "rings" }) }
        SystemWidget { id: bars; y: 170; width: 336; height: 160; options: ({ cpu: true, memory: true, temperature: true, style: "bars" }) }
        NetSpeedWidget { id: net; y: 340; width: 336; height: 160 }
    }
    function check(name, ok, why) { console.log((ok ? "PASS " : "FAIL ") + name + (ok ? "" : ": " + why)); }
    function find(item, test, out) {
        for (const c of item.children) { if (test(c)) out.push(c); find(c, test, out); }
        return out;
    }
    function meters(w, kind) { return find(w, c => c.kind === kind && c.thickness !== undefined, []); }
    function rows(w) { return find(w, c => c.modelData !== undefined && c.modelData !== null && c.modelData.t === "Download", []); }

    property var before: ({})
    Timer {
        // After the first samples (and the GPU answering, which adds its meter).
        interval: 3000; running: true
        onTriggered: {
            before = { rings: meters(system, "circular"), bars: meters(bars, "linear"), down: rows(net) };
            later.start();
        }
    }
    Timer {
        id: later
        // Two more samples of each.
        interval: 4500
        onTriggered: {
            const rings = meters(system, "circular"), bs = meters(bars, "linear"), down = rows(net);
            check("rings are there", before.rings.length >= 3, "got " + before.rings.length);
            check("a sample keeps the rings", rings.length === before.rings.length && rings.every((m, i) => m === before.rings[i]),
                  "the rings were made again");
            check("a sample keeps the bars", bs.length === before.bars.length && bs.length >= 3 && bs.every((m, i) => m === before.bars[i]),
                  "the bars were made again");
            check("the ring follows the processor", Math.abs(rings[0].value - SysInfo.cpuUsage) < 1e-6,
                  rings[0].value + " vs " + SysInfo.cpuUsage);
            check("a sample keeps the rate rows", down.length === 1 && down[0] === before.down[0], "the rows were made again");
            console.log("DONE");
            Qt.quit();
        }
    }
}
