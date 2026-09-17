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
#include <QMetaType>
#include <QVariantList>

#include <KLocalizedString>
#include <KAboutData>
#include <KConfigGroup>
#include <KDBusService>
#include <KSharedConfig>
#include <KWindowConfig>

#include "systemtrayicon.h"


class I18nBridge : public QObject
{
    Q_OBJECT

public:
    Q_INVOKABLE QString i18n(const QString &text, const QVariantList &args) const
    {
        const QByteArray textUtf8 = text.toUtf8();
        KLocalizedString localized = ki18n(textUtf8.constData());
        return finalize(localized, args);
    }

    Q_INVOKABLE QString i18nc(const QString &context, const QString &text, const QVariantList &args) const
    {
        const QByteArray contextUtf8 = context.toUtf8();
        const QByteArray textUtf8 = text.toUtf8();
        KLocalizedString localized = ki18nc(contextUtf8.constData(), textUtf8.constData());
        return finalize(localized, args);
    }

    Q_INVOKABLE QString i18np(const QString &singular, const QString &plural, const QVariantList &args) const
    {
        if (args.isEmpty())
            return plural;

        const QByteArray singularUtf8 = singular.toUtf8();
        const QByteArray pluralUtf8 = plural.toUtf8();
        KLocalizedString localized = ki18np(singularUtf8.constData(), pluralUtf8.constData());
        localized = localized.subs(args.first().toInt());
        QVariantList remaining = args.mid(1);
        return finalize(localized, remaining);
    }

    Q_INVOKABLE QString i18ncp(const QString &context, const QString &singular, const QString &plural, const QVariantList &args) const
    {
        if (args.isEmpty())
            return plural;

        const QByteArray contextUtf8 = context.toUtf8();
        const QByteArray singularUtf8 = singular.toUtf8();
        const QByteArray pluralUtf8 = plural.toUtf8();
        KLocalizedString localized = ki18ncp(contextUtf8.constData(), singularUtf8.constData(), pluralUtf8.constData());
        localized = localized.subs(args.first().toInt());
        QVariantList remaining = args.mid(1);
        return finalize(localized, remaining);
    }

private:
    static QString finalize(KLocalizedString localized, const QVariantList &args)
    {
        for (const auto &arg : args)
        {
            switch (arg.typeId())
            {
            case QMetaType::Int:
            case QMetaType::UInt:
            case QMetaType::LongLong:
            case QMetaType::ULongLong:
            case QMetaType::Short:
            case QMetaType::UShort:
            case QMetaType::Char:
            case QMetaType::UChar:
            case QMetaType::Bool:
                localized = localized.subs(arg.toInt());
                break;
            case QMetaType::Double:
            case QMetaType::Float:
                localized = localized.subs(arg.toDouble());
                break;
            default:
                localized = localized.subs(arg.toString());
                break;
            }
        }
        return localized.toString();
    }
};


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

    QString packagePath = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                                 QStringLiteral("kpackage/genericqml/org.kde.fancontrol.gui"),
                                                 QStandardPaths::LocateDirectory);
    if (packagePath.isEmpty())
        packagePath = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                             QStringLiteral("kpackage/org.kde.fancontrol.gui"),
                                             QStandardPaths::LocateDirectory);

    QString mainScript = QStringLiteral("ui/Application.qml");
    const QString metadataPath = packagePath + QStringLiteral("/metadata.desktop");
    if (QFile::exists(metadataPath))
    {
        const KConfigGroup metadata(KSharedConfig::openConfig(metadataPath, KConfig::SimpleConfig),
                                    QStringLiteral("Desktop Entry"));
        mainScript = metadata.readEntry(QStringLiteral("X-Plasma-MainScript"), mainScript);
    }

    QQmlApplicationEngine engine;
    I18nBridge i18nBridge;
    engine.globalObject().setProperty(QStringLiteral("_i18nBridge"), engine.newQObject(&i18nBridge));
    engine.evaluate(QStringLiteral(
        "function i18n(text) {"
        "    return _i18nBridge.i18n(text, Array.prototype.slice.call(arguments, 1));"
        "}"
        "function i18nc(context, text) {"
        "    return _i18nBridge.i18nc(context, text, Array.prototype.slice.call(arguments, 2));"
        "}"
        "function i18np(singular, plural) {"
        "    return _i18nBridge.i18np(singular, plural, Array.prototype.slice.call(arguments, 2));"
        "}"
        "function i18ncp(context, singular, plural) {"
        "    return _i18nBridge.i18ncp(context, singular, plural, Array.prototype.slice.call(arguments, 3));"
        "}"));

    const QString mainQmlUrl = packagePath + QStringLiteral("/contents/") + mainScript;
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

#include "main.moc"
