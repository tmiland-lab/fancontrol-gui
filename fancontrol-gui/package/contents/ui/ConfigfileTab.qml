/*
 * Copyright (C) 2015  Malte Veerman <malte.veerman@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
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
import "ConfigParser.js" as ConfigParser


Kirigami.ScrollablePage {
    id: root

    readonly property QtObject loader: Fancontrol.Base.loader

    readonly property var parsed: ConfigParser.parse(!!loader ? loader.config : "")
    readonly property var issues: ConfigParser.validate(parsed)
    readonly property var changes: !!loader && loader.needsSave
                                      ? ConfigParser.diff(loader.savedConfig, loader.config)
                                      : []
    readonly property int errorCount: {
        var n = 0;
        for (var i = 0; i < issues.length; i++)
            if (issues[i].severity === "error") ++n;
        return n;
    }
    readonly property int warningCount: issues.length - errorCount

    function fmt(value) {
        return value === undefined || value === null ? i18n("—") : value;
    }

    header: ColumnLayout {
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                level: 3
                text: i18n("Fancontrol configuration")
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            Label {
                text: !!loader ? loader.configPath : ""
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideLeft
                Layout.maximumWidth: root.width / 2
            }
        }

        TabBar {
            id: modeBar
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing

            TabButton { text: i18n("Raw") }
            TabButton { text: i18n("Table") }
            TabButton {
                text: root.changes.length > 0
                      ? i18n("Changes (%1)", root.changes.length)
                      : i18n("Changes")
            }
        }
    }

    actions: [
        Kirigami.Action {
            text: i18n("Copy")
            icon.name: "edit-copy"
            enabled: !!loader
            onTriggered: {
                clipboard.text = loader.config;
                clipboard.selectAll();
                clipboard.copy();
            }
        },
        Kirigami.Action {
            text: i18n("Import")
            icon.name: "document-open-remote"
            enabled: !!loader
            onTriggered: {
                pasteArea.text = "";
                importUrlField.text = "";
                importError.text = "";
                importDialog.open();
            }
        },
        Kirigami.Action {
            text: i18n("Reload")
            icon.name: "view-refresh"
            enabled: !!loader
            onTriggered: loader.load()
        },
        Kirigami.Action {
            text: i18n("Apply")
            icon.name: "dialog-ok-apply"
            enabled: Fancontrol.Base.needsApply
            onTriggered: Fancontrol.Base.apply()
        },
        Kirigami.Action {
            text: i18n("Reset")
            icon.name: "edit-undo"
            enabled: Fancontrol.Base.needsApply
            onTriggered: Fancontrol.Base.reset()
        }
    ]

    // Hidden helper for the "copy" action.
    TextEdit {
        id: clipboard
        visible: false
        width: 0
        height: 0
    }

    // ScrollablePage stacks page children at the same position, so all content
    // has to live inside one layout root.
    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.issues.length > 0
            type: root.errorCount > 0 ? Kirigami.MessageType.Error : Kirigami.MessageType.Warning
            text: root.errorCount > 0
                  ? i18np("%1 problem found in this configuration.", "%1 problems found in this configuration.", root.issues.length)
                  : i18np("%1 issue found in this configuration.", "%1 issues found in this configuration.", root.issues.length)
        }

        // --- Issues -------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.issues.length > 0
            spacing: 0

            Repeater {
                model: root.issues

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        Layout.preferredWidth: Kirigami.Units.smallSpacing
                        Layout.preferredHeight: Kirigami.Units.smallSpacing
                        radius: width / 2
                        color: modelData.severity === "error"
                               ? Kirigami.Theme.negativeTextColor
                               : Kirigami.Theme.neutralTextColor
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: modelData.entry.length > 0
                              ? i18n("%1: %2", modelData.entry, modelData.message)
                              : modelData.message
                        color: modelData.severity === "error"
                               ? Kirigami.Theme.negativeTextColor
                               : Kirigami.Theme.textColor
                    }
                }
            }
        }

        // --- Raw ----------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: editor.contentHeight + Kirigami.Units.largeSpacing * 2
            Layout.minimumHeight: Kirigami.Units.gridUnit * 8
            visible: modeBar.currentIndex === 0
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.alternateBackgroundColor
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                  Kirigami.Theme.textColor.g,
                                  Kirigami.Theme.textColor.b, 0.12)

            TextEdit {
                id: editor

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Kirigami.Units.largeSpacing
                }
                text: !!loader ? loader.config : ""
                readOnly: true
                selectByMouse: true
                persistentSelection: true
                color: Kirigami.Theme.textColor
                wrapMode: TextEdit.Wrap
                font.family: "monospace"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
            }
        }

        // --- Table --------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            visible: modeBar.currentIndex === 1
            spacing: Kirigami.Units.largeSpacing

            // Globals card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: globalsColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.alternateBackgroundColor
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                      Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.12)

                ColumnLayout {
                    id: globalsColumn

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Kirigami.Units.largeSpacing
                    }
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading { level: 4; text: i18n("General"); Layout.fillWidth: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: i18n("Interval")
                            color: Kirigami.Theme.disabledTextColor
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                        }
                        Label {
                            text: root.parsed.globals.INTERVAL === undefined
                                  ? i18n("—")
                                  : i18np("%1 second", "%1 seconds", root.parsed.globals.INTERVAL)
                            font.bold: true
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: i18n("Devices")
                            color: Kirigami.Theme.disabledTextColor
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                        }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: {
                                var names = [];
                                for (var k in root.parsed.globals.DEVNAME)
                                    names.push(k + " = " + root.parsed.globals.DEVNAME[k]);
                                return names.length > 0 ? names.join(", ") : i18n("—");
                            }
                        }
                    }
                }
            }

            // Per-fan cards
            Repeater {
                model: root.parsed.fans

                Rectangle {
                    readonly property var f: modelData

                    Layout.fillWidth: true
                    implicitHeight: fanColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
                    radius: Kirigami.Units.smallSpacing
                    color: Kirigami.Theme.alternateBackgroundColor
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                          Kirigami.Theme.textColor.g,
                                          Kirigami.Theme.textColor.b, 0.12)

                    ColumnLayout {
                        id: fanColumn

                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Kirigami.Units.largeSpacing
                        }
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Heading { level: 4; text: f.entry; Layout.fillWidth: true; elide: Text.ElideRight }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: Kirigami.Units.largeSpacing
                            rowSpacing: Kirigami.Units.smallSpacing

                            Label { text: i18n("Temperature"); color: Kirigami.Theme.disabledTextColor }
                            Label { text: root.fmt(f.temp); Layout.fillWidth: true; elide: Text.ElideRight }
                            Label { text: i18n("Fan"); color: Kirigami.Theme.disabledTextColor }
                            Label { text: root.fmt(f.fan); Layout.fillWidth: true; elide: Text.ElideRight }

                            Label { text: "MINTEMP"; color: Kirigami.Theme.disabledTextColor }
                            Label { text: root.fmt(f.minTemp) }
                            Label { text: "MAXTEMP"; color: Kirigami.Theme.disabledTextColor }
                            Label { text: root.fmt(f.maxTemp) }

                            Label { text: "MINSTART"; color: Kirigami.Theme.disabledTextColor }
                            Label { text: root.fmt(f.minStart) }
                            Label { text: "MINSTOP"; color: Kirigami.Theme.disabledTextColor }
                            Label { text: root.fmt(f.minStop) }

                            Label { text: "MINPWM"; color: Kirigami.Theme.disabledTextColor }
                            Label { text: root.fmt(f.minPwm) }
                            Label { text: "MAXPWM"; color: Kirigami.Theme.disabledTextColor }
                            Label { text: root.fmt(f.maxPwm) }

                            Label { text: "AVERAGE"; color: Kirigami.Theme.disabledTextColor }
                            Label { text: root.fmt(f.average) }
                            Item { Layout.fillWidth: true }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }

        // --- Changes ------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            visible: modeBar.currentIndex === 2
            spacing: 0

            Label {
                visible: root.changes.length === 0
                Layout.fillWidth: true
                text: i18n("No pending changes.")
                color: Kirigami.Theme.disabledTextColor
            }

            Repeater {
                model: root.changes

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Label {
                        text: modelData.entry.length > 0
                              ? i18n("%1 %2:", modelData.entry, modelData.key)
                              : modelData.key + ":"
                        color: Kirigami.Theme.disabledTextColor
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                        elide: Text.ElideRight
                    }
                    Label {
                        text: root.fmt(modelData.old)
                        color: Kirigami.Theme.negativeTextColor
                        font.strikeout: true
                    }
                    Kirigami.Icon {
                        source: "arrow-right"
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                    }
                    Label {
                        text: modelData.new === undefined ? i18n("removed") : root.fmt(modelData.new)
                        color: modelData.new === undefined
                               ? Kirigami.Theme.negativeTextColor
                               : Kirigami.Theme.positiveTextColor
                        font.bold: true
                    }
                }
            }
        }
    }

    // --- Import (paste or URL) --------------------------------------------
    Dialog {
        id: importDialog

        title: i18n("Import configuration")
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent
        implicitWidth: Kirigami.Units.gridUnit * 30

        onAccepted: {
            var text = pasteArea.text.trim();
            if (text.length === 0)
                return;
            if (loader.importConfig(text))
                modeBar.currentIndex = 2;
            else
                importError.text = i18n("The pasted text is not a valid configuration.");
        }

        ColumnLayout {
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18n("Paste a configuration below, or download one from a URL.")
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 12

                TextArea {
                    id: pasteArea
                    placeholderText: "INTERVAL=10\nFCTEMPS=..."
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    font.family: "monospace"
                }
            }

            RowLayout {
                Layout.fillWidth: true

                TextField {
                    id: importUrlField
                    Layout.fillWidth: true
                    placeholderText: i18n("https://example.com/fancontrol.conf")
                    inputMethodHints: Qt.ImhUrlCharactersOnly
                    onAccepted: if (text.trim().length > 0) fetchFromUrl(text.trim())
                }
                Button {
                    text: i18n("Download")
                    icon.name: "download"
                    onClicked: if (importUrlField.text.trim().length > 0) fetchFromUrl(importUrlField.text.trim())
                }
            }

            Label {
                id: importError
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.negativeTextColor
                visible: text.length > 0
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18n("The imported configuration is loaded but not written to disk until you Apply.")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }

    function fetchFromUrl(url) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200 && xhr.responseText.length > 0) {
                pasteArea.text = xhr.responseText;
                importError.text = "";
            } else {
                importError.text = i18n("Download failed (HTTP %1).", xhr.status);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }
}
