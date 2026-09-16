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

#ifndef FANCONTROLKCM_H
#define FANCONTROLKCM_H

#include <QObject>
#include <QVariantList>
#include <KPluginMetaData>
#include <kquickconfigmodule.h>


using namespace KCMUtils;

class FancontrolKCM : public KQuickConfigModule
{
    Q_OBJECT

public:

    explicit FancontrolKCM(QObject *parent, const KPluginMetaData &metaData);


public slots:

    void load() override;
    void save() override;
    void defaults() override;


signals:

    void aboutToSave();
    void aboutToLoad();
    void aboutToDefault();
};

#endif // FANCONTROLKCM_H