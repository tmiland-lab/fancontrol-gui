/*
 * Copyright (C) 2026 Tommy Miland <tommy@tmiland.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import org.kde.kirigami 2.14 as Kirigami
import "math.js" as MoreMath

Item {
    id: root

    property QtObject temp
    property int sampleCount: 120
    property int minTemp: 0
    property int maxTemp: 100
    property color lineColor: Kirigami.Theme.positiveTextColor
    property color fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.15)
    property int updateInterval: 1000
    property bool running: true

    signal clicked()

    implicitHeight: Kirigami.Units.gridUnit * 12

    readonly property real currentValue: !!temp ? temp.value : 0

    ListModel {
        id: samples
    }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: root.running && !!root.temp

        onTriggered: {
            while (samples.count >= root.sampleCount)
                samples.remove(0);

            samples.append({
                "value": root.temp.value,
                "timestamp": Date.now()
            });
            historyCanvas.requestPaint();
        }
    }

    // Canvas contents are cached; repaint when the colour scheme changes so
    // the timeline does not keep the previous (e.g. dark) theme colours.
    Connections {
        target: Kirigami.Theme
        function onColorsChanged() { historyCanvas.requestPaint() }
    }

    Rectangle {
        id: background

        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
        border.color: Kirigami.Theme.textColor
        border.width: 1
        radius: Kirigami.Units.smallSpacing

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true

                Label {
                    id: titleLabel

                    text: !!root.temp ? root.temp.name : i18n("Temperature")
                    font.bold: true
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                }

                Label {
                    text: currentValue.toFixed(1) + i18n("°C")
                    font.bold: true
                    color: root.lineColor
                    Layout.alignment: Qt.AlignRight
                }
            }

            Canvas {
                id: historyCanvas

                Layout.fillWidth: true
                Layout.fillHeight: true

                renderStrategy: Canvas.Threaded

                onPaint: {
                    var c = historyCanvas.getContext("2d");
                    c.clearRect(0, 0, width, height);

                    if (samples.count < 2) {
                        return;
                    }

                    var pad = 4;
                    var w = width - pad * 2;
                    var h = height - pad * 2;
                    var minV = root.minTemp;
                    var maxV = root.maxTemp;
                    var range = maxV - minV;
                    if (range <= 0)
                        range = 1;

                    function scaleX(i) {
                        return pad + (samples.count <= 1 ? 0 : i / (samples.count - 1)) * w;
                    }
                    function scaleY(v) {
                        return pad + (1 - (v - minV) / range) * h;
                    }

                    //grid
                    c.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15);
                    c.lineWidth = 1;
                    c.beginPath();
                    for (var i = 1; i < 5; i++) {
                        var y = pad + h / 4 * i;
                        c.moveTo(pad, y);
                        c.lineTo(w + pad, y);
                    }
                    c.stroke();

                    //area fill
                    var first = samples.get(0);
                    var last = samples.get(samples.count - 1);
                    var maxVal = Math.max(first.value, last.value);
                    for (var j = 0; j < samples.count; j++) {
                        var v = samples.get(j).value;
                        if (v > maxVal)
                            maxVal = v;
                    }

                    c.beginPath();
                    c.moveTo(scaleX(0), pad + h);
                    for (var k = 0; k < samples.count; k++) {
                        c.lineTo(scaleX(k), scaleY(samples.get(k).value));
                    }
                    c.lineTo(scaleX(samples.count - 1), pad + h);
                    c.closePath();
                    c.fillStyle = root.fillColor;
                    c.fill();

                    //line
                    c.beginPath();
                    for (var l = 0; l < samples.count; l++) {
                        var px = scaleX(l);
                        var py = scaleY(samples.get(l).value);
                        if (l === 0)
                            c.moveTo(px, py);
                        else
                            c.lineTo(px, py);
                    }
                    c.strokeStyle = root.lineColor;
                    c.lineWidth = 2;
                    c.lineJoin = "round";
                    c.stroke();

                    //current point
                    var cxp = scaleX(samples.count - 1);
                    var cyp = scaleY(last.value);
                    c.beginPath();
                    c.arc(cxp, cyp, 4, 0, Math.PI * 2);
                    c.fillStyle = root.lineColor;
                    c.fill();
                }
            }
        }
    }

    //Leeg-preserve current value
    Component.onDestruction: {
        samples.clear();
    }
}