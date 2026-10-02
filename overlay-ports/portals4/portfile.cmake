# The Portals4 repository publishes no release tags; v4.2 is the released
# source state identified by this commit.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO Portals4/portals4
    REF 8c16cdc0f9478b6ef410526387fabf73fdcc6f19
    SHA512 47a9ab7062734bc6e6d280b40016e20d7b774d54417883c15989a6ea07f5e5cf704f1eb8cfe7cee9d1723452fc4909cc5abc281a61fd7878933e4612888e3ed9
    HEAD_REF master
)

# The upstream tree ships no configure script, so autoreconf is used (requires
# the usual autotools host packages, provided by the vcpkg CI image).
#
# User-space library only:
#   --disable-testing / --disable-pmi-from-portals  no MPI-based test suite and
#                                                   no bundled PMI/ORTE runtime
#   --disable-transport-ib                          no OFED/IB, hence no
#                                                   libibverbs dependency
#   --enable-transport-udp                          hardware-independent
#                                                   transport for the library
# libportals always links libev; the vcpkg libev package keeps ev.h under
# include/libev, which the bundled OMPI_CHECK_PACKAGE macro detects.
# The hwloc and bsd-compat probes are forced off so the package never links a
# build-host library that is not declared as a dependency.  KNEM is only
# enabled through the optional "knem" feature; without it the build must not
# probe the host for knem_io.h.
set(PORTALS4_OPTIONS
    --disable-dependency-tracking
    --disable-testing
    --disable-pmi-from-portals
    --disable-transport-ib
    --enable-transport-udp
    "--with-ev=${CURRENT_INSTALLED_DIR}"
    ac_cv_search_hwloc_topology_init=no
    ac_cv_lib_bsd_compat_main=no
)
if("knem" IN_LIST FEATURES)
    list(APPEND PORTALS4_OPTIONS "--with-knem=${CURRENT_INSTALLED_DIR}")
else()
    list(APPEND PORTALS4_OPTIONS --without-knem)
endif()
vcpkg_make_configure(
    AUTORECONF
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${PORTALS4_OPTIONS}
    OPTIONS_DEBUG
        "with_ev_libdir=${CURRENT_INSTALLED_DIR}/debug/lib"
    OPTIONS_RELEASE
        "with_ev_libdir=${CURRENT_INSTALLED_DIR}/lib"
)
vcpkg_make_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
