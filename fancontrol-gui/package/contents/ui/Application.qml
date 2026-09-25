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
import Fancontrol.Gui 1.0 as Gui
import Fancontrol.Qml 1.0 as Fancontrol


Kirigami.ApplicationWindow {
    id: window

    // Mirror the system dark/light preference (detected in C++ and re-checked
    // at runtime) onto the window palette, so palette-driven QML controls
    // follow the scheme even when the platform theme does not.
    readonly property bool darkMode: !!_theme && _theme.dark
    palette.window: darkMode ? "#232629" : "#faf9f8"
    palette.windowText: darkMode ? "#eff0f1" : "#000000"
    palette.base: darkMode ? "#232629" : "#ffffff"
    palette.alternateBase: darkMode ? "#31363b" : "#eff0f1"
    palette.text: darkMode ? "#eff0f1" : "#000000"
    palette.button: darkMode ? "#31363b" : "#eff0f1"
    palette.buttonText: darkMode ? "#eff0f1" : "#000000"
    palette.toolTipBase: darkMode ? "#31363b" : "#ffffdc"
    palette.toolTipText: darkMode ? "#eff0f1" : "#000000"

    property string leftPage
    readonly property QtObject pwmFanModel: Fancontrol.Base.pwmFanModel
    property QtObject fan: pwmFanModel.length > 0 ? pwmFanModel.fan(0) : null

    function showWindow() {
        window.show()
        window.raise()
        window.requestActivate()
    }

    title: i18n("Fancontrol-GUI")
    minimumWidth: Kirigami.Units.gridUnit * 20
    minimumHeight: Kirigami.Units.gridUnit * 15
    pageStack.defaultColumnWidth: Kirigami.Units.gridUnit * 25

    onLeftPageChanged: {
        window.pageStack.clear();
        if (leftPage) {
            var url = Qt.resolvedUrl(leftPage);
            var component = Qt.createComponent(url);

            if (component.status === Component.Ready) {
                var page = component.createObject(window.pageStack);

                if (page)
                    window.pageStack.push(page);
                else
                    console.log("Error creating page object: %1", url);
            } else {
                console.log("Error creating page component: %1", component.errorString());
            }
        }
    }

    onWideScreenChanged: drawer.drawerOpen = wideScreen

    onClosing: {
        if (Fancontrol.Base.needsApply && !saveOnCloseDialog.answered) {
            close.accepted = false;
            saveOnCloseDialog.open();
            return;
        }
    }

    Component.onCompleted: {
        Fancontrol.Base.load();
        window.visible = !Fancontrol.Base.startMinimized;
        leftPage = "SensorsTab.qml";
    }

    globalDrawer: Kirigami.GlobalDrawer {
        id: drawer

        width: Kirigami.Units.gridUnit * 10
        modal: !window.wideScreen
        handleVisible: !window.wideScreen
        resetMenuOnTriggered: false

        function populateFans() {
            for (var i = fansAction.children.length - 1; i >= 0; i--) {
                fansAction.children[i].destroy();
            }

            var actions = [];
            for (var i = 0; i < pwmFanModel.length; i++) {
                var action = fanActionComponent.createObject(fansAction, { "index": i });

                if (action)
                    actions.push(action);
                else
                    console.log("Error creating fan action with index %1", i);
            }
            fansAction.children = actions;
        }

        Component {
            id: fanActionComponent

            Kirigami.Action {
                property int index
                property QtObject fan: pwmFanModel.fan(index)

                text: !!fan ? fan.name : ""
                visible: !!fan
                checked: window.fan === fan

                onTriggered: window.fan = fan
            }
        }

        Component.onCompleted: populateFans()

        Connections {
            target: pwmFanModel
            function onFansChanged() {
                for (var i = 0; i < pwmFanModel.length && i < fansAction.children.length; i++) {
                    fansAction.children[i].fan = pwmFanModel.fan(i);
                }
            }
        }

        actions: [
            Kirigami.Action {
                text: i18n("Sensors")
                checked: window.leftPage === "SensorsTab.qml"

                onTriggered: window.leftPage = "SensorsTab.qml"
            },
            Kirigami.Action {
                id: fansAction

                text: i18n("Fans")
                checked: window.leftPage === "PwmFansTab.qml"

                onTriggered: window.leftPage = "PwmFansTab.qml"
            },
            Kirigami.Action {
                text: i18n("Configfile")
                checked: window.leftPage === "ConfigfileTab.qml"

                onTriggered: window.leftPage = "ConfigfileTab.qml"
            },
            Kirigami.Action {
                text: i18n("Settings")
                checked: window.leftPage === "SettingsTab.qml"

                onTriggered: window.leftPage = "SettingsTab.qml"
            }
        ]
    }

    contextDrawer: Kirigami.ContextDrawer {}

    Loader {
        id: trayLoader

        active: Fancontrol.Base.showTray

        sourceComponent: Component {
            Gui.SystemTrayIcon {
                id: trayIcon
                title: "Fancontrol-GUI"
                iconName: "org.kde.fancontrol.gui"
                profileModel: Fancontrol.Base.profileModel
                tooltipSummary: {
                    var temps = Fancontrol.Base.tempModel;
                    var summary = "";
                    for (var i = 0; i < temps.length; i++) {
                        var t = temps.temp(i);
                        if (summary.length > 0)
                            summary += "\n";
                        summary += t.label + ": " + t.value + "°C";
                    }
                    return summary;
                }

                onActivateRequested: window.showWindow()
                onActivateProfile: {
                    Fancontrol.Base.applyProfile(profile);
                    Fancontrol.Base.apply();
                }
                onActivateService: Fancontrol.Base.systemdCom.serviceActive = active
                onEnableService: Fancontrol.Base.systemdCom.serviceEnabled = enabled
            }
        }
    }

    Fancontrol.ErrorDialog {
        id: errorDialog

        visible: false
        anchors.centerIn: parent
    }

    Dialog {
        id: saveOnCloseDialog

        property bool answered: false

        visible: false
        modal: true
        title: i18n("Unsaved changes")
        standardButtons: Dialog.Cancel | Dialog.Discard | Dialog.Apply
        anchors.centerIn: parent
        // Explicit width avoids a QtQuick.Controls implicitWidth binding loop
        // between the dialog and its standard button box.
        implicitWidth: Kirigami.Units.gridUnit * 22

        onRejected: close()
        onDiscarded: {
            answered = true;
            close();
            window.close();
        }
        onApplied: {
            Fancontrol.Base.apply();
            answered = true;
            close();
            window.close();
        }

        contentItem: Label {
            text: i18n("There are unsaved changes.\nDo you want to apply these changes?")
            wrapMode: Text.WordWrap
        }
    }
}
