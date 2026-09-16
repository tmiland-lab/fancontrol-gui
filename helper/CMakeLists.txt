set(LIBRARIES Qt6::Core
              KF6::Auth
              KF6::I18n)

if(NOT NO_SYSTEMD)

    set(LIBRARIES ${LIBRARIES}
                  Qt6::DBus)

endif(NOT NO_SYSTEMD)

find_package(KF6Auth REQUIRED)

add_executable(fancontrol_gui-helper src/helper.cpp)
target_link_libraries(fancontrol_gui-helper PRIVATE ${LIBRARIES})
install(TARGETS fancontrol_gui-helper DESTINATION ${KAUTH_HELPER_INSTALL_DIR})

configure_file(helper.actions.in helper.actions @ONLY)
configure_file(helper.conf.in ${STANDARD_HELPER_ID}.conf @ONLY)
configure_file(helper.service.in ${STANDARD_HELPER_ID}.service @ONLY)

kauth_install_helper_files(fancontrol_gui-helper ${STANDARD_HELPER_ID} root)
kauth_install_actions(${STANDARD_HELPER_ID} ${CMAKE_CURRENT_BINARY_DIR}/helper.actions)
