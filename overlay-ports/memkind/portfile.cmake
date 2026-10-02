vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO memkind/memkind
    REF "v${VERSION}"
    SHA512 313c97c28be817abc86929565063859ec475bad31871a8ebed1f6ebca6b1c5f6b8c1d1ae947f694320b4a7c9998755681ac5d13a865ec8993440fcd8b32d7b94
    HEAD_REF master
    PATCHES
        fix-disable-static.patch
        fix-examples-ndebug.patch
)

# memkind vendors and builds a private jemalloc (symbol prefix jemk_) from its
# own tree, so an in-source build is required. Disable all optional host
# library probes: only numactl is a declared dependency.
vcpkg_make_configure(
    COPY_SOURCE
    SOURCE_PATH "${SOURCE_PATH}"
    AUTORECONF
    OPTIONS
        --disable-daxctl
        --disable-hwloc
)
# Build the vendored jemalloc first; 'all' would otherwise race with it when
# linking libmemkind.
vcpkg_make_install(TARGETS jemalloc_deps all install)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST
    "${SOURCE_PATH}/COPYING"
    "${SOURCE_PATH}/jemalloc/COPYING"
)
