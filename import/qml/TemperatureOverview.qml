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
import Fancontrol.Qml 1.0 as Fancontrol
import "colors.js" as Colors
import "math.js" as MoreMath

Item {
    id: root

    readonly property QtObject tempModel: Fancontrol.Base.tempModel
    property int updateInterval: 1000
    property int rangeMinutes: 5
    property real axisMin: 0
    property real axisMax: 100
    property bool showThreshold: true
    property color thresholdColor: Qt.rgba(0.9, 0.15, 0.15, 0.85)
    property color gridColor: Colors.setAlpha(Kirigami.Theme.textColor, 0.15)

    implicitHeight: Kirigami.Units.gridUnit * 14

    readonly property int maxSamples: root.rangeMinutes * 60
    readonly property real currentMax: {
        var max = root.axisMin;
        for (var i = 0; i < seriesKeys.length; i++) {
            var v = series[seriesKeys[i]];
            if (v.length > 0 && v[v.length - 1] > max)
                max = v[v.length - 1];
        }
        return max;
    }

    property var series: ({})
    property var seriesKeys: []
    property var seriesColors: []
    property real lastSampleTime: 0

    property ListModel rowsModel: ListModel {}

    function rebuildSeries() {
        var keys = [];
        var colors = [];
        var newSeries = {};
        for (var i = 0; i < root.tempModel.length; i++) {
            var t = root.tempModel.temp(i);
            keys.push(t.label);
            colors.push(Colors.palette(i));
            if (root.series[t.label])
                newSeries[t.label] = root.series[t.label];
            else
                newSeries[t.label] = [];
        }
        // prune removed sensors
        for (var old in root.series) {
            if (keys.indexOf(old) < 0)
                newSeries[old] = undefined;
        }
        root.series = newSeries;
        root.seriesKeys = keys;
        root.seriesColors = colors;

        rowsModel.clear();
        for (var j = 0; j < keys.length; j++) {
            rowsModel.append({ "label": keys[j], "colorIndex": j, "isMax": false });
        }
        updateMaxMarker();
    }

    function updateMaxMarker() {
        for (var r = 0; r < rowsModel.count; r++) {
            rowsModel.setProperty(r, "isMax", rowsModel.get(r).label === root.currentMaxKey);
        }
    }

    readonly property string currentMaxKey: {
        var best = root.seriesKeys.length > 0 ? root.seriesKeys[0] : "";
        var bestVal = -273;
        for (var i = 0; i < root.seriesKeys.length; i++) {
            var v = root.series[root.seriesKeys[i]];
            if (v.length > 0 && v[v.length - 1] > bestVal) {
                bestVal = v[v.length - 1];
                best = root.seriesKeys[i];
            }
        }
        return best;
    }

    onTempModelChanged: rebuildSeries()
    Component.onCompleted: rebuildSeries()
    Connections {
        target: root.tempModel
        function onTempsChanged() { rebuildSeries() }
    }

    // Canvas contents are cached; repaint when the colour scheme changes so
    // the chart grid/labels do not keep the previous (e.g. dark) theme colours.
    Connections {
        target: Kirigami.Theme
        function onColorsChanged() { overviewCanvas.requestPaint() }
    }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: root.tempModel.length > 0

        onTriggered: {
            root.lastSampleTime = Date.now();
            var keys = root.seriesKeys;
            for (var i = 0; i < keys.length; i++) {
                var t = root.tempModel.temp(i);
                if (!t)
                    continue;
                var arr = root.series[keys[i]];
                if (!arr)
                    arr = [];
                while (arr.length >= root.maxSamples)
                    arr.shift();
                arr.push(t.value);
                root.series[keys[i]] = arr;
            }
            updateMaxMarker();
            overviewCanvas.requestPaint();
        }
    }

    Rectangle {
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
                    text: i18n("Temperature overview")
                    font.bold: true
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                }

                Label {
                    text: currentMax.toFixed(1) + i18n("°C")
                    font.bold: true
                    color: root.currentMax >= Fancontrol.Base.alertThreshold ? root.thresholdColor : Kirigami.Theme.textColor
                    Layout.alignment: Qt.AlignRight
                }

                RowLayout {
                    id: rangeButtons

                    spacing: Kirigami.Units.smallSpacing
                    Layout.alignment: Qt.AlignRight

                    Button {
                        text: i18n("1m")
                        checked: root.rangeMinutes === 1
                        checkable: true
                        flat: true
                        onClicked: root.rangeMinutes = 1
                    }
                    Button {
                        text: i18n("5m")
                        checked: root.rangeMinutes === 5
                        checkable: true
                        flat: true
                        onClicked: root.rangeMinutes = 5
                    }
                    Button {
                        text: i18n("15m")
                        checked: root.rangeMinutes === 15
                        checkable: true
                        flat: true
                        onClicked: root.rangeMinutes = 15
                    }
                }
            }

            Canvas {
                id: overviewCanvas

                Layout.fillWidth: true
                Layout.fillHeight: true
                renderStrategy: Canvas.Threaded

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: {
                        var factor = wheel.angleDelta.y > 0 ? 0.8 : 1.25;
                        var range = root.axisMax - root.axisMin;
                        var cursor = root.axisMin + (wheel.x / width) * range;
                        var newRange = range * factor;
                        var lower = cursor - (cursor - root.axisMin) * factor;
                        root.axisMin = Math.max(-273, lower);
                        root.axisMax = root.axisMin + newRange;
                        overviewCanvas.requestPaint();
                    }
                }

                onPaint: {
                    var c = overviewCanvas.getContext("2d");
                    c.clearRect(0, 0, width, height);

                    if (width < 2 || height < 2)
                        return;

                    var pad = 6;
                    var w = width - pad * 2;
                    var h = height - pad * 2;
                    var minV = root.axisMin;
                    var maxV = root.axisMax;
                    var range = maxV - minV;
                    if (range <= 0)
                        range = 1;

                    function scaleY(v) {
                        return pad + (1 - (v - minV) / range) * h;
                    }

                    // horizontal grid
                    c.strokeStyle = root.gridColor;
                    c.lineWidth = 1;
                    c.beginPath();
                    for (var i = 1; i < 5; i++) {
                        var y = pad + h / 4 * i;
                        c.moveTo(pad, y);
                        c.lineTo(w + pad, y);
                    }
                    c.stroke();

                    // threshold line
                    if (root.showThreshold && Fancontrol.Base.alertThreshold > minV && Fancontrol.Base.alertThreshold < maxV) {
                        c.strokeStyle = root.thresholdColor;
                        c.setLineDash([4, 3]);
                        c.beginPath();
                        var ty = scaleY(Fancontrol.Base.alertThreshold);
                        c.moveTo(pad, ty);
                        c.lineTo(w + pad, ty);
                        c.stroke();
                        c.setLineDash([]);

                        c.fillStyle = root.thresholdColor;
                        c.font = "9px sans-serif";
                        c.textAlign = "right";
                        c.fillText(Fancontrol.Base.alertThreshold.toFixed(0) + i18n("°C"), w + pad, ty - 3);
                    }

                    // series
                    var keys = root.seriesKeys;
                    var maxLen = 0;
                    for (var k = 0; k < keys.length; k++) {
                        if (root.series[keys[k]])
                            maxLen = Math.max(maxLen, root.series[keys[k]].length);
                    }
                    if (maxLen < 2)
                        return;

                    function scaleX(i) {
                        return pad + (maxLen <= 1 ? 0 : i / (maxLen - 1)) * w;
                    }

                    for (var s = 0; s < keys.length; s++) {
                        var vals = root.series[keys[s]];
                        if (!vals || vals.length < 2)
                            continue;
                        var color = root.seriesColors[s];
                        c.strokeStyle = color;
                        c.fillStyle = Colors.setAlpha(color, 0.12);
                        c.lineWidth = 1.5;
                        c.lineJoin = "round";

                        c.beginPath();
                        c.moveTo(scaleX(0), pad + h);
                        for (var p = 0; p < vals.length; p++) {
                            c.lineTo(scaleX(p), scaleY(vals[p]));
                        }
                        c.lineTo(scaleX(vals.length - 1), pad + h);
                        c.closePath();
                        c.fill();

                        c.beginPath();
                        for (var q = 0; q < vals.length; q++) {
                            var px = scaleX(q);
                            var py = scaleY(vals[q]);
                            if (q === 0)
                                c.moveTo(px, py);
                            else
                                c.lineTo(px, py);
                        }
                        c.stroke();

                        // current point
                        c.beginPath();
                        c.arc(scaleX(vals.length - 1), scaleY(vals[vals.length - 1]), 3, 0, Math.PI * 2);
                        c.fillStyle = color;
                        c.fill();
                    }
                }
            }

            // Legend
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: rowsModel.count > 0

                Repeater {
                    model: rowsModel

                    RowLayout {
                        spacing: 2
                        Layout.preferredWidth: implicitWidth

                        readonly property string currentValueText: {
                            var arr = root.series[label];
                            return arr && arr.length > 0 ? arr[arr.length - 1].toFixed(1) + i18n("°C") : "-";
                        }

                        Rectangle {
                            width: 10
                            height: 10
                            radius: 2
                            color: Colors.palette(colorIndex)
                        }
                        Label {
                            text: label + "  " + currentValueText
                            color: isMax ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                            font.bold: isMax
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}