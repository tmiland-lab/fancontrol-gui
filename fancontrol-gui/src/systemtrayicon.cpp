/*
 * Copyright 2018  Malte Veerman <malte.veerman@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as
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
 */

#include "systemtrayicon.h"

#include <KI18n/KLocalizedString>

#include <QMenu>

SystemTrayIcon::SystemTrayIcon(QObject *parent) : KStatusNotifierItem(QStringLiteral("fancontrold.gui"), parent)
    , m_profileModel(nullptr)
    , m_tooltipSummary()
{
    setCategory(KStatusNotifierItem::ApplicationStatus);

    m_profilesMenu = contextMenu()->addMenu(i18n("Apply profile"));

    //Service control submenu
    m_serviceMenu = contextMenu()->addMenu(i18n("Service"));
    auto startStopAction = m_serviceMenu->addAction(i18n("Start/Stop service"));
    connect(startStopAction, &QAction::triggered, this, [this]() {
        emit activateService(!m_serviceActive);
    });
    m_serviceActive = true;

    auto enableDisableAction = m_serviceMenu->addAction(i18n("Enable/Disable autostart"));
    connect(enableDisableAction, &QAction::triggered, this, [this]() {
        emit enableService(!m_serviceEnabled);
    });
    m_serviceEnabled = true;
}

void SystemTrayIcon::setProfileModel(QStringListModel* model)
{
    if (m_profileModel == model)
        return;

    m_profileModel = model;
    emit profileModelChanged();

    if (!m_profileModel)
    {
        setProfiles(QStringList());
        return;
    }

    setProfiles(m_profileModel->stringList());

    connect(m_profileModel, &QStringListModel::dataChanged, this, [this]() { setProfiles(m_profileModel->stringList()); });
    connect(m_profileModel, &QStringListModel::rowsInserted, this, [this]() { setProfiles(m_profileModel->stringList()); });
    connect(m_profileModel, &QStringListModel::rowsRemoved, this, [this]() { setProfiles(m_profileModel->stringList()); });
    connect(m_profileModel, &QStringListModel::modelReset, this, [this]() { setProfiles(m_profileModel->stringList()); });
}

void SystemTrayIcon::setProfiles(const QStringList& profiles)
{
    m_profilesMenu->clear();

    for (const auto &profile : profiles)
    {
        const auto action = m_profilesMenu->addAction(profile);
        connect(action, &QAction::triggered, this, [this, profile]() { emit activateProfile(profile); });
    }
}

void SystemTrayIcon::setTooltipSummary(const QString &summary)
{
    if (m_tooltipSummary == summary)
        return;

    m_tooltipSummary = summary;
    setTitle(summary);
    emit tooltipSummaryChanged();
}
