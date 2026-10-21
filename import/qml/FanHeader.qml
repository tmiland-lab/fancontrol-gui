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
import "colors.js" as Colors


RowLayout {
    id: root

    property QtObject fan
    property bool editable: true

    spacing: Kirigami.Units.smallSpacing

    Loader {
        active: !!fan
        sourceComponent: root.editable ? editableNameComponent : nameComponent
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.maximumWidth: root.width - idLabel.implicitWidth - Kirigami.Units.gridUnit * 3
    }

    Item {
        Layout.fillWidth: true
    }

    Label {
        id: idLabel

        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        Layout.rightMargin: Kirigami.Units.smallSpacing
        text: !!fan ? fan.id : ""
        color: Kirigami.Theme.disabledTextColor
        font: Kirigami.Theme.smallFont
        elide: Text.ElideLeft
    }

    Component {
        id: nameComponent

        Label {
            text: !!fan ? fan.name : ""
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
            elide: Text.ElideRight
        }
    }

    Component {
        id: editableNameComponent

        RowLayout {
            spacing: Kirigami.Units.smallSpacing

            TextField {
                id: nameField

                // No `text:` binding here: typing in a TextField destroys a
                // QML binding, after which the field kept showing the previous
                // fan's name forever (on fan switches too). Sync imperatively.
                placeholderText: i18n("Fan name")
                selectByMouse: true
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                implicitWidth: Math.max(Kirigami.Units.gridUnit * 10,
                                        contentWidth + leftPadding + rightPadding)
                leftPadding: Kirigami.Units.smallSpacing
                rightPadding: Kirigami.Units.smallSpacing
                // Frameless look that reads as a heading but is clearly an
                // editable field once hovered/focused.
                background: Rectangle {
                    radius: Kirigami.Units.smallSpacing
                    color: nameField.activeFocus || nameField.hovered
                           ? Kirigami.Theme.alternateBackgroundColor
                           : "transparent"
                    border.width: nameField.activeFocus ? 1 : 0
                    border.color: Colors.setAlpha(Kirigami.Theme.focusColor, 0.6)
                }

                function syncFromFan() {
                    if (nameField.activeFocus)
                        return;
                    var value = !!fan ? fan.name : "";
                    if (nameField.text !== value)
                        nameField.text = value;
                }

                // Switching fans must always show the new fan's name, even
                // while the field still has focus (sidebar clicks do not move
                // focus away), and must never commit the previous fan's text
                // to the new fan.
                function resetForFanChange() {
                    nameField.text = !!fan ? fan.name : "";
                    nameField.focus = false;
                }

                Component.onCompleted: syncFromFan()

                // Commit only when editing finishes (Enter/focus loss) so
                // partial names are not written on every keystroke.
                onEditingFinished: {
                    if (!!fan && text.trim().length > 0 && fan.name !== text.trim())
                        fan.name = text.trim();
                    else
                        syncFromFan();
                }

                Connections {
                    target: !!fan ? fan : null
                    function onNameChanged() { nameField.syncFromFan() }
                }

                Connections {
                    target: root
                    function onFanChanged() { nameField.resetForFanChange() }
                }
            }

            ToolButton {
                icon.name: "document-edit"
                visible: !nameField.activeFocus
                opacity: nameField.hovered || hovered ? 1 : 0.45
                ToolTip.text: i18n("Rename this fan")
                ToolTip.visible: hovered
                ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: {
                    nameField.forceActiveFocus();
                    nameField.selectAll();
                }
            }
        }
    }
}
