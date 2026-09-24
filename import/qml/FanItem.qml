/*
 * Copyright (C) 2015  Malte Veerman <malte.veerman@gmail.com>
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
    property int margin: Kirigami.Units.smallSpacing
    property bool showControls: true
    property bool editable: true
    readonly property QtObject systemdCom: Fancontrol.Base.hasSystemdCommunicator ? Fancontrol.Base.systemdCom : null
    readonly property QtObject tempModel: Fancontrol.Base.tempModel
    readonly property real minTemp: Fancontrol.Base.minTemp
    readonly property real maxTemp: Fancontrol.Base.maxTemp
    readonly property color coolColor: Qt.rgba(0.2, 0.4, 0.9)
    readonly property color warmColor: Qt.rgba(0.9, 0.3, 0.2)

    ColumnLayout {
        anchors.fill: parent
        spacing: root.margin

        TabBar {
            id: tabBar

            Layout.fillWidth: true

            TabButton {
                text: i18n("Fan curve")
                width: Math.max(implicitWidth, tabBar.width / tabBar.count)
            }
            TabButton {
                text: i18n("Temperature & PWM")
                width: Math.max(implicitWidth, tabBar.width / tabBar.count)
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // Tab 1: the editable fan curve, using the full width.
            FanCurveGraph {
                id: graph
                fan: root.fan
                editable: root.editable
                coolColor: root.coolColor
                warmColor: root.warmColor
            }

            // Tab 2: live temperature timeline above the PWM history.
            ColumnLayout {
                spacing: root.margin

                Fancontrol.TemperatureTimeline {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    temp: !!root.fan && root.fan.hasTemp ? root.fan.temp : null
                    visible: !!root.fan && root.fan.hasTemp
                    lineColor: root.coolColor
                }

                Fancontrol.PwmHistory {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 7
                    fan: root.fan
                    visible: !!root.fan && root.fan.hasTemp
                    lineColor: root.warmColor
                }
            }
        }

        // Presets row
        Fancontrol.FanCurvePreset {
            Layout.fillWidth: true
            fan: root.fan
            visible: root.showControls
        }

        FanControls {
            id: settingsArea

            fan: root.fan
            padding: root.margin
            Layout.fillWidth: true
            visible: root.showControls
        }
    }
}
