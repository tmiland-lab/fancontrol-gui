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

#ifndef SYSTEMTRAYICON_H
#define SYSTEMTRAYICON_H

#include <KStatusNotifierItem>

#include <QStringListModel>
#include <QMenu>


class SystemTrayIcon : public KStatusNotifierItem
{
    Q_OBJECT
    Q_PROPERTY(QStringListModel* profileModel READ profileModel WRITE setProfileModel NOTIFY profileModelChanged)
    Q_PROPERTY(QString tooltipSummary READ tooltipSummary WRITE setTooltipSummary NOTIFY tooltipSummaryChanged)

public:

    SystemTrayIcon(QObject *parent = nullptr);

    QStringListModel *profileModel() const { return m_profileModel; }
    void setProfileModel(QStringListModel *model);
    void setProfiles(const QStringList &profiles);
    QString tooltipSummary() const { return m_tooltipSummary; }
    void setTooltipSummary(const QString &summary);


Q_SIGNALS:
    void activateProfile(QString profile);
    void activateService(bool active);
    void enableService(bool enabled);
    void profileModelChanged();
    void tooltipSummaryChanged();


private:

    QStringListModel *m_profileModel;
    QMenu *m_profilesMenu;
    QMenu *m_serviceMenu;
    QString m_tooltipSummary;
    bool m_serviceActive = true;
    bool m_serviceEnabled = true;
};

#endif // SYSTEMTRAYICON_H
