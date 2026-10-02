vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO memkind/memkind
    REF "v${VERSION}"
    SHA512 313c97c28be817abc86929565063859ec475bad31871a8ebed1f6ebca6b1c5f6b8c1d1ae947f694320b4a7c9998755681ac5d13a865ec8993440fcd8b32d7b94
    HEAD_REF master
    PATCHES
        fix-disable-static.patch
        disable-examples.patch
        fix-jemalloc-cross-host.patch
        fix-pkgconfig-private-math.patch
)

set(FEATURE_OPTIONS "")
if("daxctl" IN_LIST FEATURES)
    list(APPEND FEATURE_OPTIONS "--enable-daxctl")
else()
    list(APPEND FEATURE_OPTIONS "--disable-daxctl")
endif()
if("hwloc" IN_LIST FEATURES)
    list(APPEND FEATURE_OPTIONS "--enable-hwloc")
else()
    list(APPEND FEATURE_OPTIONS "--disable-hwloc")
endif()

# memkind vendors and builds a private jemalloc (symbol prefix jemk_) from its
# own tree, so an in-source build is required. The hwloc and daxctl probes are
# feature-gated and explicitly disabled otherwise, so configure never falls
# back to host libraries; the vcpkg-make include and library paths select the
# installed dependency for the current configuration.
vcpkg_make_configure(
    COPY_SOURCE
    SOURCE_PATH "${SOURCE_PATH}"
    AUTORECONF
    OPTIONS
        ${FEATURE_OPTIONS}
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
