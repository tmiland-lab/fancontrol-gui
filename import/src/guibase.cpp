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


#include "guibase.h"

#include "config.h"
#include "hwmon.h"
#include "temp.h"

#include <KLocalizedString>
#include <KNotification>
#include <QDebug>
#include <QLocale>


namespace Fancontrol
{

GUIBase::GUIBase(QObject *parent) : QObject(parent),

#ifndef NO_SYSTEMD
    m_com(new SystemdCommunicator(this)),
#endif

    m_loader(new Loader(this)),
    m_configValid(false),
    m_pwmFanModel(new PwmFanModel(this)),
    m_tempModel(new TempModel(this)),
    m_profileModel(new QStringListModel(this)),
    m_highestTemp(-273.0),
    m_temperatureAlarm(false)
{
    connect(m_loader, &Loader::needsSaveChanged, this, &GUIBase::needsApplyChanged);
    connect(m_loader, &Loader::configChanged, this, &GUIBase::currentProfileChanged);

#ifndef NO_SYSTEMD
    connect(m_loader, &Loader::requestSetServiceActive, m_com, &SystemdCommunicator::setServiceActive);
    connect(m_com, &SystemdCommunicator::needsApplyChanged, this, &GUIBase::needsApplyChanged);
#endif

    m_alertTimer.setInterval(5000);
    connect(&m_alertTimer, &QTimer::timeout, this, &GUIBase::checkTemperatures);

    m_loader->parseHwmons();

    const auto hwmons = m_loader->hwmons();
    for (const auto &hwmon : hwmons)
    {
        m_pwmFanModel->addPwmFans(hwmon->pwmFans().values());
        m_tempModel->addTemps(hwmon->temps().values());
    }

    m_alertTimer.start();
}

GUIBase::~GUIBase()
{
    Config::instance()->save();
}

void GUIBase::load()
{
    Config::instance()->load();

    // Check profiles
    auto profiles = Config::instance()->findItem(QStringLiteral("Profiles"))->property().toStringList();
    auto profileNames = Config::instance()->findItem(QStringLiteral("ProfileNames"))->property().toStringList();

    while (profiles.size() > profileNames.size())
        profiles.removeLast();

    while (profiles.size() < profileNames.size())
        profileNames.removeLast();

    Config::instance()->findItem(QStringLiteral("Profiles"))->setProperty(profiles);
    Config::instance()->findItem(QStringLiteral("ProfileNames"))->setProperty(profileNames);

    m_profileModel->setStringList(profileNames);

    m_configValid = m_loader->load(configUrl());

#ifndef NO_SYSTEMD
    m_com->setServiceName(serviceName());
    m_com->reset();
#endif

    Q_EMIT currentProfileChanged();
    Q_EMIT serviceNameChanged();
    Q_EMIT minTempChanged();
    Q_EMIT maxTempChanged();
    Q_EMIT configUrlChanged();
    Q_EMIT alertEnabledChanged();
    Q_EMIT alertThresholdChanged();
}

qreal GUIBase::maxTemp() const
{
    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    return Config::instance()->findItem(QStringLiteral("MaxTemp"))->property().toReal();
}

qreal GUIBase::minTemp() const
{
    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    return Config::instance()->findItem(QStringLiteral("MinTemp"))->property().toReal();
}

QString GUIBase::serviceName() const
{
    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    return Config::instance()->findItem(QStringLiteral("ServiceName"))->property().toString();
}

QUrl GUIBase::configUrl() const
{
    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    return QUrl(Config::instance()->findItem(QStringLiteral("ConfigUrl"))->property().toString());
}

bool GUIBase::showTray() const
{
    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    return Config::instance()->findItem(QStringLiteral("ShowTray"))->property().toBool();
}

bool GUIBase::startMinimized() const
{
    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    return Config::instance()->findItem(QStringLiteral("StartMinimized"))->property().toBool();
}

void GUIBase::setMaxTemp(qreal temp)
{
    if (temp != maxTemp())
    {
        Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
        Config::instance()->findItem(QStringLiteral("MaxTemp"))->setProperty(temp);
        Q_EMIT maxTempChanged();
    }
}

void GUIBase::setMinTemp(qreal temp)
{
    if (temp != minTemp())
    {
        Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
        Config::instance()->findItem(QStringLiteral("MinTemp"))->setProperty(temp);
        Q_EMIT minTempChanged();
    }
}

void GUIBase::setServiceName(const QString& name)
{
    if (name != serviceName())
    {
        Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
        Config::instance()->findItem(QStringLiteral("ServiceName"))->setProperty(name);

#ifndef NO_SYSTEMD
        m_com->setServiceName(name);
#endif

        Q_EMIT serviceNameChanged();
    }
}

void GUIBase::setConfigUrl(const QUrl &url)
{
    if (url != configUrl())
    {
        m_configValid = m_loader->load(url);

        Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
        Config::instance()->findItem(QStringLiteral("ConfigUrl"))->setProperty(url.toString());
        Q_EMIT configUrlChanged();
    }
}

void GUIBase::setShowTray(bool show)
{
    if (showTray() == show)
        return;

    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    Config::instance()->findItem(QStringLiteral("ShowTray"))->setProperty(show);
    Q_EMIT showTrayChanged();
}

void GUIBase::setStartMinimized(bool sm)
{
    if (startMinimized() == sm)
        return;

    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    Config::instance()->findItem(QStringLiteral("StartMinimized"))->setProperty(sm);
    Q_EMIT startMinimizedChanged();
}

bool GUIBase::alertEnabled() const
{
    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    return Config::instance()->findItem(QStringLiteral("AlertEnabled"))->property().toBool();
}

void GUIBase::setAlertEnabled(bool enabled)
{
    if (alertEnabled() == enabled)
        return;

    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    Config::instance()->findItem(QStringLiteral("AlertEnabled"))->setProperty(enabled);
    Q_EMIT alertEnabledChanged();
}

double GUIBase::alertThreshold() const
{
    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    return Config::instance()->findItem(QStringLiteral("AlertThreshold"))->property().toDouble();
}

void GUIBase::setAlertThreshold(double threshold)
{
    if (qFuzzyCompare(alertThreshold(), threshold))
        return;

    Config::instance()->setCurrentGroup(QStringLiteral("preferences"));
    Config::instance()->findItem(QStringLiteral("AlertThreshold"))->setProperty(threshold);
    Q_EMIT alertThresholdChanged();
}

void GUIBase::checkTemperatures()
{
    double highest = -273.0;
    QString sensor;

    const auto hwmons = m_loader->hwmons();
    for (const auto &hwmon : hwmons)
    {
        const auto temps = hwmon->temps().values();
        for (const auto &temp : temps)
        {
            if (!temp)
                continue;

            const auto value = static_cast<double>(temp->value());
            if (value > highest)
            {
                highest = value;
                sensor = temp->label();
            }
        }
    }

    if (!qFuzzyCompare(highest, m_highestTemp))
    {
        m_highestTemp = highest;
        Q_EMIT highestTempChanged();
    }

    const bool alarm = alertEnabled() && highest >= alertThreshold();
    if (alarm != m_temperatureAlarm)
    {
        m_temperatureAlarm = alarm;
        m_alarmSensor = sensor;
        Q_EMIT temperatureAlarmChanged();

        if (alarm)
        {
            auto notification = new KNotification(QStringLiteral("fancontrol-temperature-alarm"), KNotification::CloseOnTimeout, this);
            notification->setTitle(i18n("Temperature alarm"));
            notification->setText(i18n("%1 has reached %2°C, which is above the alert threshold of %3°C.", sensor, qRound(highest), qRound(alertThreshold())));
            notification->setUrgency(KNotification::CriticalUrgency);
            notification->setIconName(QStringLiteral("dialog-warning"));
            notification->sendEvent();
        }
    }
}

void GUIBase::applyAndRestart()
{
    apply();

#ifndef NO_SYSTEMD
    m_com->restartService();
#endif
}

bool GUIBase::needsApply() const
{
#ifndef NO_SYSTEMD
    return m_loader->needsSave() || m_com->needsApply();
#else
    return m_loader->needsSave();
#endif
}

bool GUIBase::hasSystemdCommunicator() const
{
#ifndef NO_SYSTEMD
    return true;
#else
    return false;
#endif
}

void GUIBase::apply()
{
    qInfo() << i18n("Applying changes");

    bool configChanged = m_loader->save(configUrl());

#ifndef NO_SYSTEMD
    m_com->apply(configChanged);
#endif

    Q_EMIT needsApplyChanged();
}

void GUIBase::reset()
{
    qInfo() << i18n("Resetting changes");

    m_loader->reset();

#ifndef NO_SYSTEMD
    m_com->setServiceName(serviceName());
    m_com->reset();
#endif

    Q_EMIT needsApplyChanged();
}

void GUIBase::handleError(const QString &error, bool critical)
{
    if (error.isEmpty())
        return;

    m_error = error;
    Q_EMIT errorChanged();

    if (critical)
    {
        qCritical() << error;
        Q_EMIT criticalError();
    }
    else
        qWarning() << error;
}

void GUIBase::handleInfo(const QString &info)
{
    if (info.isEmpty())
        return;

    else
        qInfo() << info;
}

void GUIBase::applyProfile(const QString& profileName)
{
    if (!Config::instance()->findItem(QStringLiteral("ProfileNames"))->property().toStringList().contains(profileName))
    {
        handleError(i18n("Unable to apply unknown profile: %1", profileName));
        return;
    }

    int index = Config::instance()->findItem(QStringLiteral("ProfileNames"))->property().toStringList().indexOf(profileName);

    applyProfile(index);
}

void GUIBase::applyProfile(int index)
{
    auto profileNames = Config::instance()->findItem(QStringLiteral("ProfileNames"))->property().toStringList();

    if (index < 0 || index >= profileNames.size())
    {
        handleError(i18n("Profile with index %1 not found.", index));
        return;
    }

    auto newConfig = Config::instance()->findItem(QStringLiteral("Profiles"))->property().toStringList().value(index);

    if (newConfig.isEmpty())
    {
        handleError(i18n("Unable to read data for profile: %1", index));
        profileNames.removeAt(index);
        Config::instance()->findItem(QStringLiteral("ProfileNames"))->setProperty(profileNames);
        return;
    }

    if (m_loader->config() == newConfig)
        return;

    m_loader->load(newConfig);
}

void GUIBase::saveProfile(const QString& profileName, bool updateModel)
{
    auto profileNames = Config::instance()->findItem(QStringLiteral("ProfileNames"))->property().toStringList();
    int index = profileNames.indexOf(profileName);

    if (index < 0)
    {
        index = profileNames.size();

        auto profileNames = Config::instance()->findItem(QStringLiteral("ProfileNames"))->property().toStringList();
        Config::instance()->findItem(QStringLiteral("ProfileNames"))->setProperty(profileNames << profileName);

        if (updateModel)
            m_profileModel->insertRow(index);
    }

    auto profiles = Config::instance()->findItem(QStringLiteral("Profiles"))->property().toStringList();
    profiles.insert(index, m_loader->config());
    Config::instance()->findItem(QStringLiteral("Profiles"))->setProperty(profiles);

    Q_EMIT currentProfileChanged();

    if (updateModel)
        m_profileModel->setData(m_profileModel->index(index, 0), profileName);
}

void GUIBase::deleteProfile(const QString& profileName, bool updateModel)
{
    int index = Config::instance()->findItem(QStringLiteral("ProfileNames"))->property().toStringList().indexOf(profileName);

    deleteProfile(index, updateModel);
}

void GUIBase::deleteProfile(int index, bool updateModel)
{
    auto profileNames = Config::instance()->findItem(QStringLiteral("ProfileNames"))->property().toStringList();
    auto profiles = Config::instance()->findItem(QStringLiteral("Profiles"))->property().toStringList();

    if (index < 0 || index >= profileNames.size() || index >= profiles.size())
        return;

    profileNames.removeAt(index);
    Config::instance()->findItem(QStringLiteral("ProfileNames"))->setProperty(profileNames);
    profiles.removeAt(index);
    Config::instance()->findItem(QStringLiteral("Profiles"))->setProperty(profiles);

    Q_EMIT currentProfileChanged();

    if (updateModel)
        m_profileModel->removeRow(index);
}

QString GUIBase::currentProfile() const
{
    const int index = currentProfileIndex();

    if (index == -1)
        return i18n("No profile");

    const auto profileNames = Config::instance()->findItem(QStringLiteral("ProfileNames"))->property().toStringList();
    return profileNames.value(index);
}

int GUIBase::currentProfileIndex() const
{
    const auto profiles = Config::instance()->findItem(QStringLiteral("Profiles"))->property().toStringList();
    return profiles.indexOf(m_loader->config());
}

}
