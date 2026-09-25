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
#include <QPalette>
#include <QProcess>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QStyle>
#include <QStyleHints>
#include <QTimer>
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


static bool isKdeSession()
{
    const QByteArray desktop = qgetenv("XDG_CURRENT_DESKTOP").toUpper();
    return desktop.contains("KDE") || desktop.contains("PLASMA");
}

// Determine whether the system is currently using a dark colour scheme.
//
// On Plasma the Qt platform theme reports this accurately, so the style hint
// is trusted. On GNOME (and other GTK desktops) Qt often reports "Light"
// regardless of the user's preference, which lives in gsettings, so that is
// consulted instead. FANCONTROL_COLOR_SCHEME=dark|light always wins.
static Qt::ColorScheme detectColorScheme()
{
    const QByteArray override = qgetenv("FANCONTROL_COLOR_SCHEME").trimmed().toLower();
    if (override == "dark")
        return Qt::ColorScheme::Dark;
    if (override == "light")
        return Qt::ColorScheme::Light;

    const Qt::ColorScheme hint = QGuiApplication::styleHints()->colorScheme();

    if (isKdeSession())
        return hint;

    QProcess gsettings;
    gsettings.start(QStringLiteral("gsettings"),
                    {QStringLiteral("get"),
                     QStringLiteral("org.gnome.desktop.interface"),
                     QStringLiteral("color-scheme")});
    if (gsettings.waitForFinished(500))
    {
        const QString out = QString::fromUtf8(gsettings.readAllStandardOutput());
        if (out.contains(QStringLiteral("prefer-dark"), Qt::CaseInsensitive))
            return Qt::ColorScheme::Dark;
        if (out.contains(QStringLiteral("prefer-light"), Qt::CaseInsensitive))
            return Qt::ColorScheme::Light;
    }

    return hint;
}

static QPalette s_lightPalette;

static QPalette darkPalette()
{
    // Breeze Dark inspired palette. Needed because palette-driven QML styles
    // (e.g. Fusion on GNOME) read the application palette, not the KDE one.
    const QColor window(35, 38, 41);
    const QColor alternate(49, 54, 59);
    const QColor text(239, 240, 241);
    const QColor disabled(127, 140, 141);
    const QColor highlight(61, 174, 233);

    QPalette pal = s_lightPalette;
    pal.setColor(QPalette::Window, window);
    pal.setColor(QPalette::WindowText, text);
    pal.setColor(QPalette::Base, window);
    pal.setColor(QPalette::AlternateBase, alternate);
    pal.setColor(QPalette::ToolTipBase, alternate);
    pal.setColor(QPalette::ToolTipText, text);
    pal.setColor(QPalette::Text, text);
    pal.setColor(QPalette::PlaceholderText, disabled);
    pal.setColor(QPalette::Button, alternate);
    pal.setColor(QPalette::ButtonText, text);
    pal.setColor(QPalette::BrightText, Qt::red);
    pal.setColor(QPalette::Link, highlight);
    pal.setColor(QPalette::Highlight, highlight);
    pal.setColor(QPalette::HighlightedText, Qt::black);

    pal.setColor(QPalette::Disabled, QPalette::Text, disabled);
    pal.setColor(QPalette::Disabled, QPalette::WindowText, disabled);
    pal.setColor(QPalette::Disabled, QPalette::ButtonText, disabled);

    return pal;
}

static void applyPalette(QApplication &app, bool dark)
{
    const QPalette pal = dark ? darkPalette() : s_lightPalette;
    app.setPalette(pal);
}

// Watches the system colour scheme and re-applies it while the app is running,
// so toggling dark/light in the desktop settings updates the window body and
// not just the compositor-drawn title bar.
class ThemeWatcher : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool dark READ dark NOTIFY darkChanged)

public:
    explicit ThemeWatcher(QObject *parent = nullptr) : QObject(parent)
    {
        m_dark = detectColorScheme() == Qt::ColorScheme::Dark;
        applyCurrent();
        connect(&m_timer, &QTimer::timeout, this, &ThemeWatcher::refresh);
        m_timer.setInterval(1500);
        m_timer.start();
        connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged,
                this, &ThemeWatcher::refresh);
    }

    bool dark() const { return m_dark; }

    void refresh()
    {
        const bool dark = detectColorScheme() == Qt::ColorScheme::Dark;
        const bool changed = (dark != m_dark);
        m_dark = dark;
        // Re-assert every time: the platform theme (e.g. GTK) can overwrite the
        // application palette during startup and on theme reloads.
        applyCurrent();
        if (changed)
            Q_EMIT darkChanged();
    }

Q_SIGNALS:
    void darkChanged();

private:
    void applyCurrent()
    {
        if (auto *app = qobject_cast<QApplication *>(qApp))
            applyPalette(*app, m_dark);
    }

    bool m_dark = false;
    QTimer m_timer;
};


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

    // Remember the platform's light palette so we can restore it when the
    // system switches back to a light colour scheme at runtime.
    s_lightPalette = app.style()->standardPalette();

    // Follow the system light/dark preference. On Plasma the Breeze QML style
    // tracks the KDE colour scheme automatically; elsewhere the palette-driven
    // default style is used together with the detected palette.
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE") && isKdeSession())
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));

    app.setDesktopFileName(QStringLiteral("org.kde.fancontrol.gui"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("org.kde.fancontrol.gui")));

    KLocalizedString::setApplicationDomain("kcm_fancontrol");

    auto about = KAboutData(QStringLiteral("org.kde.fancontrol.gui"),
                            i18n("Fancontrol-GUI"),
                            QStringLiteral("1.0.0"),
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

    // Applies the current system palette and keeps it in sync at runtime.
    // Also exposed to QML as `_theme` so the ApplicationWindow can mirror the
    // scheme onto its own controls palette.
    ThemeWatcher themeWatcher;
    engine.globalObject().setProperty(QStringLiteral("_theme"), engine.newQObject(&themeWatcher));
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

    // Qt/KDE initialisation above may have replaced the palette; make sure the
    // detected colour scheme is applied to the freshly created window.
    themeWatcher.refresh();

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
