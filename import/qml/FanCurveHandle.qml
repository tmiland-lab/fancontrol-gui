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
import org.kde.kirigami 2.14 as Kirigami
import Fancontrol.Qml 1.0 as Fancontrol

// A draggable point on the combined fan curve graph. Position is derived
// purely from the graph's curvePoints model, so dragging (which writes the
// model through FanCurveGraph.applyPoint) always leaves the canvas, the
// model and the handle in sync.
Rectangle {
    id: root

    // The graphBackground that provides scaleX/scaleY/scaleTemp/scalePwm.
    property Item background: parent
    // The FanCurveGraph that owns the curvePoints model.
    property var graph
    // Index into graph.curvePoints ("stop" ..., "max").
    property int pointIndex: 0
    // "stop" | "waypoint" | "max"
    property string kind: "waypoint"
    // Reuse the graph's anchor colours so the two stay coherent.
    readonly property color edgeColor: !!graph && kind === "stop" ? graph.coolColor
                                     : !!graph && kind === "max" ? graph.warmColor
                                     : Kirigami.Theme.highlightColor

    property bool editable: false
    property int size: Kirigami.Units.smallSpacing * 2

    readonly property real centerX: x + width / 2
    readonly property real centerY: y + height / 2
    readonly property point center: Qt.point(centerX, centerY)

    x: !!background && !!graph ? background.scaleX(graph.pointTemp(pointIndex)) - width / 2 : -width / 2
    y: !!background && !!graph ? background.scaleY(graph.pointPwm(pointIndex)) - height / 2 : -height / 2

    width: size
    height: size
    radius: size / 2
    color: Qt.tint(edgeColor, Qt.rgba(edgeColor.r, edgeColor.g, edgeColor.b, 0.35))
    border.width: mouseArea.containsMouse || mouseArea.drag.active ? 2 : 1
    border.color: Qt.rgba(edgeColor.r, edgeColor.g, edgeColor.b, 0.9)

    Behavior on x { enabled: !root.dragging; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !root.dragging; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    property bool dragging: false

    // Painted above the curve/temp canvases so the draggable plots are never
    // occluded by the temp-history or the curve polygon layers.
    z: 990
    visible: !!background && !!graph

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        enabled: root.editable
        hoverEnabled: root.enabled
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onPressed: {
            root.dragging = true
        }

        onPositionChanged: {
            if (!pressed || !root.graph)
                return;

            var p = root.mapToItem(root.background, mouse.x, mouse.y);
            root.graph.applyPoint(root.pointIndex, root.background.scaleTemp(p.x), root.background.scalePwm(p.y));
        }

        onReleased: {
            root.dragging = false
            if (root.graph)
                root.graph.finishPoint(root.pointIndex);
        }
    }

    Rectangle {
        id: tooltip

        parent: root.parent
        x: Math.min(root.width + root.x, background.width - width + background.anchors.rightMargin)
        y: Math.max(root.y - height, -background.anchors.topMargin)
        z: 2
        width: column.width
        height: column.height
        radius: Kirigami.Units.smallSpacing / 2
        color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.3)
        visible: root.enabled && mouseArea.containsMouse

        Column {
            id: column

            padding: Kirigami.Units.smallSpacing

            Text {
                font.pixelSize: root.size * 1.4
                text: !!root.graph ? Number(root.graph.pointTemp(root.pointIndex)).toLocaleString(Qt.locale(), 'f', 0) + i18n("°C") : ""
                color: Kirigami.Theme.textColor
            }
            Text {
                font.pixelSize: root.size * 1.4
                text: !!root.graph ? Number(root.graph.pointPwm(root.pointIndex) / 2.55).toLocaleString(Qt.locale(), 'f', 1) + Qt.locale().percent : ""
                color: Kirigami.Theme.textColor
            }
        }
    }
}