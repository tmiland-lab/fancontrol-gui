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

RowLayout {
    id: root

    property QtObject fan
    readonly property bool enabled: !!fan && fan.hasTemp
    readonly property bool running: !!fan && fan.testing
    readonly property int globalMinTemp: Math.ceil(Fancontrol.Base.minTemp)
    readonly property int globalMaxTemp: Math.floor(Fancontrol.Base.maxTemp)

    property int pendingProfile: -1
    property int idleTemp: -1

    readonly property var profiles: [
        { name: i18n("Silent"), icon: "weather-clear-night", minPwm: 0,     maxPwm: 0.60, minTempOffset: 10, maxTempOffset: 30, tooltip: i18n("Apply a quiet fan curve") },
        { name: i18n("Cool"),   icon: "weather-snow",        minPwm: 0,     maxPwm: 1.00, minTempOffset: 3,  maxTempOffset: 18, tooltip: i18n("Apply a cool and quiet fan curve") },
        { name: i18n("Balanced"), icon: "preferences-system-balance", minPwm: 0,  maxPwm: 1.00, minTempOffset: 5, maxTempOffset: 20, tooltip: i18n("Apply a balanced fan curve") },
        { name: i18n("Performance"), icon: "speedometer",    minPwm: -1,    maxPwm: 1.00, minTempOffset: 1,  maxTempOffset: 10, tooltip: i18n("Apply an aggressive fan curve") }
    ]

    Connections {
        target: fan

        function onTestStatusChanged() {
            if (!root.fan || root.pendingProfile < 0)
                return;

            if (root.fan.testStatus === Fancontrol.PwmFan.Finished) {
                root.applyProfile(root.pendingProfile, root.idleTemp, false);
                root.save();
            } else if (root.fan.testStatus === Fancontrol.PwmFan.Error ||
                       root.fan.testStatus === Fancontrol.PwmFan.Cancelled) {
                // The test could not be completed (e.g. no permission to set
                // the PWM). Apply a static fallback curve so the buttons never
                // hang and a profile is still produced.
                root.applyProfile(root.pendingProfile, root.idleTemp, true);
                root.save();
            }
        }
    }

    Repeater {
        model: root.profiles

        delegate: Button {
            text: modelData.name
            icon.name: modelData.icon
            enabled: root.enabled && !root.running
            Layout.fillWidth: true
            ToolTip.text: modelData.tooltip
            ToolTip.visible: hovered
            ToolTip.delay: Kirigami.Units.toolTipDelay

            onClicked: root.selectPreset(index)
        }
    }

    Button {
        text: root.running ? i18n("Autotuning…") : i18n("Autotune")
        icon.name: "run-build"
        enabled: root.enabled
        Layout.minimumWidth: Kirigami.Units.gridUnit * 8
        ToolTip.text: i18n("Measure the fan's actual start and stop values")
        ToolTip.visible: hovered
        ToolTip.delay: Kirigami.Units.toolTipDelay

        onClicked: {
            if (root.running)
                fan.abortTest();
            else
                root.autotune(root.pendingProfile >= 0 ? root.pendingProfile : 0);
        }
    }

    function bound(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function selectPreset(index) {
        if (!root.enabled || root.running)
            return;

        // Apply the preset curve immediately, using the last measured start
        // and stop values when available.
        root.idleTemp = !!fan.temp ? fan.temp.value : 40;
        root.pendingProfile = index;
        root.applyProfile(index, root.idleTemp, false);
        root.save();
    }

    function autotune(index) {
        if (!root.enabled || root.running)
            return;

        // Capture idle temperature BEFORE the test: the test spins the fan
        // at full speed and cools the system down, which would skew the baseline.
        root.idleTemp = !!fan.temp ? fan.temp.value : 40;
        root.pendingProfile = index >= 0 ? index : 0;
        fan.test();
    }

    function applyProfile(index, idle, fallback) {
        if (!fan)
            return;

        var profile = root.profiles[index];
        if (!profile)
            return;

        // Measured hardware values from the test (0..255).
        // Only trust them when the test actually finished: an untouched fan
        // keeps its default minStart/minStop of 255 (i.e. "unknown"), which
        // would otherwise produce an invalid MINSTOP >= MAXPWM config.
        var minStart;
        var minStop;
        if (!fallback && fan.testStatus === Fancontrol.PwmFan.Finished &&
                fan.minStart > 0 && fan.minStop > 0 && fan.minStop < 255) {
            minStart = fan.minStart;
            minStop = fan.minStop;
        } else {
            minStart = Math.round(25 * 2.55);
            minStop = Math.round(20 * 2.55);
        }

        // Profile-specific fan-off behavior.
        // minPwm === -1 means: always keep spinning (minPwm = minStop).
        fan.minPwm = profile.minPwm >= 0 ? Math.round(profile.minPwm * 2.55) : minStop;
        fan.minStart = minStart;
        fan.minStop = minStop;

        // Temperature thresholds relative to a clamped idle baseline. The raw
        // reading at click time may be inflated (warm machine, right after
        // load), so clamp it and hard-cap the curve so the fan always engages
        // at a safe temperature.
        var baseline = bound(idle, 30, Math.min(root.globalMaxTemp - 20, 45));
        var minTemp = bound(baseline + profile.minTempOffset, root.globalMinTemp, Math.min(root.globalMaxTemp - 1, 55));
        var maxTemp = bound(baseline + profile.maxTempOffset, minTemp + 1, Math.min(root.globalMaxTemp, 85));

        // Amplitude, relative to the measured start value.
        var ampl = Math.max(0, 255 - minStop);
        var maxPwm = minStop + Math.round(ampl * profile.maxPwm);

        fan.minTemp = minTemp;
        fan.maxTemp = maxTemp;
        fan.maxPwm = Math.round(bound(maxPwm, fan.minPwm, 255));
    }

    function save() {
        // Persist the generated curve as a named profile so the user can
        // re-apply it later from the system tray or the Profiles dialog.
        var profile = root.profiles[root.pendingProfile];
        if (profile) {
            Fancontrol.Base.saveProfile(profile.name);
            Fancontrol.Base.apply();
        }
        root.reset();
    }

    function reset() {
        root.pendingProfile = -1;
        root.idleTemp = -1;
    }
}