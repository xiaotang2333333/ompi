vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/sandialabs/qthreads/releases/download/${VERSION}/qthreads-${VERSION}.tar.gz"
    FILENAME "qthreads-${VERSION}.tar.gz"
    SHA512 1cca3b42e074ab966d6a0878c25285af3ee2ce3b460da2f48442dc55cfdb7ee0b56c036e244433cfc461e99e991dc50615323061035fb390d6d93f41fc84f890
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
)

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

vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        # qthreads otherwise autodetects hwloc on the build machine. Consumers
        # only need the qthread library and headers.
        --with-topology=no
)
vcpkg_make_install()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
