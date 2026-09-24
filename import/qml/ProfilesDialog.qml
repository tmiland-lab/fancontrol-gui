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
import QtQuick.Dialogs 6
import org.kde.kirigami 2.14 as Kirigami
import Fancontrol.Qml 1.0 as Fancontrol


Dialog {
    id: profilesDialog

    title: i18n("Manage profiles")
    width: Kirigami.Units.gridUnit * 25
    height: Kirigami.Units.gridUnit * 22
    standardButtons: Dialog.Close

    RowLayout {
        anchors.fill: parent

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Without a minimum the button column (whose buttons don't elide)
            // can claim the whole row, collapsing the list to a sliver.
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Kirigami.Theme.textColor

            ListView {
                id: profilesListView

                anchors.fill: parent
                anchors.margins: parent.border.width
                model: Fancontrol.Base.profileModel
                clip: true
                currentIndex: Fancontrol.Base.currentProfileIndex
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.AutoFlickIfNeeded
                header: ItemDelegate {
                    text: '<b>' + i18n("Profiles") + '</b>'
                    hoverEnabled: false
                    enabled: false
                    padding: Kirigami.Units.smallSpacing
                }
                delegate: ItemDelegate {
                    readonly property string profileName: model.display
                    text: {
                        if (Fancontrol.Base.currentProfileIndex === index)
                            return model.display + ' ' + i18n("(current profile)")
                        else
                            return model.display
                    }
                    hoverEnabled: true
                    highlighted: ListView.isCurrentItem
                    onClicked: profilesListView.currentIndex = index
                }
            }
        }

        ColumnLayout {
            Layout.fillHeight: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 13

            Button {
                text: i18n("Apply profile")
                enabled: profilesListView.currentIndex >= 0 &&
                         Fancontrol.Base.currentProfileIndex !== profilesListView.currentIndex
                onClicked: Fancontrol.Base.applyProfile(profilesListView.currentIndex)
            }
            Button {
                text: i18n("Create new profile")
                enabled: Fancontrol.Base.currentProfileIndex === -1
                ToolTip.text: i18n("Save the current settings as a new named profile")
                ToolTip.visible: hovered
                ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: {
                    newProfileNameField.text = "";
                    newProfileNameDialog.title = i18n("New profile's name");
                    newProfileNameDialog.open();
                }
            }
            Button {
                text: i18n("Save to profile")
                enabled: profilesListView.currentIndex >= 0 &&
                         Fancontrol.Base.currentProfileIndex !== profilesListView.currentIndex
                ToolTip.text: i18n("Overwrite the selected profile with the current settings")
                ToolTip.visible: hovered
                ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: {
                    overwriteName = profilesListView.currentItem.profileName;
                    overwriteDialog.text = i18n("Overwrite profile '%1' with the current settings?", overwriteName);
                    overwriteDialog.open();
                }
            }
            Button {
                text: i18n("Rename profile")
                enabled: profilesListView.currentIndex >= 0
                onClicked: {
                    newProfileNameField.text = profilesListView.currentItem.profileName;
                    newProfileNameDialog.title = i18n("Rename profile");
                    newProfileNameDialog.open();
                }
            }
            Button {
                text: i18n("Duplicate profile")
                enabled: profilesListView.currentIndex >= 0
                onClicked: Fancontrol.Base.duplicateProfile(profilesListView.currentIndex, "")
            }
            Button {
                text: i18n("Delete profile")
                enabled: profilesListView.currentIndex >= 0
                onClicked: {
                    deleteDialog.text = i18n("Delete profile '%1'? This cannot be undone.",
                                             profilesListView.currentItem.profileName);
                    deleteDialog.open();
                }
            }

            Item { Layout.fillHeight: true; Layout.preferredHeight: Kirigami.Units.gridUnit * 2 }

            Label {
                text: i18n("Import/Export:")
                font.bold: true
                Layout.fillWidth: true
            }

            Button {
                text: i18n("Export profile")
                icon.name: "document-save"
                enabled: profilesListView.currentIndex >= 0
                Layout.fillWidth: true
                onClicked: {
                    var profileName = profilesListView.currentItem ? profilesListView.currentItem.profileName : "fan_profile";
                    exportFileDialog.currentFile = Qt.url("file://" + profileName + ".conf");
                    exportFileDialog.open();
                }
            }

            Button {
                text: i18n("Import profile")
                icon.name: "document-open"
                Layout.fillWidth: true
                onClicked: importFileDialog.open()
            }
        }
    }

    property string overwriteName: ""

    Dialog {
        id: overwriteDialog

        property string text: ""

        title: i18n("Overwrite profile")
        standardButtons: Dialog.Ok | Dialog.Cancel
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        onAccepted: Fancontrol.Base.saveProfile(overwriteName)

        Label {
            text: overwriteDialog.text
            wrapMode: Text.WordWrap
            width: Kirigami.Units.gridUnit * 20
        }
    }

    Dialog {
        id: deleteDialog

        property string text: ""

        title: i18n("Delete profile")
        standardButtons: Dialog.Ok | Dialog.Cancel
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        onAccepted: Fancontrol.Base.deleteProfile(profilesListView.currentIndex)

        Label {
            text: deleteDialog.text
            wrapMode: Text.WordWrap
            width: Kirigami.Units.gridUnit * 20
        }
    }

    Dialog {
        id: newProfileNameDialog

        title: i18n("New profile's name")
        standardButtons: Dialog.Ok | Dialog.Cancel
        visible: false
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        onAccepted: {
            var name = newProfileNameField.text.trim();

            if (name.length === 0)
                return;

            if (newProfileNameDialog.title === i18n("Rename profile") &&
                    profilesListView.currentIndex >= 0) {
                Fancontrol.Base.renameProfile(profilesListView.currentIndex, name);
            } else if (Fancontrol.Base.profileExists(name)) {
                overwriteName = name;
                overwriteDialog.text = i18n("A profile named '%1' already exists. Overwrite it?", name);
                overwriteDialog.open();
            } else {
                Fancontrol.Base.saveProfile(name);
            }

            newProfileNameField.text = "";
        }
        onRejected: newProfileNameField.text = ""

        TextField {
            id: newProfileNameField
            placeholderText: i18n("Profile name")
        }
    }

    FileDialog {
        id: exportFileDialog

        title: i18n("Export profile")
        fileMode: FileDialog.SaveFile
        nameFilters: [i18n("Fancontrol config (*.conf)")]
        modality: Qt.NonModal

        onAccepted: Fancontrol.Base.exportProfile(profilesListView.currentIndex, selectedFile)
    }

    FileDialog {
        id: importFileDialog

        title: i18n("Import profile")
        fileMode: FileDialog.OpenFile
        nameFilters: [i18n("Fancontrol config (*.conf)")]
        modality: Qt.NonModal

        onAccepted: Fancontrol.Base.importProfile(selectedFile)
    }
}
