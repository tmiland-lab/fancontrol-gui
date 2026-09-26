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

Item {
    id: root

    property QtObject fan
    property int sampleCount: 120
    property int updateInterval: 1000
    property bool running: true
    property color lineColor: Kirigami.Theme.neutralTextColor
    property color fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.15)

    implicitHeight: Kirigami.Units.gridUnit * 8

    readonly property int currentPwm: !!fan ? fan.pwm : 0
    readonly property int currentRpm: !!fan ? fan.rpm : 0
    readonly property string currentPwmText: (currentPwm / 2.55).toFixed(0) + i18n("%")

    ListModel {
        id: samples
    }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: root.running && !!root.fan

        onTriggered: {
            while (samples.count >= root.sampleCount)
                samples.remove(0);

            samples.append({
                "pwm": root.fan.pwm,
                "rpm": root.fan.rpm
            });
            historyCanvas.requestPaint();
        }
    }

    // Canvas contents are cached; repaint when the colour scheme changes so
    // the grid graph does not keep the previous (e.g. dark) theme colours.
    Connections {
        target: Kirigami.Theme
        function onColorsChanged() { historyCanvas.requestPaint() }
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
                    id: titleLabel

                    text: i18n("PWM history")
                    font.bold: true
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                }

                Label {
                    text: currentPwmText
                    font.bold: true
                    color: root.lineColor
                    Layout.alignment: Qt.AlignRight
                }

                Label {
                    text: currentRpm > 0 ? currentRpm + i18n(" rpm") : i18n("stopped")
                    color: Kirigami.Theme.disabledTextColor
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

                    function scaleX(i) {
                        return pad + (samples.count <= 1 ? 0 : i / (samples.count - 1)) * w;
                    }
                    function scaleY(pwm) {
                        return pad + (1 - pwm / 255) * h;
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
                    c.beginPath();
                    for (var j = 1; j < 5; j++) {
                        var x = pad + w / 4 * j;
                        c.moveTo(x, pad);
                        c.lineTo(x, h + pad);
                    }
                    c.stroke();

                    //area fill
                    var last = samples.get(samples.count - 1);
                    c.beginPath();
                    c.moveTo(scaleX(0), pad + h);
                    for (var k = 0; k < samples.count; k++) {
                        c.lineTo(scaleX(k), scaleY(samples.get(k).pwm));
                    }
                    c.lineTo(scaleX(samples.count - 1), pad + h);
                    c.closePath();
                    c.fillStyle = root.fillColor;
                    c.fill();

                    //line
                    c.beginPath();
                    for (var l = 0; l < samples.count; l++) {
                        var px = scaleX(l);
                        var py = scaleY(samples.get(l).pwm);
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
                    c.beginPath();
                    c.arc(scaleX(samples.count - 1), scaleY(last.pwm), 4, 0, Math.PI * 2);
                    c.fillStyle = root.lineColor;
                    c.fill();
                }
            }
        }
    }

    Component.onDestruction: {
        samples.clear();
    }
}