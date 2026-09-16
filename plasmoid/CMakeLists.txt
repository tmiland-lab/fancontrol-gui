find_package(KF6 COMPONENTS Plasma REQUIRED)

ecm_find_qmlmodule(org.kde.plasma.core 2.0)

plasma_install_package(package org.kde.fancontrol.plasmoid)
