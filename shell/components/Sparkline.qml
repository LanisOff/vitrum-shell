import QtQuick
import qs.theme

// A small graph of recent values: the line, turning from `color` to `color2`
// left to right (dichroic: accent → accent2, or a colour and its pair), and a
// soft fill under it fading down. `max` 0 scales to the largest value shown. Drawn on a Canvas: the
// Shape version drew nothing inside the widgets.
Item {
    id: root
    property var values: []
    property color color: Colors.accent
    property color color2: Colors.pair(color)
    property bool fill: true
    property real max: 0
    property real lineWidth: 2
    readonly property real peak: max > 0 ? max : Math.max(1e-9, ...(values.length ? values : [1]))
    readonly property var pts: {
        const n = values.length, out = [];
        if (n < 2) return out;
        for (let i = 0; i < n; i++)
            out.push(Qt.point(i / (n - 1) * width, height - lineWidth - Math.max(0, Math.min(1, values[i] / peak)) * (height - 2 * lineWidth)));
        return out;
    }
    onPtsChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onColor2Changed: canvas.requestPaint()
    onFillChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d"), p = root.pts;
            c.reset();
            if (p.length < 2) return;
            const col = root.color;
            if (root.fill) {
                const g = c.createLinearGradient(0, 0, 0, height);
                g.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0.32));
                g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0));
                c.fillStyle = g;
                c.beginPath();
                c.moveTo(p[0].x, height);
                for (const q of p) c.lineTo(q.x, q.y);
                c.lineTo(p[p.length - 1].x, height);
                c.closePath();
                c.fill();
            }
            const col2 = root.color2;
            const line = c.createLinearGradient(0, 0, width, 0);
            line.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 1));
            line.addColorStop(1, Qt.rgba(col2.r, col2.g, col2.b, 1));
            c.strokeStyle = line;
            c.lineWidth = root.lineWidth;
            c.lineCap = "round";
            c.lineJoin = "round";
            c.beginPath();
            c.moveTo(p[0].x, p[0].y);
            for (let i = 1; i < p.length; i++) c.lineTo(p[i].x, p[i].y);
            c.stroke();
        }
    }
}
