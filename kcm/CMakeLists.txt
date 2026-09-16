set(LIBRARIES Qt6::Core
              KF6::CoreAddons
              KF6::I18n
              KF6::QuickAddons
              KF6::KCMUtils)

find_package(KF6 COMPONENTS CoreAddons Package Declarative KCMUtils REQUIRED)

ecm_find_qmlmodule(org.kde.kcmutils 1.0)

add_library(kcm_fancontrol MODULE src/fancontrolkcm.cpp)

target_link_libraries(kcm_fancontrol PRIVATE ${LIBRARIES})

install(TARGETS kcm_fancontrol DESTINATION "${KDE_INSTALL_QTPLUGINDIR}/kcms")

kpackage_install_package(package org.kde.fancontrol.kcm kcms)
