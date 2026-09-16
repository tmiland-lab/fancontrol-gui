/*
 * Copyright 2015  Malte Veerman <malte.veerman@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License or (at your option) version 3 or any later version
 * accepted by the membership of KDE e.V. (or its successor approved
 * by the membership of KDE e.V.), which shall act as a proxy
 * defined in Section 14 of version 3 of the license.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "fancontrolkcm.h"

#include <KPluginFactory>
#include <KLocalizedString>


#ifndef STANDARD_HELPER_ID
#define STANDARD_HELPER_ID "org.kde.fancontrol.gui.helper"
#endif


K_PLUGIN_CLASS_WITH_JSON(FancontrolKCM, "kcm_fancontrol.json")


FancontrolKCM::FancontrolKCM(QObject *parent, const KPluginMetaData& metaData)
    : KQuickConfigModule(parent, metaData)
{
    setButtons(Apply | Default);
    setAuthActionName(QStringLiteral(STANDARD_HELPER_ID) + QStringLiteral(".action"));
}

void FancontrolKCM::save()
{
    Q_EMIT aboutToSave();

    setNeedsSave(false);
}

void FancontrolKCM::load()
{
    Q_EMIT aboutToLoad();

    setNeedsSave(false);
}

void FancontrolKCM::defaults()
{
    Q_EMIT aboutToDefault();

    setNeedsSave(true);
}


#include "fancontrolkcm.moc"