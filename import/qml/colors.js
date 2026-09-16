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


function setAlpha(color, alpha) {
    return Qt.rgba(color.r, color.g, color.b, alpha);
}

function palette(index) {
    var colors = [
        Qt.rgba(0.20, 0.45, 0.95, 1.0),
        Qt.rgba(0.91, 0.34, 0.20, 1.0),
        Qt.rgba(0.13, 0.63, 0.39, 1.0),
        Qt.rgba(0.85, 0.60, 0.11, 1.0),
        Qt.rgba(0.48, 0.33, 0.85, 1.0),
        Qt.rgba(0.17, 0.65, 0.68, 1.0),
        Qt.rgba(0.78, 0.33, 0.66, 1.0),
        Qt.rgba(0.62, 0.53, 0.21, 1.0)
    ];
    return colors[index % colors.length];
}