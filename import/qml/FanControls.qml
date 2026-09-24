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
import org.kde.kirigami 2.14 as Kirigami
import Fancontrol.Qml 1.0 as Fancontrol


GridLayout {
    id: root

    property int padding: Kirigami.Units.smallSpacing
    property QtObject fan
    readonly property QtObject tempModel: Fancontrol.Base.tempModel

    // Every value field shares this width so the column lines up cleanly.
    readonly property int fieldWidth: Kirigami.Units.gridUnit * 12

    columns: 2
    columnSpacing: Kirigami.Units.largeSpacing
    rowSpacing: Kirigami.Units.smallSpacing
    Layout.leftMargin: root.padding
    Layout.rightMargin: root.padding

    // --- Controller -------------------------------------------------------
    CheckBox {
        id: hasTempCheckBox
        text: i18n("Controlled by:")
        checked: !!fan ? fan.hasTemp : false
        Layout.fillWidth: true
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

    ComboBox {
        id: tempBox

        Layout.fillWidth: true
        Layout.preferredWidth: root.fieldWidth * 2
        model: tempModel
        currentIndex: !!fan && fan.hasTemp ? tempModel.indexOf(fan.temp) : -1
        textRole: "display"
        enabled: hasTempCheckBox.checked
        onCurrentIndexChanged: {
            if (hasTempCheckBox.checked)
                fan.temp = tempModel.temp(currentIndex);
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

    // --- Averaging --------------------------------------------------------
    Label {
        text: i18n("Cycles to average temperature")
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        elide: Text.ElideRight
    }

    SpinBox {
        id: averageInput

        Layout.preferredWidth: root.fieldWidth
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

    // --- Fan-off behavior -------------------------------------------------
    CheckBox {
        id: fanOffCheckBox

        Layout.columnSpan: 2
        Layout.fillWidth: true
        text: i18n("Turn fan off when temperature is below the start temperature")
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

    // --- Start speed ------------------------------------------------------
    Label {
        text: i18n("Start PWM value")
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        enabled: fanOffCheckBox.checked && fanOffCheckBox.enabled
        elide: Text.ElideRight
    }

    SpinBox {
        id: minStartInput

        Layout.preferredWidth: root.fieldWidth
        enabled: fanOffCheckBox.checked && fanOffCheckBox.enabled
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

    // --- Temperature curve -------------------------------------------------
    Label {
        text: i18n("Start temperature")
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        elide: Text.ElideRight
    }

    SpinBox {
        id: minTempInput

        Layout.preferredWidth: root.fieldWidth
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

    Label {
        text: i18n("Maximum temperature")
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        elide: Text.ElideRight
    }

    SpinBox {
        id: maxTempInput

        Layout.preferredWidth: root.fieldWidth
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

    // --- PWM levels --------------------------------------------------------
    Label {
        text: i18n("PWM at start temperature")
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        elide: Text.ElideRight
    }

    SpinBox {
        id: minStopInput

        Layout.preferredWidth: root.fieldWidth
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

    Label {
        text: i18n("PWM at maximum temperature")
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        elide: Text.ElideRight
    }

    SpinBox {
        id: maxPwmInput

        Layout.preferredWidth: root.fieldWidth
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
