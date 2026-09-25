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


Kirigami.ScrollablePage {
    id: root

    readonly property QtObject loader: Fancontrol.Base.loader

    spacing: Kirigami.Units.smallSpacing
    horizontalScrollBarPolicy: Qt.ScrollBarAlwaysOff

    ListView {
        id: listView

        width: root.width
        clip: true
        topMargin: Kirigami.Units.smallSpacing
        bottomMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing
        boundsBehavior: Flickable.StopAtBounds

        model: loader.hwmons.length

        // The temperature overview and the alarm banner ride along as the list
        // header, so a single flickable scrolls the whole page.
        header: Item {
            width: listView.width
            height: headerColumn.implicitHeight

            ColumnLayout {
                id: headerColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.InlineMessage {
                    id: alarmBanner

                    readonly property bool alarm: Fancontrol.Base.temperatureAlarm

                    Layout.fillWidth: true
                    visible: alarm
                    type: Kirigami.MessageType.Error
                    text: alarm ? i18n("Temperature alarm: %1 reached %2°C, above the %3°C threshold",
                                        Fancontrol.Base.alarmSensor,
                                        Fancontrol.Base.highestTemp.toFixed(1),
                                        Fancontrol.Base.alertThreshold.toFixed(1)) : ""
                    actions: [
                        Kirigami.Action {
                            icon.name: "dialog-ok"
                            text: i18n("Dismiss")
                            onTriggered: Fancontrol.Base.checkTemperatures()
                        },
                        Kirigami.Action {
                            icon.name: "configure"
                            text: i18n("Settings…")
                            onTriggered: window.leftPage = "SettingsTab.qml"
                        }
                    ]
                }

                Fancontrol.TemperatureOverview {
                    id: overview

                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 20
                    updateInterval: Fancontrol.Base.loader.interval * 1000
                    rangeMinutes: 5
                }
            }
        }

        delegate: Rectangle {
            id: card

            readonly property QtObject hwmon: loader.hwmons[index]

            width: listView.width - Kirigami.Units.largeSpacing * 2
            x: Kirigami.Units.largeSpacing
            implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.alternateBackgroundColor
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                  Kirigami.Theme.textColor.g,
                                  Kirigami.Theme.textColor.b, 0.12)

            ColumnLayout {
                id: content

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Kirigami.Units.largeSpacing
                }
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    level: 3
                    text: hwmon.name
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Repeater {
                    model: hwmon.fans.length

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "fan"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                        }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: i18n("Fan %1", index + 1)
                            color: Kirigami.Theme.disabledTextColor
                        }
                        Label {
                            text: i18n("%1 rpm", hwmon.fans[index].rpm)
                            font.bold: true
                        }
                    }
                }

                Repeater {
                    model: hwmon.temps.length

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "thermometer"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                        }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: hwmon.temps[index].name
                            color: Kirigami.Theme.disabledTextColor
                        }
                        Label {
                            text: hwmon.temps[index].value + i18n("°C")
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
