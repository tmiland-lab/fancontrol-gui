# fancontrol-gui

A GUI for [fancontrol](https://github.com/lm-sensors/lm-sensors), the fan-control
daemon that ships with lm-sensors. It lets you read and adjust fan speeds and
watch temperatures from a simple desktop application.

This is the **Qt 6 / KDE Frameworks 6** port (see [Status](#status)).

The app talks to the fancontrol daemon in two ways:

* It generates a fancontrol configuration file from your hardware and writes it
  through the KDE **KAuth** framework.
* It controls the `fancontrol` **systemd service** (start/stop/restart,
  apply-and-restart) through D-Bus via `systemd-communicator`.

The Qt6 build uses a dedicated systemd communicator based on systemd's D-Bus
API, so it works on modern distributions without relying on `pkexec` or the
ability to run the helper with root privileges.

## Features

* **Sensor overview** — live temperature chart (`TemperatureOverview`) and
  per-sensor values on the Sensors tab.
* **Fan control curves** — build PWM fan curves point by pointholidays on the
  Fans tabchers. Choose presets and pick a profile on the Profiles dialog.
* **Temperature alarm** — enable an alert threshold; the app shows an inline
  alarm banner and raises a desktop notification (`KNotification`) when a
  sensor exceeds the threshold, listing the offending sensor and the current
  value. Dismiss rechecks, or jump straight to settings.
* **Profiles** — save and apply named fan-control profiles.
* **Plasmoid & KCM** — optional KDE Plasma widget and system-settings module.
* **Tray integration** — tray icon, start minimized, all optional.

## Screenshots

![Sensors overview](https://user-images.githubusercontent.com/8409391/89116324-02da7400-d4bd-11ea-867c-3172edf87f2e.png)

![Fan curves](https://user-images.githubusercontent.com/8409391/89116322-f8b87600-d4bc-11ea-89e4-515121cd7d21.png)

![Fan speeds](https://user-images.githubusercontent.com/8409391/89116328-0a9a1900-d4bd-11ea-955f-f4e80c885d8b.png)

![Profiles dialog](https://user-images.githubusercontent.com/8409391/89116329-108ffa00-d4bd-11ea-990c-2c1f2ca3dc90.png)

## Status

* **2026** — ported from Qt5/KF5 to **Qt6 / KDE Frameworks 6**. Build, install
  and the bundled unit tests are verified against current KF6 on up‑to‑date
  distributions; continuous integration builds and runs the test suite on every
  push.
* Alerts (temperature alarm + desktop notification) and the temperature
  overview chart are included in this build.

## Build requirements

* Qt6: Base/Core, Widgets, Gui, QML
* KF6: I18n, Auth, Config, Package, Declarative, CoreAddons, DBusAddons,
  Extra-Cmake-Modules, Notifications
* Other: a C++ compiler, Gettext, CMake

### Additional runtime requirements

* Qt6: Quick 2.15, QuickControls2 2.15, QuickLayouts 2.15, QuickDialogs
* KF6: Kirigami2 2.14

### Additional requirements for KCM

* KF6: KCMUtils

### Additional requirements for plasmoid

* KF6: Plasma

### Debian/Ubuntu

```
sudo apt-get install ca-certificates git build-essential cmake gcc g++ \
  libkf6config-dev libkf6auth-dev libkf6package-dev libkf6declarative-dev \
  libkf6coreaddons-dev libkf6dbusaddons-dev libkf6kcmutils-dev libkf6i18n-dev \
  libkf6plasma-dev libqt6core6 libqt6widgets6 libqt6gui6 libqt6qml6 \
  extra-cmake-modules qt6-base-dev libkf6notifications-dev \
  qml6-module-org-kde-kirigami qml6-module-qtquick-dialogs \
  qml6-module-qtquick-controls qml6-module-qtquick-layouts \
  qml6-module-qt-labs-settings qml6-module-qt-labs-folderlistmodel \
  cmake build-essential gettext
```

**Note:** tested on Ubuntu 24.04 LTS and Debian 12.

### Fedora

```
sudo dnf install git gcc g++ cmake kf6-ki18n-devel kf6-kauth-devel \
  kf6-kconfig-devel kf6-kpackage-devel kf6-kcoreaddons-devel \
  kf6-kdbusaddons-devel extra-cmake-modules kf6-knotifications-devel \
  qt6-qtquickcontrols2-devel kf6-kconfigwidgets-devel kf6-kcmutils-devel \
  kf6-plasma-devel cmake gettext qt6-qtbase-devel gcc-c++ \
  kf6-kdeclarative-devel qt6-qtquickcontrols qt6-qtquickcontrols2
```

**Note:** tested on Fedora 40.

## Install

```
git clone https://github.com/tmiland/fancontrol-gui.git
cd fancontrol-gui
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_KCM=on -DBUILD_PLASMOID=on
make -j
sudo make install
```

## Build options

| Option | Default | Description |
| --- | --- | --- |
| `-DNO_SYSTEMD=true` | off | Build without systemd support. |
| `-DBUILD_KCM=on` | off | Also build the KDE Settings module. Only available when systemd support is enabled. |
| `-DBUILD_PLASMOID=on` | off | Also build the KDE Plasma plasmoid. |
| `-DINSTALL_POLKIT=true` | off | Install a polkit rules file that lets members of a group edit the config and manage the service without prompting. |
| `-DPOLKIT_GROUP_NAME=...` | `fancontrol` | Group allowed by the polkit rules file. |
| `-DSTANDARD_SERVICE_NAME=...` | standard | Name of the fancontrol service. |
| `-DSTANDARD_CONFIG_FILE=...` | standard | Path of the fancontrol config file. |
| `-DKDE_INSTALL_USE_QT_SYS_PATHS=true` | off | Use `/usr/lib/qt/qml` when your distribution places QML there instead of `/usr/lib/qml`. |

**KAuth notes:** KAuth does not currently support install prefixes other than
the one KAuth itself was installed into. To use another prefix, run the
application as root (or as a user with the required privileges) to avoid the
KAuth helper. To avoid authorizing every use of the helper, build with
`-DINSTALL_POLKIT=true`; this installs a polkit rules file allowing members of
the group `fancontrol` to edit the config file and control the service. The
group can be changed with `-DPOLKIT_GROUP_NAME`.

## Running the tests

```
cd build
ctest --output-on-failure
```

The suite (`hwmon`, `fan`, `pwmfan`, `temp` and config-loader tests) is built
when `BUILD_TESTING` is enabled (the default) and is run by CI on every push.

## Uninstall

```
cd fancontrol-gui/build
sudo make uninstall
```

## License

fancontrol-gui is released under the GNU Lesser General Public License
(version 2 or later). See `COPYING` for details.
