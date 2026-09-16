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

#include <KCoreAddons/KPluginFactory>
#include <KI18n/KLocalizedString>


#ifndef STANDARD_HELPER_ID
#define STANDARD_HELPER_ID "org.kde.fancontrol.gui.helper"
#endif


K_PLUGIN_FACTORY_WITH_JSON(FancontrolKCMFactory, "kcm_fancontrol.json", registerPlugin<FancontrolKCM>();)


FancontrolKCM::FancontrolKCM(QObject *parent, const KPluginMetaData& metaData)
    : KQuickConfigModule(parent, metaData)
{
    setButtons(Apply | Default);
    setAuthActionName(QString(STANDARD_HELPER_ID) + ".action");
}

void FancontrolKCM::save()
{
    emit aboutToSave();

    setNeedsSave(false);
}

void FancontrolKCM::load()
{
    emit aboutToLoad();

    setNeedsSave(false);
}

void FancontrolKCM::defaults()
{
    emit aboutToDefault();

    setNeedsSave(true);
}


#include "fancontrolkcm.moc"