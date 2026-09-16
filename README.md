# fancontrol-gui
GUI for fancontrol which is part of lm_sensors <link>https://github.com/lm-sensors/lm-sensors</link>.
It uses the KAuth module of the KDE Frameworks 6 to write the generated config file.
Furthermore it communicates with systemd via dbus to control the fancontrol service.

KAuth currently doesn't support install prefixes other than where KAuth itself was installed.
If you want to use another install prefix, you have to run the application as root or another user with the necessary privileges to avoid the KAuth helper.
If you want to avoid authorizing yourself when using the helper you can set the option -DINSTALL_POLKIT=true. This will install a polkit rules file allowing members of the group 'fancontrol' to edit the config file and manipulate the systemd service. You can change the group name with the -DPOLKIT_GROUP_NAME option. Service name and config file can be set with the options -DSTANDARD_SERVICE_NAME and -DSTANDARD_CONFIG_FILE.

If you want to compile without systemd support set the option -DNO_SYSTEMD=true.

If your distro looks for QML plugins in /usr/lib/qt/qml instead of /usr/lib/qml you need to set the option -DKDE_INSTALL_USE_QT_SYS_PATHS=true.

To compile the additional KCM set the cmake option -DBUILD_KCM=on.
The KCM is only build, if the -DNO_SYSTEMD option is unset or set to false.

To compile the additional KDE Plasma plasmoid set the cmake option -DBUILD_PLASMOID=on.

# Screenshots

![image](https://user-images.githubusercontent.com/8409391/89116324-02da7480-d4bd-11ea-867c-3172edf87f2e.png)

![image](https://user-images.githubusercontent.com/8409391/89116322-f8b87600-d4bc-11ea-89e4-515121cd7d71.png)

![image](https://user-images.githubusercontent.com/8409391/89116328-0a9a1900-d4bd-11ea-955f-f4e80c885d8b.png)

![image](https://user-images.githubusercontent.com/8409391/89116329-108ffa00-d4bd-11ea-990c-2c1f2ca3dc90.png)

# Build requirements
* Qt6: Base/Core, Widgets, Gui, QML
* KF6: I18n, Auth, Config, Package, Declarative, CoreAddons, DBusAddons, Extra-Cmake-Modules, Notifications
* Other: C++ compiler, Gettext, CMake

## Additional runtime requirements
* Qt6: Quick 2.15, QuickControls2 2.15, QuickLayouts 2.15, QuickDialogs
* KF6: Kirigami2 2.14

## Additional requirements for KCM
* KF6: KCMUtils

## Additional requirements for plasmoid
* KF6: Plasma

## Commands to install requirements
### Debian/Ubuntu command to install the build requirements:
```
sudo apt-get install ca-certificates git build-essential cmake gcc g++ libkf6config-dev libkf6auth-dev libkf6package-dev libkf6declarative-dev libkf6coreaddons-dev libkf6dbusaddons-dev libkf6kcmutils-dev libkf6i18n-dev libkf6plasma-dev libqt6core6 libqt6widgets6 libqt6gui6 libqt6qml6 extra-cmake-modules qt6-base-dev libkf6notifications-dev qml6-module-org-kde-kirigami qml6-module-qtquick-dialogs qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qt-labs-settings qml6-module-qt-labs-folderlistmodel cmake build-essential gettext
```
**Note:** This was tested on `Ubuntu 24.04 LTS` and `Debian 12`.

### Fedora:
```
sudo dnf install git gcc g++ cmake kf6-ki18n-devel kf6-kauth-devel kf6-kconfig-devel kf6-kpackage-devel kf6-kcoreaddons-devel kf6-kdbusaddons-devel extra-cmake-modules kf6-knotifications-devel qt6-qtquickcontrols2-devel kf6-kconfigwidgets-devel kf6-kcmutils-devel kf6-plasma-devel cmake gettext qt6-qtbase-devel gcc-c++ kf6-kdeclarative-devel qt6-qtquickcontrols qt6-qtquickcontrols2
```
**Note:** This was tested on `Fedora 40`.

# Install:

```
git clone https://github.com/tmiland/fancontrol-gui.git
cd fancontrol-gui
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_KCM=on -DBUILD_PLASMOID=on
make -j
sudo make install
```

# Uninstall:

```
cd fancontrol-gui/build
sudo make uninstall
```