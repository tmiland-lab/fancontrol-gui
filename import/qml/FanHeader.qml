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

                text: !!fan ? fan.name : ""
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

                // Commit only when editing finishes (Enter/focus loss) so
                // partial names are not written on every keystroke.
                onEditingFinished: {
                    if (!!fan && text.trim().length > 0 && fan.name !== text.trim())
                        fan.name = text.trim();
                    else if (!!fan)
                        text = fan.name;
                }

                Connections {
                    target: !!fan ? fan : null
                    function onNameChanged() {
                        if (!nameField.activeFocus && fan.name !== nameField.text)
                            nameField.text = fan.name;
                    }
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
