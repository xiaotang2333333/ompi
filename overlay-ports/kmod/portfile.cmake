vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO kmod-project/kmod
    REF "v${VERSION}"
    SHA512 5f2c553bf5ce296fe3d325ed9112dada9948e3c22679f084ae946f5b53aad8270cb81f1076c89d0eebbc5083f564a21f12a808a0a43224d6d420d7ba62ab5478
    HEAD_REF master
    PATCHES
        library-only.patch
)

set(KMOD_FEATURE_OPTIONS "")
foreach(feature IN ITEMS zstd xz zlib openssl)
    set(option_value disabled)
    if(feature IN_LIST FEATURES)
        set(option_value enabled)
    endif()
    list(APPEND KMOD_FEATURE_OPTIONS "-D${feature}=${option_value}")
endforeach()

vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -Dtools=false
        -Dmanpages=false
        -Ddocs=false
        -Dbuild-tests=false
        -Dbashcompletiondir=no
        -Dfishcompletiondir=no
        -Dzshcompletiondir=no
        ${KMOD_FEATURE_OPTIONS}
)

vcpkg_install_meson()
vcpkg_fixup_pkgconfig()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
