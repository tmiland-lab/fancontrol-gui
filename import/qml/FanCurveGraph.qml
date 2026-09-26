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
import "math.js" as MoreMath
import "colors.js" as Colors

Item {
    id: root

    property QtObject fan
    property bool editable: true
    property int sampleCount: 120
    property int updateInterval: 1000
    property color coolColor: Qt.rgba(0.2, 0.4, 0.9)
    property color warmColor: Qt.rgba(0.9, 0.3, 0.2)
    property color historyColor: Colors.setAlpha(Kirigami.Theme.highlightColor, 0.35)

    readonly property real minTemp: Fancontrol.Base.minTemp
    readonly property real maxTemp: Fancontrol.Base.maxTemp
    readonly property int handleSize: graph.fontSize

    readonly property real currentTemp: !!fan && fan.hasTemp && !!fan.temp ? fan.temp.value : 0
    readonly property real currentPwm: !!fan ? fan.pwm : 0
    readonly property real currentRpm: !!fan ? fan.rpm : 0
    readonly property string currentTempText: currentTemp.toFixed(1) + i18n("°C")
    readonly property string currentPwmText: (currentPwm / 2.55).toFixed(0) + i18n("%")
    readonly property string currentRpmText: currentRpm > 0 ? currentRpm.toFixed(0) + i18n(" rpm") : i18n("stopped")
    readonly property bool showHistory: !!fan && fan.hasTemp

    implicitHeight: Kirigami.Units.gridUnit * 14
    Layout.minimumWidth: Kirigami.Units.gridUnit * 14
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12

    // Operating-points sampled over time: (temp, pwm) pairs that trace the
    // fan's actual behaviour inside the temp/PWM plane of the curve.
    property ListModel samples: ListModel {}

    // Draggable curve control points. First and last entry are the config
    // backed stop (minTemp/minStop) and max (maxTemp/maxPwm) anchors; the
    // in-between entries are free waypoints that bend the drawn curve.
    property ListModel curvePoints: ListModel {}

    function pointTemp(i) { return i >= 0 && i < curvePoints.count ? curvePoints.get(i).temp : 0 }
    function pointPwm(i) { return i >= 0 && i < curvePoints.count ? curvePoints.get(i).pwm : 0 }
    function setPointTemp(i, t) { curvePoints.setProperty(i, "temp", t) }
    function setPointPwm(i, p) { curvePoints.setProperty(i, "pwm", p) }

    function rebuildDefaultPoints() {
        if (!fan)
            return;

        var stopTemp = Math.round(MoreMath.bound(minTemp, fan.minTemp, maxTemp));
        var stopPwm = fan.minPwm === 0 ? 0 : fan.minStop;
        var maxTempV = Math.round(MoreMath.bound(minTemp, fan.maxTemp, maxTemp));
        var maxPwm = fan.maxPwm;

        curvePoints.clear();
        curvePoints.append({ "temp": stopTemp, "pwm": stopPwm, "kind": "stop" });
        // evenly spaced waypoints between the two anchors
        for (var i = 1; i <= root.waypointCount; i++) {
            var f = i / (root.waypointCount + 1);
            curvePoints.append({
                "temp": Math.round(stopTemp + (maxTempV - stopTemp) * f),
                "pwm": Math.round(stopPwm + (maxPwm - stopPwm) * f),
                "kind": "waypoint"
            });
        }
        curvePoints.append({ "temp": maxTempV, "pwm": maxPwm, "kind": "max" });
        curveCanvas.requestPaint();
    }

    function syncAnchorsFromFan() {
        if (!fan || curvePoints.count < 2)
            return;

        // stop anchor
        var stopTemp = Math.round(MoreMath.bound(minTemp, fan.minTemp, maxTemp));
        var stopPwm = fan.minPwm === 0 ? 0 : fan.minStop;
        var maxTempV = Math.round(MoreMath.bound(minTemp, fan.maxTemp, maxTemp));
        var maxPwm = fan.maxPwm;

        // Remember the previous anchor range so interior waypoints can be
        // reprojected proportionally into the new one. Clamping alone would
        // collapse every waypoint onto the same temp when a preset narrows
        // the range (producing a broken, flat then vertical curve).
        var oldMinT = pointTemp(0);
        var oldMaxT = pointTemp(curvePoints.count - 1);
        var oldMinP = pointPwm(0);
        var oldMaxP = pointPwm(curvePoints.count - 1);
        var oldTRange = oldMaxT - oldMinT;
        var oldPRange = oldMaxP - oldMinP;

        if (curvePoints.get(0).kind === "stop") {
            setPointTemp(0, stopTemp);
            setPointPwm(0, stopPwm);
        }
        var last = curvePoints.count - 1;
        if (curvePoints.get(last).kind === "max") {
            setPointTemp(last, maxTempV);
            setPointPwm(last, maxPwm);
        }

        var newTRange = maxTempV - stopTemp;
        var newPRange = maxPwm - stopPwm;

        for (var i = 1; i < last; i++) {
            // Normalised position of the waypoint within the old range.
            var fT = oldTRange !== 0 ? (pointTemp(i) - oldMinT) / oldTRange : i / (last);
            var fP = oldPRange !== 0 ? (pointPwm(i) - oldMinP) / oldPRange : i / (last);
            fT = MoreMath.bound(0, fT, 1);
            fP = MoreMath.bound(0, fP, 1);

            setPointTemp(i, Math.round(stopTemp + newTRange * fT));
            setPointPwm(i, Math.round(stopPwm + newPRange * fP));
        }
    }

    // Unified drag contract used by FanCurveHandle: writes the model back and
    // mirrors the changed anchor (stop/max) or waypoint into the fan. The
    // handle hands us fully scaled temp/pwm values, so no canvas math here.
    function applyPoint(index, temp, pwm) {
        if (!fan || index < 0 || index >= curvePoints.count)
            return;

        var kind = curvePoints.get(index).kind;
        var t = Math.round(MoreMath.bound(minTemp, temp, maxTemp));
        var p = Math.round(MoreMath.bound(0, pwm, 255));

        if (kind === "stop") {
            // The stop anchor defines both the "turn off" floor and the
            // minimum spinning value. Keep minStop <= minStart so the
            // generated fancontrol config stays valid, and mirror minStop
            // into minPwm unless the fan is configured to stop completely.
            fan.minTemp = t;
            fan.minStop = Math.min(p, fan.minStart > 0 ? fan.minStart : p);
            if (fan.minPwm !== 0)
                fan.minPwm = fan.minStop;
        } else if (kind === "max") {
            // maxPwm must stay above the stop floor, otherwise the curve
            // collapses and the fan never reaches full speed.
            fan.maxTemp = t;
            fan.maxPwm = Math.max(p, fan.minStop);
        } else if (kind === "waypoint") {
            setPointTemp(index, t);
            setPointPwm(index, p);
        }
        syncAnchorsFromFan();
        curveCanvas.requestPaint();
    }

    function finishPoint(index) {
        if (!fan)
            return;
        syncAnchorsFromFan();
        curveCanvas.requestPaint();
    }

    property int waypointCount: 2

    onWaypointCountChanged: rebuildDefaultPoints()
    onFanChanged: {        if (fan) {
            rebuildDefaultPoints();
            samples.clear();
        }
        if (!!curveCanvas) curveCanvas.requestPaint()
        if (!!trailCanvas) trailCanvas.requestPaint()
        if (!!meshCanvas) meshCanvas.requestPaint()
    }
    onMinTempChanged: syncAnchorsFromFan()
    onMaxTempChanged: syncAnchorsFromFan()
    onWidthChanged: {
        if (!!curveCanvas) curveCanvas.requestPaint()
        if (!!trailCanvas) trailCanvas.requestPaint()
        if (!!meshCanvas) meshCanvas.requestPaint()
    }
    onHeightChanged: {
        if (!!curveCanvas) curveCanvas.requestPaint()
        if (!!trailCanvas) trailCanvas.requestPaint()
        if (!!meshCanvas) meshCanvas.requestPaint()
    }

    // Canvas contents are cached bitmaps. The curves, mesh and trail are
    // painted with the current theme colours, so they must be repainted when
    // the system switches between light and dark, otherwise the plot keeps
    // its old (dark) fill on a light background.
    Connections {
        target: Kirigami.Theme
        function onColorsChanged() {
            if (!!curveCanvas) curveCanvas.requestPaint()
            if (!!trailCanvas) trailCanvas.requestPaint()
            if (!!meshCanvas) meshCanvas.requestPaint()
        }
    }

    Connections {
        target: fan && fan.hasTemp ? fan : null
        function onMinPwmChanged() { syncAnchorsFromFan() }
        function onMinStopChanged() { syncAnchorsFromFan() }
        function onMinTempChanged() { syncAnchorsFromFan() }
        function onMaxPwmChanged() { syncAnchorsFromFan() }
        function onMaxTempChanged() { syncAnchorsFromFan() }
    }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: root.showHistory

        onTriggered: {
            while (samples.count >= root.sampleCount)
                samples.remove(0);

            samples.append({
                "temp": root.currentTemp,
                "pwm": root.currentPwm
            });
            trailCanvas.requestPaint();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Item {
            id: graph

            property int fontSize: MoreMath.bound(8, height / 20 + 1, 16)
            property int verticalScalaCount: height > Kirigami.Units.gridUnit * 30 ? 11 : 6
            property var horIntervals: MoreMath.intervals(root.minTemp, root.maxTemp, 10)

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 8

            Item {
                id: verticalScala

                anchors {
                    top: graphBackground.top
                    bottom: graphBackground.bottom
                    left: parent.left
                }
                width: MoreMath.maxWidth(children) + graph.fontSize / 3

                Repeater {
                    id: verticalRepeater

                    model: graph.verticalScalaCount

                    Text {
                        x: verticalScala.width - implicitWidth - graph.fontSize / 3
                        y: graphBackground.height - graphBackground.height / (graph.verticalScalaCount - 1) * index - graph.fontSize * 2 / 3
                        horizontalAlignment: Text.AlignRight
                        color: Kirigami.Theme.textColor
                        text: Number(index * (100 / (graph.verticalScalaCount - 1))).toLocaleString(Qt.locale(), 'f', 0) + Qt.locale().percent
                        font.pixelSize: graph.fontSize
                    }
                }
            }

            Item {
                id: horizontalScala

                anchors {
                    right: graphBackground.right
                    bottom: parent.bottom
                    left: graphBackground.left
                }
                height: graph.fontSize * 2

                Repeater {
                    model: graph.horIntervals.length;

                    Text {
                        x: graphBackground.scaleX(graph.horIntervals[index]) - width/2
                        y: horizontalScala.height / 2 - implicitHeight / 2
                        color: Kirigami.Theme.textColor
                        text: Number(graph.horIntervals[index]).toLocaleString() + i18n("°C")
                        font.pixelSize: graph.fontSize
                    }
                }
            }

            Rectangle {
                id: graphBackground

                Kirigami.Theme.colorSet: Kirigami.Theme.View
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.textColor
                border.width: 2

                anchors {
                    top: parent.top
                    left: verticalScala.right
                    bottom: horizontalScala.top
                    right: parent.right
                    topMargin: parent.fontSize
                    rightMargin: parent.fontSize * 2
                }

                function scaleX(temp) {
                    return (temp - minTemp) * width / (maxTemp - minTemp);
                }
                function scaleY(pwm) {
                    return height - pwm * height / 255;
                }
                function scaleTemp(x) {
                    return x / width * (maxTemp - minTemp) + minTemp;
                }
                function scalePwm(y) {
                    return 255 - y / height * 255;
                }

                Canvas {
                    id: trailCanvas

                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    renderStrategy: Canvas.Threaded

                    onPaint: {
                        var c = trailCanvas.getContext("2d");
                        c.clearRect(0, 0, width, height);

                        if (samples.count < 2)
                            return;

                        var pad = 4;
                        var w = width - pad * 2;
                        var h = height - pad * 2;
                        var minV = root.minTemp;
                        var maxV = root.maxTemp;
                        var range = maxV - minV;
                        if (range <= 0)
                            range = 1;

                        function scaleX(temp) {
                            return pad + (temp - minV) / range * w;
                        }
                        function scaleY(pwm) {
                            return pad + (1 - pwm / 255) * h;
                        }

                        // fading operating-point trail: old samples are faint,
                        // the most recent sample is drawn at full opacity
                        c.lineWidth = 1.5;
                        c.lineJoin = "round";
                        for (var i = 1; i < samples.count; i++) {
                            var prev = samples.get(i - 1);
                            var s = samples.get(i);
                            var alpha = 0.08 + 0.92 * (i / (samples.count - 1));
                            c.strokeStyle = Colors.setAlpha(root.historyColor, alpha);
                            c.fillStyle = c.strokeStyle;
                            c.beginPath();
                            c.moveTo(scaleX(prev.temp), scaleY(prev.pwm));
                            c.lineTo(scaleX(s.temp), scaleY(s.pwm));
                            c.stroke();
                            c.beginPath();
                            c.arc(scaleX(s.temp), scaleY(s.pwm), 1.5, 0, Math.PI * 2);
                            c.fill();
                        }
                    }
                }

                Canvas {
                    id: meshCanvas

                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    renderStrategy: Canvas.Threaded

                    onPaint: {
                        var c = meshCanvas.getContext("2d");
                        c.clearRect(0, 0, width, height);

                        c.beginPath();
                        c.strokeStyle = Colors.setAlpha(Kirigami.Theme.textColor, 0.3);

                        for (var i=0; i<=100; i+=100/(graph.verticalScalaCount-1)) {
                            var y = graphBackground.scaleY(i*2.55);
                            if (i != 0 && i != 100) {
                                for (var j=0; j<=width; j+=15) {
                                    c.moveTo(j, y);
                                    c.lineTo(Math.min(j+5, width), y);
                                }
                            }
                        }

                        if (graph.horIntervals.length > 1) {
                            for (var i=1; i<graph.horIntervals.length; i++) {
                                var x = graphBackground.scaleX(graph.horIntervals[i]);
                                for (var j=0; j<=height; j+=20) {
                                    c.moveTo(x, j);
                                    c.lineTo(x, Math.min(j+5, height));
                                }
                            }
                        }
                        c.stroke();
                    }
                }

                Canvas {
                    id: curveCanvas

                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    renderStrategy: Canvas.Threaded

                    onPaint: {
                        var c = curveCanvas.getContext("2d");
                        c.clearRect(0, 0, width, height);

                        if (curvePoints.count < 2)
                            return;

                        var gradStart = root.coolColor;
                        var gradEnd = root.warmColor;

                        var gradient = c.createLinearGradient(0, 0, width, 0);
                        gradient.addColorStop(0, gradStart);
                        gradient.addColorStop(1, gradEnd);
                        c.fillStyle = gradient;
                        c.lineWidth = graph.fontSize / 3;
                        c.strokeStyle = gradient;
                        c.lineJoin = "round";
                        c.beginPath();

                        var first = curvePoints.get(0);
                        var last = curvePoints.get(curvePoints.count - 1);
                        var fx = graphBackground.scaleX(first.temp);
                        var fy = graphBackground.scaleY(first.pwm);
                        var lx = graphBackground.scaleX(last.temp);
                        var ly = graphBackground.scaleY(last.pwm);

                        if (first.pwm === 0) {
                            c.moveTo(fx, height);
                        } else {
                            c.moveTo(0, fy);
                            c.lineTo(fx, fy);
                        }
                        for (var i = 0; i < curvePoints.count; i++) {
                            var p = curvePoints.get(i);
                            c.lineTo(graphBackground.scaleX(p.temp), graphBackground.scaleY(p.pwm));
                        }
                        c.lineTo(width, ly);
                        c.stroke();

                        c.lineTo(width, height);
                        if (first.pwm === 0) {
                            c.lineTo(fx, height);
                        } else {
                            c.lineTo(0, height);
                        }
                        c.fill();

                        // blend graphBackground so the gradient reads as a band
                        gradient = c.createLinearGradient(0, 0, 0, height);
                        gradient.addColorStop(0, Colors.setAlpha(graphBackground.color, 0.5));
                        gradient.addColorStop(1, Colors.setAlpha(graphBackground.color, 0.9));
                        c.fillStyle = gradient;
                        c.fill();
                    }

                    Connections {
                        target: fan
                        function onTempChanged() { curveCanvas.requestPaint() }
                        function onMinPwmChanged() { curveCanvas.requestPaint() }
                    }
                }

                Repeater {
                    id: curveHandleRepeater
                    model: root.curvePoints

                    delegate: FanCurveHandle {
                        background: graphBackground
                        pointIndex: model.kind === "stop" ? 0
                                   : model.kind === "max" ? root.curvePoints.count - 1
                                   : index
                        kind: model.kind
                        graph: root
                        editable: root.editable
                        size: root.handleSize
                    }
                }

                StatusPoint {
                    id: currentStatus

                    size: graph.fontSize
                    visible: showHistory && graphBackground.contains(center)
                    fan: root.fan

                    // The combined graph draws history *and* curve, so make
                    // the live operating point clearly stand out on top.
                    z: 999
                }
            }
        }

        ColumnLayout {
            id: infoColumn

            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 8
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            // Without a maximum the column greedily claims half the row (its
            // children fillWidth), starving the plot of space.
            Layout.maximumWidth: Kirigami.Units.gridUnit * 11
            spacing: Kirigami.Units.smallSpacing

            // Live readout card. The fan name lives in the page header, so it
            // is not duplicated here.
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: stats.implicitHeight + Kirigami.Units.largeSpacing
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.alternateBackgroundColor
                border.width: 1
                border.color: Colors.setAlpha(Kirigami.Theme.textColor, 0.12)

                ColumnLayout {
                    id: stats

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Kirigami.Units.smallSpacing
                    }
                    spacing: Kirigami.Units.smallSpacing

                    Label {
                        text: i18n("Live")
                        font.bold: true
                        color: Kirigami.Theme.disabledTextColor
                        Layout.fillWidth: true
                    }

                    StatRow {
                        label: i18n("Temp")
                        value: root.currentTempText
                        valueColor: root.coolColor
                    }
                    StatRow {
                        label: i18n("PWM")
                        value: root.currentPwmText
                        valueColor: root.warmColor
                    }
                    StatRow {
                        label: i18n("Speed")
                        value: root.currentRpmText
                        valueColor: Kirigami.Theme.textColor
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Waypoint stepper.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: stepper.implicitHeight + Kirigami.Units.smallSpacing
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.alternateBackgroundColor
                border.width: 1
                border.color: Colors.setAlpha(Kirigami.Theme.textColor, 0.12)

                RowLayout {
                    id: stepper

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Kirigami.Units.smallSpacing
                    }
                    spacing: 0

                    ToolButton {
                        text: i18n("−")
                        enabled: root.editable && root.waypointCount > 0
                        onClicked: if (root.waypointCount > 0) --root.waypointCount
                    }
                    Label {
                        text: i18np("%1 point", "%1 points", root.waypointCount + 2)
                        color: Kirigami.Theme.disabledTextColor
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    ToolButton {
                        text: i18n("+")
                        enabled: root.editable && root.waypointCount < 6
                        onClicked: if (root.waypointCount < 6) ++root.waypointCount
                    }
                }
            }
        }
    }

    // One label/value pair of the live readout.
    component StatRow: RowLayout {
        property string label
        property string value
        property color valueColor: Kirigami.Theme.textColor

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.preferredWidth: Kirigami.Units.smallSpacing
            Layout.preferredHeight: Kirigami.Units.smallSpacing
            radius: width / 2
            color: valueColor
        }
        Label {
            text: label
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Label {
            text: value
            color: valueColor
            font.bold: true
        }
    }
}