vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO openucx/xpmem
    REF "v${VERSION}"
    SHA512 d6b2152609ca84b92ea9ada6b591c8fa7706b48695959e578dc316079e9d178c65f86ce47fb44c8677ae812fecc20ba604d8819371ca10acd5d805bf310510dd
    HEAD_REF master
)

vcpkg_make_configure(
    AUTORECONF
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        --disable-gtest
        --disable-kernel-module
)

vcpkg_make_install()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/etc"
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/etc"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING.LESSER")
