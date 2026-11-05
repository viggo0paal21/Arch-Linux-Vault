import QtQuick
import qs.config

// Mini history graph. values: array of numbers 0..1 (or 0..max).
Canvas {
    id: root

    property var values: []
    property real max: 1
    property color stroke: Theme.fg
    property int capacity: 60

    implicitHeight: 42
    implicitWidth: 200
    renderStrategy: Canvas.Cooperative

    onValuesChanged: requestPaint()
    onMaxChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const vals = root.values || [];
        if (vals.length < 2 || width <= 0 || height <= 0)
            return;
        const top = Math.max(root.max, 0.0001);
        const stepX = width / Math.max(1, root.capacity - 1);
        const offset = (root.capacity - vals.length) * stepX;
        const yOf = v => height - 1 - Math.max(0, Math.min(1, v / top)) * (height - 2);

        ctx.beginPath();
        ctx.moveTo(offset, yOf(vals[0]));
        for (let i = 1; i < vals.length; i++)
            ctx.lineTo(offset + i * stepX, yOf(vals[i]));
        ctx.lineWidth = 1.5;
        ctx.strokeStyle = root.stroke;
        ctx.stroke();

        ctx.lineTo(offset + (vals.length - 1) * stepX, height);
        ctx.lineTo(offset, height);
        ctx.closePath();
        const grad = ctx.createLinearGradient(0, 0, 0, height);
        grad.addColorStop(0, Qt.rgba(1, 1, 1, 0.18));
        grad.addColorStop(1, Qt.rgba(1, 1, 1, 0.0));
        ctx.fillStyle = grad;
        ctx.fill();
    }
}
