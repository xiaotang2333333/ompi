vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/sandialabs/qthreads/releases/download/${VERSION}/qthreads-${VERSION}.tar.gz"
    FILENAME "qthreads-${VERSION}.tar.gz"
    SHA512 1cca3b42e074ab966d6a0878c25285af3ee2ce3b460da2f48442dc55cfdb7ee0b56c036e244433cfc461e99e991dc50615323061035fb390d6d93f41fc84f890
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
)

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
