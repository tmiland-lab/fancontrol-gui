set(Fancontrol_GUI_SRCS src/main.cpp
                        src/systemtrayicon.cpp)

set(LIBRARIES Qt6::Gui
              Qt6::Widgets
              KF6::CoreAddons
              KF6::DBusAddons
              KF6::Package
              KF6::I18n
              KF6::ConfigCore
              KF6::ConfigGui
              KF6::Notifications
              KF6::StatusNotifierItem)

find_package(KF6StatusNotifierItem REQUIRED)

add_executable(fancontrol_gui ${Fancontrol_GUI_SRCS})
target_link_libraries(fancontrol_gui PRIVATE ${LIBRARIES})

install(TARGETS fancontrol_gui ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
install(PROGRAMS org.kde.fancontrol.gui.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES org.kde.fancontrol.gui.appdata.xml DESTINATION ${KDE_INSTALL_METAINFODIR})

kpackage_install_package(package org.kde.fancontrol.gui genericqml)
