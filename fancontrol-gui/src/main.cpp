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

#include <QQmlContext>
#include <QQmlApplicationEngine>
#include <QCommandLineParser>
#include <QLoggingCategory>
#include <QIcon>
#include <QWindow>
#include <QApplication>
#include <QFile>
#include <QStandardPaths>

#include <KLocalizedString>
#include <KAboutData>
#include <KDBusService>
#include <KSharedConfig>
#include <KWindowConfig>
#include <kpackage/package.h>
#include <kpackage/packageloader.h>

#include "systemtrayicon.h"


#ifndef CONFIG_NAME
#define CONFIG_NAME "fancontrol-gui"
#endif


Q_DECLARE_LOGGING_CATEGORY(FANCONTROL)
Q_LOGGING_CATEGORY(FANCONTROL, "fancontrol-gui")


static QWindow *s_window = nullptr;


void handleArguments(QStringList args)
{
    if (args.isEmpty())
        args << qApp->applicationName();

    const auto parser = new QCommandLineParser;
    KAboutData::applicationData().setupCommandLine(parser);
    parser->process(args);
    KAboutData::applicationData().processCommandLine(parser);
    delete parser;
}

void activate(const QStringList &args, const QString &workingDir)
{
    Q_UNUSED(workingDir);

    handleArguments(args);

    if (s_window)
    {
        s_window->show();
        s_window->raise();
        s_window->requestActivate();
    }
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("fancontrol_gui")));

    KLocalizedString::setApplicationDomain("kcm_fancontrol");

    auto about = KAboutData(QStringLiteral("org.kde.fancontrol.gui"),
                            i18n("Fancontrol-GUI"),
                            QStringLiteral("0.7"),
                            i18n("Graphical user interface for fancontrol"),
                            KAboutLicense::KAboutLicense::GPL_V2,
                            QStringLiteral("Copyright (C) 2015 Malte Veerman"),
                            QString(),
                            QStringLiteral("http://github.com/maldela/fancontrol-gui"),
                            QStringLiteral("http://github.com/maldela/fancontrol-gui/issues"));
    about.addAuthor(i18n("Malte Veerman"), i18n("Main Developer"), QStringLiteral("malte.veerman@gmail.com"));
    KAboutData::setApplicationData(about);

    handleArguments(app.arguments());

    // register  the app  to dbus
    KDBusService dbusService(KDBusService::Unique);
    QObject::connect(&dbusService, &KDBusService::activateRequested, qApp, activate);

    qmlRegisterType<SystemTrayIcon>("Fancontrol.Gui", 1, 0, "SystemTrayIcon");

    KPackage::Package package = KPackage::PackageLoader::self()->loadPackage(QStringLiteral("GenericQml"));
    const QString packagePath = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                                       QStringLiteral("kpackage/org.kde.fancontrol.gui"),
                                                       QStandardPaths::LocateDirectory);
    if (!packagePath.isEmpty())
        package.setPath(packagePath);

    QString mainScript = package.metadata().value(QStringLiteral("X-Plasma-MainScript"));
    if (mainScript.isEmpty())
        mainScript = QStringLiteral("ui/main.qml");

    QQmlApplicationEngine engine;
    const QString mainQmlUrl = package.filePath("contents") + QLatin1Char('/') + mainScript;
    if (QFile::exists(mainQmlUrl))
        engine.load(QUrl::fromLocalFile(mainQmlUrl));

    const auto rootObjects = engine.rootObjects();
    s_window = rootObjects.isEmpty() ? nullptr : qobject_cast<QWindow *>(rootObjects.first());
    if (s_window)
    {
        KConfigGroup configGroup(KSharedConfig::openConfig(QStringLiteral(CONFIG_NAME)), QStringLiteral("window"));
        KWindowConfig::restoreWindowSize(s_window, configGroup);
        QObject::connect(&app, &QApplication::aboutToQuit, s_window, []() {
            KConfigGroup configGroup(KSharedConfig::openConfig(QStringLiteral(CONFIG_NAME)), QStringLiteral("window"));
            KWindowConfig::saveWindowSize(s_window, configGroup);
            configGroup.sync();
        });
    }

    return app.exec();
}
