vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/sandialabs/qthreads/releases/download/${VERSION}/qthreads-${VERSION}.tar.gz"
    FILENAME "qthreads-${VERSION}.tar.gz"
    SHA512 1cca3b42e074ab966d6a0878c25285af3ee2ce3b460da2f48442dc55cfdb7ee0b56c036e244433cfc461e99e991dc50615323061035fb390d6d93f41fc84f890
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
)

# qthreads 1.21 advertises --with-topology=hwloc_v2, but the release tarball
# ships no src/affinity/hwloc_v2.c (it is only listed in EXTRA_DIST) and
# configure.ac runs QTHREAD_CHECK_HWLOC for "hwloc", not "hwloc_v2".  The
# shipped src/affinity/hwloc.c is API-version neutral: it uses hwloc_bitmap_*
# for HWLOC_API_VERSION != 0x00010000 (i.e. hwloc 2.x such as the registry's
# 2.11.2) and falls back to the hwloc 1.x cpuset API otherwise.  The missing
# deprecated distance symbol it probes for makes the configure distance check
# fail gracefully on hwloc 2.x, which selects the shep_dists fallback.
#
# QTHREAD_CHECK_HWLOC only accepts a single --with-hwloc=PREFIX and hard-codes
# -L$with_hwloc/lib.  Split the library directory into with_hwloc_libdir so
# Debug builds can link the debug hwloc while the headers stay
# configuration-independent.  This port does not run AUTORECONF and the mtime
# refresh below suppresses regeneration, so the shipped generated configure
# script must receive the same replacement as the m4 source.
vcpkg_replace_string("${SOURCE_PATH}/config/qthread_check_hwloc.m4"
    "AS_IF([test \"x$with_hwloc\" != x],"
    "AS_IF([test \"x$with_hwloc_libdir\" = x], [with_hwloc_libdir=\"$with_hwloc/lib\"])
  AS_IF([test \"x$with_hwloc\" != x],")
vcpkg_replace_string("${SOURCE_PATH}/config/qthread_check_hwloc.m4"
    "-L$with_hwloc/lib" "-L$with_hwloc_libdir")
vcpkg_replace_string("${SOURCE_PATH}/configure"
    "  hwloc_saved_LDFLAGS=\"$LDFLAGS\"
  if test \"x$with_hwloc\" != x"
    "  hwloc_saved_LDFLAGS=\"$LDFLAGS\"
  if test \"x$with_hwloc_libdir\" = x
then :
  with_hwloc_libdir=\"$with_hwloc/lib\"
fi
  if test \"x$with_hwloc\" != x")
vcpkg_replace_string("${SOURCE_PATH}/configure"
    "LDFLAGS=\"-L$with_hwloc/lib $LDFLAGS\"" "LDFLAGS=\"-L$with_hwloc_libdir $LDFLAGS\"")

# The 1.21 release tarball was assembled with automake 1.17 and ships
# aclocal.m4/Makefile.in that are older than the bundled config/*.m4 files.
# Make would then try to regenerate them, which fails on hosts that only
# provide automake 1.16 (e.g. Ubuntu 24.04).  Refresh the timestamps of the
# shipped generated files, keeping aclocal.m4 older than the files generated
# from it.
file(GLOB_RECURSE qthreads_generated_aclocal LIST_DIRECTORIES false
    "${SOURCE_PATH}/*aclocal.m4"
)
file(GLOB_RECURSE qthreads_generated_files LIST_DIRECTORIES false
    "${SOURCE_PATH}/*Makefile.in"
    "${SOURCE_PATH}/*config.h.in"
    "${SOURCE_PATH}/*configure"
)
if(qthreads_generated_aclocal)
    file(TOUCH ${qthreads_generated_aclocal})
endif()
if(qthreads_generated_files)
    file(TOUCH ${qthreads_generated_files})
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        hwloc QTHREADS_HWLOC
)

# Default stays "no": configure.ac probes hwloc whenever the topology is left
# to guess, which would link whatever the build host happens to provide.
set(QTHREADS_OPTIONS "")
set(QTHREADS_DEBUG_OPTIONS "")
set(QTHREADS_RELEASE_OPTIONS "")
if(QTHREADS_HWLOC)
    list(APPEND QTHREADS_OPTIONS
        --with-topology=hwloc
        "--with-hwloc=${CURRENT_INSTALLED_DIR}"
    )
    list(APPEND QTHREADS_DEBUG_OPTIONS
        "with_hwloc_libdir=${CURRENT_INSTALLED_DIR}/debug/lib"
    )
    list(APPEND QTHREADS_RELEASE_OPTIONS
        "with_hwloc_libdir=${CURRENT_INSTALLED_DIR}/lib"
    )
else()
    list(APPEND QTHREADS_OPTIONS --with-topology=no)
endif()

vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${QTHREADS_OPTIONS}
    OPTIONS_DEBUG
        ${QTHREADS_DEBUG_OPTIONS}
    OPTIONS_RELEASE
        ${QTHREADS_RELEASE_OPTIONS}
)
vcpkg_make_install()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
