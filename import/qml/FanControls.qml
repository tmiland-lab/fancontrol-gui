/*
 * Copyright (C) 2019  Malte Veerman <malte.veerman@gmail.com>
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
import Fancontrol.Qml 1.0 as Fancontrol


ColumnLayout {
    id: root

    property int padding
    property QtObject fan
    readonly property QtObject tempModel: Fancontrol.Base.tempModel

    spacing: 2

    RowLayout {
        CheckBox {
            id: hasTempCheckBox
            text: i18n("Controlled by:")
            checked: !!fan ? fan.hasTemp : false
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            onCheckedChanged: {
                if (!!fan) {
                    fan.hasTemp = checked;
                    if (checked && !!tempModel.temp(tempBox.currentIndex)) {
                        fan.temp = tempModel.temp(tempBox.currentIndex);
                    }
                }
            }

            Connections {
                target: root
                function onFanChanged() { hasTempCheckBox.checked = !!fan ? fan.hasTemp : false }
            }
            Connections {
                target: fan
                function onHasTempChanged() { hasTempCheckBox.checked = fan.hasTemp }
            }
        }
        RowLayout {
            ComboBox {
                id: tempBox
                Layout.fillWidth: true
                model: tempModel
                currentIndex: !!fan && fan.hasTemp ? tempModel.indexOf(fan.temp) : -1
                textRole: "display"
                enabled: hasTempCheckBox.checked
                onCurrentIndexChanged: {
                    if (hasTempCheckBox.checked)
                        fan.temp = tempModel.temp(currentIndex);
                }
            }

            Connections {
                target: root
                function onFanChanged() { tempBox.currentIndex = !!fan && fan.hasTemp ? tempModel.indexOf(fan.temp) : -1 }
            }
            Connections {
                target: fan
                function onTempChanged() { tempBox.currentIndex = !!fan && fan.hasTemp ? tempModel.indexOf(fan.temp) : -1 }
            }
        }
    }

    RowLayout {
        Label {
            text: i18n("Number of cycles to average temperature")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            renderType: Text.NativeRendering
        }
        SpinBox {
            id: averageInput

            Layout.fillWidth: true
            from: 1
            to: 100
            editable: true
            value: !!fan ? fan.average : 1
            textFromValue: function(value, locale) { return Number(value).toLocaleString(locale, 'f', 1) }
            onValueModified: {
                if (!!fan) {
                    fan.average = value
                }
            }

            Connections {
                target: root
                function onFanChanged() { if (!!fan) averageInput.value = fan.average }
            }
            Connections {
                target: fan
                function onAverageChanged() { averageInput.value = fan.average }
            }
        }
    }

    CheckBox {
        id: fanOffCheckBox

        text: i18n("Turn Fan off if temp < MINTEMP")
        enabled: hasTempCheckBox.checked
        checked: !!fan ? fan.minPwm === 0 : false
        onCheckedChanged: {
            if (!!fan) {
                fan.minPwm = checked ? 0 : fan.minStop;
            }
        }

        Connections {
            target: root
            function onFanChanged() { if (!!fan) fanOffCheckBox.checked = fan.minPwm === 0 }
        }
        Connections {
            target: fan
            function onMinPwmChanged() { fanOffCheckBox.checked = fan.minPwm === 0 }
        }
    }

    RowLayout {
        enabled: fanOffCheckBox.checked && fanOffCheckBox.enabled

        Label {
            text: i18n("Pwm value for fan to start:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            renderType: Text.NativeRendering
        }
        SpinBox {
            id: minStartInput

            Layout.fillWidth: true
            from: 0
            to: 100
            editable: true
            value: !!fan ? Math.round(fan.minStart / 2.55) : 0
            textFromValue: function(value, locale) { return Number(value).toLocaleString(locale, 'f', 1) + locale.percent }
            onValueModified: {
                if (!!fan) {
                    fan.minStart = Math.round(value * 2.55)
                }
            }

            Connections {
                target: root
                function onFanChanged() { if (!!fan) minStartInput.value = Math.round(fan.minStart / 2.55) }
            }
            Connections {
                target: fan
                function onMinStartChanged() { minStartInput.value = Math.round(fan.minStart / 2.55) }
            }
        }
    }

    RowLayout {
        Label {
            text: i18n("Temperature to start curve:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            renderType: Text.NativeRendering
        }
        SpinBox {
            id: minTempInput

            Layout.fillWidth: true
            from: Math.ceil(Fancontrol.Base.minTemp)
            to: Math.max(from, maxTempInput.value - 1)
            editable: true
            value: !!fan ? fan.minTemp : from
            textFromValue: function(value, locale) { return Number(value).toLocaleString(locale, 'f', 0) + ' ' + i18n("°C") }
            onValueModified: {
                if (!!fan) fan.minTemp = value;
            }

            Connections {
                target: root
                function onFanChanged() { if (!!fan) minTempInput.value = Math.max(minTempInput.from, Math.min(fan.minTemp, maxTempInput.value - 1)) }
            }
            Connections {
                target: fan
                function onMinTempChanged() { minTempInput.value = Math.max(minTempInput.from, Math.min(fan.minTemp, maxTempInput.value - 1)) }
            }
        }
    }

    RowLayout {
        Label {
            text: i18n("Temperature to reach maximum:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            renderType: Text.NativeRendering
        }
        SpinBox {
            id: maxTempInput

            Layout.fillWidth: true
            from: minTempInput.value + 1
            to: Math.max(from, Math.floor(Fancontrol.Base.maxTemp))
            editable: true
            value: !!fan ? fan.maxTemp : to
            textFromValue: function(value, locale) { return Number(value).toLocaleString(locale, 'f', 0) + ' ' + i18n("°C") }
            onValueModified: {
                if (!!fan) fan.maxTemp = value;
            }

            Connections {
                target: root
                function onFanChanged() { if (!!fan) maxTempInput.value = Math.max(maxTempInput.from, Math.min(fan.maxTemp, Fancontrol.Base.maxTemp)) }
            }
            Connections {
                target: fan
                function onMaxTempChanged() { maxTempInput.value = Math.max(maxTempInput.from, Math.min(fan.maxTemp, Fancontrol.Base.maxTemp)) }
            }
        }
    }

    RowLayout {
        Label {
            text: i18n("Pwm value at MINTEMP (stop):")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            renderType: Text.NativeRendering
        }
        SpinBox {
            id: minStopInput

            Layout.fillWidth: true
            from: 0
            to: Math.round(fan.maxPwm / 2.55) || 100
            editable: true
            value: !!fan ? Math.round(fan.minStop / 2.55) : 0
            textFromValue: function(value, locale) { return Number(value).toLocaleString(locale, 'f', 1) + locale.percent }
            onValueModified: {
                if (!!fan) {
                    fan.minStop = Math.round(value * 2.55);
                    if (fan.minPwm !== 0) fan.minPwm = fan.minStop;
                }
            }

            Connections {
                target: root
                function onFanChanged() { if (!!fan) minStopInput.value = Math.round(fan.minStop / 2.55) }
            }
            Connections {
                target: fan
                function onMinStopChanged() { minStopInput.value = Math.round(fan.minStop / 2.55) }
            }
        }
    }

    RowLayout {
        Label {
            text: i18n("Pwm value at MAXTEMP:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            renderType: Text.NativeRendering
        }
        SpinBox {
            id: maxPwmInput

            Layout.fillWidth: true
            from: Math.round(fan.minStop / 2.55) || 0
            to: 100
            editable: true
            value: !!fan ? Math.round(fan.maxPwm / 2.55) : 100
            textFromValue: function(value, locale) { return Number(value).toLocaleString(locale, 'f', 1) + locale.percent }
            onValueModified: {
                if (!!fan) fan.maxPwm = Math.round(value * 2.55);
            }

            Connections {
                target: root
                function onFanChanged() { if (!!fan) maxPwmInput.value = Math.round(fan.maxPwm / 2.55) }
            }
            Connections {
                target: fan
                function onMaxPwmChanged() { maxPwmInput.value = Math.round(fan.maxPwm / 2.55) }
            }
        }
    }
}
