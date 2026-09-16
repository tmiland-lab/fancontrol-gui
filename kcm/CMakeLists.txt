set(KCM_SOURCES src/fancontrolkcm.cpp)

find_package(KF6 REQUIRED COMPONENTS KCMUtils CoreAddons)

kcmutils_add_qml_kcm(kcm_fancontrol
    INSTALL_NAMESPACE plasma/kcms/systemsettings
    SOURCES ${KCM_SOURCES}
)

target_link_libraries(kcm_fancontrol PRIVATE
    Qt6::Core
    Qt6::Quick
    KF6::CoreAddons
    KF6::I18n
    KF6::KCMUtils
    KF6::KCMUtilsQuick
)