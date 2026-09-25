/*
 * Copyright (C) 2024  Fancontrol-GUI contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License or (at your
 * option) version 3 or any later version accepted by the membership of KDE
 * e.V. (or its successor approved by the membership of KDE e.V.), which shall
 * act as a proxy defined in Section 14 of version 3 of the license.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

.pragma library

// Per-fan keys and the order they should be presented in.
var FAN_KEYS = ["FCTEMPS", "FCFANS", "MINTEMP", "MAXTEMP",
                "MINSTART", "MINSTOP", "MINPWM", "MAXPWM", "AVERAGE"];

var GLOBAL_KEYS = ["INTERVAL", "DEVPATH", "DEVNAME"];

function toNumber(value) {
    if (value === undefined || value === null || value === "")
        return undefined;
    var n = Number(value);
    return isNaN(n) ? undefined : n;
}

function splitTokens(value) {
    return String(value || "").split(/\s+/).filter(function(t) { return t.length > 0; });
}

// Parse a fancontrol configuration into:
//   globals:    { INTERVAL, DEVPATH: {hwmonN: path}, DEVNAME: {hwmonN: name} }
//   fanKeys:    { KEY: { entry: value } }
//   fans:       [ { entry, temp, fan, minTemp, ..., average } ] in file order
//   comments:   [ lines ]
function parse(text) {
    var lines = String(text || "").replace(/\r\n?/g, "\n").split("\n");
    var globals = { INTERVAL: undefined, DEVPATH: {}, DEVNAME: {} };
    var fanKeys = {};
    var entryOrder = [];
    var comments = [];

    function noteEntry(entry) {
        if (entryOrder.indexOf(entry) < 0)
            entryOrder.push(entry);
    }

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();

        if (line.length === 0)
            continue;
        if (line.charAt(0) === "#") {
            comments.push(line);
            continue;
        }

        var eq = line.indexOf("=");
        if (eq < 0)
            continue;

        var key = line.substring(0, eq).trim().toUpperCase();
        var value = line.substring(eq + 1).trim();

        if (key === "INTERVAL") {
            globals.INTERVAL = toNumber(value);
            continue;
        }

        if (key === "DEVPATH" || key === "DEVNAME") {
            var map = globals[key];
            var toks = splitTokens(value);
            for (var t = 0; t < toks.length; t++) {
                var pair = toks[t].split("=");
                if (pair.length === 2)
                    map[pair[0]] = pair[1];
            }
            continue;
        }

        if (FAN_KEYS.indexOf(key) < 0)
            continue;

        if (!fanKeys[key])
            fanKeys[key] = {};

        var tokens = splitTokens(value);
        for (var j = 0; j < tokens.length; j++) {
            var kv = tokens[j].split("=");
            if (kv.length !== 2)
                continue;
            fanKeys[key][kv[0]] = kv[1];
            noteEntry(kv[0]);
        }
    }

    function lookup(key, entry) {
        var m = fanKeys[key];
        return m ? m[entry] : undefined;
    }

    var fans = entryOrder.map(function(entry) {
        return {
            entry: entry,
            temp: lookup("FCTEMPS", entry),
            fan: lookup("FCFANS", entry),
            minTemp: toNumber(lookup("MINTEMP", entry)),
            maxTemp: toNumber(lookup("MAXTEMP", entry)),
            minStart: toNumber(lookup("MINSTART", entry)),
            minStop: toNumber(lookup("MINSTOP", entry)),
            minPwm: toNumber(lookup("MINPWM", entry)),
            maxPwm: toNumber(lookup("MAXPWM", entry)),
            average: toNumber(lookup("AVERAGE", entry))
        };
    });

    return {
        globals: globals,
        fanKeys: fanKeys,
        fans: fans,
        entryOrder: entryOrder,
        comments: comments
    };
}

// Return a list of { severity: "error"|"warning", entry, message }.
function validate(parsed) {
    var issues = [];

    function add(severity, entry, message) {
        issues.push({ severity: severity, entry: entry || "", message: message });
    }

    if (!parsed)
        return issues;

    if (parsed.fans.length === 0)
        add("warning", "", i18n("No fans are configured."));

    var g = parsed.globals;
    if (g.INTERVAL === undefined || g.INTERVAL <= 0)
        add("warning", "", i18n("INTERVAL is missing or not positive."));

    Object.keys(g.DEVPATH).forEach(function(key) {
        if (!(key in g.DEVNAME))
            add("warning", key, i18n("%1 is listed in DEVPATH but not in DEVNAME.", key));
    });
    Object.keys(g.DEVNAME).forEach(function(key) {
        if (!(key in g.DEVPATH))
            add("warning", key, i18n("%1 is listed in DEVNAME but not in DEVPATH.", key));
    });

    parsed.fans.forEach(function(f) {
        if (!f.temp)
            add("error", f.entry, i18n("No temperature source (missing FCTEMPS)."));
        if (!f.fan)
            add("error", f.entry, i18n("No fan tachometer source (missing FCFANS)."));

        if (f.minTemp === undefined || f.maxTemp === undefined)
            add("warning", f.entry, i18n("MINTEMP/MAXTEMP are not both set."));
        else if (f.minTemp >= f.maxTemp)
            add("error", f.entry, i18n("MINTEMP (%1) must be below MAXTEMP (%2).", f.minTemp, f.maxTemp));

        if (f.minStop !== undefined && f.maxPwm !== undefined && f.minStop > f.maxPwm)
            add("error", f.entry, i18n("MINSTOP (%1) must not exceed MAXPWM (%2).", f.minStop, f.maxPwm));

        if (f.minStart !== undefined && f.minStop !== undefined && f.minStart < f.minStop)
            add("warning", f.entry, i18n("MINSTART (%1) is below MINSTOP (%2).", f.minStart, f.minStop));

        if (f.minPwm !== undefined && f.maxPwm !== undefined && f.minPwm > f.maxPwm)
            add("error", f.entry, i18n("MINPWM (%1) must not exceed MAXPWM (%2).", f.minPwm, f.maxPwm));

        if (f.average !== undefined && f.average < 1)
            add("warning", f.entry, i18n("AVERAGE must be at least 1."));
    });

    return issues;
}

function compareMaps(oldMap, newMap, key, entry, out) {
    oldMap = oldMap || {};
    newMap = newMap || {};

    var keys = Object.keys(oldMap);
    Object.keys(newMap).forEach(function(k) {
        if (keys.indexOf(k) < 0)
            keys.push(k);
    });

    keys.forEach(function(e) {
        var oldValue = oldMap[e];
        var newValue = newMap[e];
        if (oldValue !== newValue)
            out.push({ key: key, entry: e, old: oldValue, new: newValue });
    });
}

// Compare two configurations, returning the per-key differences.
// Each change: { key, entry, old, new } ("old"/"new" undefined = added/removed).
function diff(oldText, newText) {
    var a = parse(oldText);
    var b = parse(newText);
    var out = [];

    if (a.globals.INTERVAL !== b.globals.INTERVAL)
        out.push({ key: "INTERVAL", entry: "", old: a.globals.INTERVAL, new: b.globals.INTERVAL });

    compareMaps(a.globals.DEVPATH, b.globals.DEVPATH, "DEVPATH", "", out);
    compareMaps(a.globals.DEVNAME, b.globals.DEVNAME, "DEVNAME", "", out);

    FAN_KEYS.forEach(function(key) {
        compareMaps(a.fanKeys[key], b.fanKeys[key], key, "", out);
    });

    return out;
}
