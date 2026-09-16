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

RowLayout {
    id: root

    property QtObject fan
    readonly property bool enabled: !!fan && fan.hasTemp

    ButtonGroup {
        id: presetGroup
    }

    Button {
        id: silentButton
        text: i18n("Silent")
        icon.name: "weather-clear-night"
        enabled: root.enabled
        Layout.fillWidth: true
        tooltip: i18n("Low fan speeds, prioritizes quiet operation")
        checkable: true
        ButtonGroup.group: presetGroup

        onToggled: {
            if (checked) {
                root.fan.minPwm = 0;
                root.fan.minTemp = 50;
                root.fan.minStart = Math.round(25 * 2.55);
                root.fan.minStop = Math.round(20 * 2.55);
                root.fan.maxPwm = Math.round(70 * 2.55);
                root.fan.maxTemp = 75;
            }
        }
    }

    Button {
        id: balancedButton
        text: i18n("Balanced")
        icon.name: "preferences-system-balance"
        enabled: root.enabled
        Layout.fillWidth: true
        tooltip: i18n("Balanced fan curve for typical workloads")
        checkable: true
        ButtonGroup.group: presetGroup

        onToggled: {
            if (checked) {
                root.fan.minPwm = Math.round(20 * 2.55);
                root.fan.minTemp = 40;
                root.fan.minStart = Math.round(30 * 2.55);
                root.fan.minStop = Math.round(25 * 2.55);
                root.fan.maxPwm = Math.round(100 * 2.55);
                root.fan.maxTemp = 75;
            }
        }
    }

    Button {
        id: performanceButton
        text: i18n("Performance")
        icon.name: "speedometer"
        enabled: root.enabled
        Layout.fillWidth: true
        tooltip: i18n("More aggressive cooling, higher noise")
        checkable: true
        ButtonGroup.group: presetGroup

        onToggled: {
            if (checked) {
                root.fan.minPwm = Math.round(30 * 2.55);
                root.fan.minTemp = 35;
                root.fan.minStart = Math.round(40 * 2.55);
                root.fan.minStop = Math.round(35 * 2.55);
                root.fan.maxPwm = Math.round(100 * 2.55);
                root.fan.maxTemp = 60;
            }
        }
    }

    onFanChanged: updateChecks()
    Component.onCompleted: updateChecks()

    function updateChecks() {
        if (!root.fan) {
            silentButton.checked = false;
            balancedButton.checked = false;
            performanceButton.checked = false;
            return;
        }
        if (root.fan.minPwm === 0)
            silentButton.checked = true;
        else if (root.fan.minPwm > Math.round(70 * 2.55))
            performanceButton.checked = true;
        else
            balancedButton.checked = true;
    }
}