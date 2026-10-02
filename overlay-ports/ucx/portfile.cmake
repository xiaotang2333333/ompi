vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/openucx/ucx/releases/download/v${VERSION}/ucx-${VERSION}.tar.gz"
    FILENAME "ucx-${VERSION}.tar.gz"
    SHA512 72cceb05bae0998de209e51a194a532680b2db439ce419ca5c4e11ad4df5c7d68c467ded5bfa59a8e73baeb3ad8edccec8744fa55585ad7d383cc580c6e40453
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
)

# Upstream hard-codes PREFIX/lib in its transport checks. Keep headers at the
# common prefix while selecting the correct vcpkg configuration's libraries.
foreach(path IN ITEMS configure src/uct/ib/configure.m4)
    vcpkg_replace_string("${SOURCE_PATH}/${path}"
        [[-L$with_verbs/lib$libsuff]] [[-L$with_verbs_libdir]])
endforeach()
foreach(path IN ITEMS configure src/uct/ib/rdmacm/configure.m4)
    vcpkg_replace_string("${SOURCE_PATH}/${path}"
        [[-L$ucx_check_rdmacm_dir/lib$libsuff]] [[-L$with_rdmacm_libdir]])
endforeach()

vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        --disable-dependency-tracking
        --disable-examples
        --disable-gtest
        --without-bfd
        --without-cuda
        --without-efa
        --without-fuse3
        --without-gda
        --without-gaudi
        --without-gdrcopy
        --without-gga
        --without-go
        --without-java
        --without-iodemo-cuda
        --without-knem
        --without-mad
        --without-mpi
        --without-mlx5
        --without-rocm
        --without-ugni
        --without-valgrind
        --without-xpmem
        --without-ze
        "--with-rdmacm=${CURRENT_INSTALLED_DIR}"
        "--with-verbs=${CURRENT_INSTALLED_DIR}"
    OPTIONS_DEBUG
        "with_verbs_libdir=${CURRENT_INSTALLED_DIR}/debug/lib"
        "with_rdmacm_libdir=${CURRENT_INSTALLED_DIR}/debug/lib"
    OPTIONS_RELEASE
        "with_verbs_libdir=${CURRENT_INSTALLED_DIR}/lib"
        "with_rdmacm_libdir=${CURRENT_INSTALLED_DIR}/lib"
)
vcpkg_make_install()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
