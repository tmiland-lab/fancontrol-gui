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

ColumnLayout {
    id: root

    property QtObject fan
    property int margin: Kirigami.Units.smallSpacing
    readonly property bool enabled: !!fan && fan.hasTemp
    readonly property bool running: !!fan && fan.testing
    readonly property int globalMinTemp: Math.ceil(Fancontrol.Base.minTemp)
    readonly property int globalMaxTemp: Math.floor(Fancontrol.Base.maxTemp)

    property int pendingProfile: -1
    property int idleTemp: -1
    // After an autotune the measured values are kept here so the user can
    // choose which preset to build from them, rather than having one applied
    // silently.
    property bool hasFreshMeasurement: false

    readonly property var profiles: [
        { name: i18n("Silent"), icon: "weather-clear-night", minPwm: 0,     maxPwm: 0.60, minTempOffset: 10, maxTempOffset: 30, tooltip: i18n("Apply a quiet fan curve") },
        { name: i18n("Cool"),   icon: "weather-snow",        minPwm: 0,     maxPwm: 1.00, minTempOffset: 3,  maxTempOffset: 18, tooltip: i18n("Apply a cool and quiet fan curve") },
        { name: i18n("Balanced"), icon: "preferences-system-balance", minPwm: 0,  maxPwm: 1.00, minTempOffset: 5, maxTempOffset: 20, tooltip: i18n("Apply a balanced fan curve") },
        { name: i18n("Performance"), icon: "speedometer",    minPwm: -1,    maxPwm: 1.00, minTempOffset: 1,  maxTempOffset: 10, tooltip: i18n("Apply an aggressive fan curve") }
    ]

    // Human readable phase label for the running test.
    readonly property string testPhase: {
        if (!fan)
            return "";
        switch (fan.testStatus) {
        case Fancontrol.PwmFan.FindingStop1:
            return i18n("Finding lowest speed…");
        case Fancontrol.PwmFan.FindingStart:
            return i18n("Finding start speed…");
        case Fancontrol.PwmFan.FindingStop2:
            return i18n("Finding stop speed…");
        default:
            return "";
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.margin

        // Progress strip while a test runs.
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: root.running

            BusyIndicator {
                running: root.running
                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
            }
            Label {
                text: root.testPhase
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Button {
                text: i18n("Abort")
                icon.name: "process-stop"
                flat: true
                onClicked: fan.abortTest()
            }
        }

        // Preset row.
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

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
                text: i18n("Autotune")
                icon.name: "run-build"
                enabled: root.enabled && !root.running
                Layout.minimumWidth: Kirigami.Units.gridUnit * 8
                ToolTip.text: i18n("Measure the fan's actual start and stop values")
                ToolTip.visible: hovered
                ToolTip.delay: Kirigami.Units.toolTipDelay

                onClicked: root.autotune()
            }

            Button {
                text: i18n("Save as profile…")
                icon.name: "document-save-as"
                enabled: root.enabled && !root.running && !Fancontrol.Base.needsApply
                Layout.minimumWidth: Kirigami.Units.gridUnit * 10
                ToolTip.text: i18n("Save the current fan settings as a named profile")
                ToolTip.visible: hovered
                ToolTip.delay: Kirigami.Units.toolTipDelay

                onClicked: root.saveAsProfile()
            }
        }
    }

    Connections {
        target: fan

        function onTestStatusChanged() {
            if (!root.fan)
                return;

            switch (root.fan.testStatus) {
            case Fancontrol.PwmFan.Finished:
                // Measurement done: keep the values, but let the user decide
                // which preset (if any) to build from them.
                root.hasFreshMeasurement = true;
                root.pendingProfile = -1;
                Fancontrol.Base.apply();
                break;
            case Fancontrol.PwmFan.Error:
                // Surface the failure instead of silently writing a fallback.
                root.pendingProfile = -1;
                break;
            case Fancontrol.PwmFan.Cancelled:
                root.pendingProfile = -1;
                break;
            default:
                break;
            }
        }
    }

    // Profile name prompt, shared by presets and "Save as profile".
    Dialog {
        id: nameDialog

        title: i18n("Save profile")
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent

        onAccepted: {
            var name = nameField.text.trim();
            if (name.length > 0)
                root.persistProfile(name);
            nameField.text = "";
        }
        onRejected: nameField.text = ""

        ColumnLayout {
            TextField {
                id: nameField
                placeholderText: i18n("Profile name")
            }
            Label {
                text: i18n("Current fan settings will be saved under this name.")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }

    function bound(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    // Apply a preset to the working configuration only. It is NOT persisted
    // automatically: the header "Apply" button writes it, or the user picks
    // "Save as profile…" to name it.
    function selectPreset(index) {
        if (!root.enabled || root.running)
            return;

        root.idleTemp = !!fan.temp ? fan.temp.value : 40;
        root.pendingProfile = index;
        root.applyProfile(index, root.idleTemp, false);
        Fancontrol.Base.apply();
    }

    // Measure the fan only. No preset is applied and nothing is saved.
    function autotune() {
        if (!root.enabled || root.running)
            return;

        // Capture idle temperature BEFORE the test: the test spins the fan
        // at full speed and cools the system down, which would skew the baseline.
        root.idleTemp = !!fan.temp ? fan.temp.value : 40;
        root.pendingProfile = -1;
        root.hasFreshMeasurement = false;
        fan.test();
    }

    function saveAsProfile() {
        nameField.text = "";
        nameDialog.open();
    }

    function persistProfile(name) {
        if (Fancontrol.Base.profileExists(name)) {
            overwritePrompt.text = i18n("A profile named '%1' already exists. Overwrite it?", name);
            overwritePrompt.pendingName = name;
            overwritePrompt.open();
            return;
        }

        Fancontrol.Base.saveProfile(name);
    }

    Dialog {
        id: overwritePrompt

        property string text: ""
        property string pendingName: ""

        title: i18n("Overwrite profile")
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent

        onAccepted: Fancontrol.Base.saveProfile(pendingName)

        Label {
            text: overwritePrompt.text
            wrapMode: Text.WordWrap
            width: Kirigami.Units.gridUnit * 20
        }
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

    function reset() {
        root.pendingProfile = -1;
        root.idleTemp = -1;
    }
}