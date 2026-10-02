vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pmem/ndctl
    REF "v${VERSION}"
    SHA512 48aa0a205d6b2337edc28fee17f148ea76fda18bd05a86b5c0f915022d79ba6e13a2797e67a65a9a4294fbccf00f8afce57a312fd33bc2f4165de47c7921a12b
    HEAD_REF main
    PATCHES
        library-only.patch
        static-pc-deps.patch
)

vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -Dversion-tag=${VERSION}
        -Drootprefix=/
        -Drootlibdir=lib
        -Ddocs=disabled
        -Dasciidoctor=disabled
        -Dlibtracefs=disabled
        -Dsystemd=disabled
        -Dkeyutils=disabled
        -Dtest=disabled
        -Ddestructive=disabled
        -Diniparserdir=${CURRENT_INSTALLED_DIR}/include/iniparser
)

vcpkg_install_meson()
vcpkg_fixup_pkgconfig()

vcpkg_install_copyright(FILE_LIST
    "${SOURCE_PATH}/COPYING"
    "${SOURCE_PATH}/LICENSES/preferred/GPL-2.0"
    "${SOURCE_PATH}/LICENSES/preferred/LGPL-2.1"
    "${SOURCE_PATH}/LICENSES/other/CC0-1.0"
    "${SOURCE_PATH}/LICENSES/other/MIT"
)
