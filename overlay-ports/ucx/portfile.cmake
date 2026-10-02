vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/openucx/ucx/releases/download/v${VERSION}/ucx-${VERSION}.tar.gz"
    FILENAME "ucx-${VERSION}.tar.gz"
    SHA512 72cceb05bae0998de209e51a194a532680b2db439ce419ca5c4e11ad4df5c7d68c467ded5bfa59a8e73baeb3ad8edccec8744fa55585ad7d383cc580c6e40453
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    PATCHES
        # test/apps is unconditionally in SUBDIRS, independent of
        # --disable-test-apps: it builds the noinst ucx_profiling helper and
        # installs the io_demo demo binary.  Keep the library and the useful
        # src/tools utilities (ucx_info, ucx_perftest, ...).
        skip-test-apps.patch
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
# XPMEM hard-codes -L$with_xpmem/lib (no lib64 variant), so make the library
# directory overridable the same way as verbs/rdmacm.
foreach(path IN ITEMS configure src/uct/sm/mm/xpmem/configure.m4)
    vcpkg_replace_string("${SOURCE_PATH}/${path}"
        [[-L$with_xpmem/lib]] [[-L$with_xpmem_libdir]])
endforeach()

# Optional dependency integrations are additive, non-exclusive features.  Each
# one is either requested against the vcpkg installed prefix or explicitly
# disabled, so configure never probes the build host.
set(UCX_OPTIONS
    --disable-dependency-tracking
    --disable-examples
    --disable-gtest
    --without-bfd
    --without-efa
    --without-fuse3
    --without-gda
    --without-gaudi
    --without-gdrcopy
    --without-gga
    --without-go
    --without-java
    --without-iodemo-cuda
    --without-mad
    --without-mpi
    --without-mlx5
    --without-rocm
    --without-ugni
    --without-ze
    "--with-rdmacm=${CURRENT_INSTALLED_DIR}"
    "--with-verbs=${CURRENT_INSTALLED_DIR}"
)
set(UCX_OPTIONS_DEBUG
    "with_verbs_libdir=${CURRENT_INSTALLED_DIR}/debug/lib"
    "with_rdmacm_libdir=${CURRENT_INSTALLED_DIR}/debug/lib"
)
set(UCX_OPTIONS_RELEASE
    "with_verbs_libdir=${CURRENT_INSTALLED_DIR}/lib"
    "with_rdmacm_libdir=${CURRENT_INSTALLED_DIR}/lib"
)

# KNEM and Valgrind are header-only dependencies; the installed include
# directory is shared by both configurations.
if("knem" IN_LIST FEATURES)
    list(APPEND UCX_OPTIONS "--with-knem=${CURRENT_INSTALLED_DIR}")
else()
    list(APPEND UCX_OPTIONS --without-knem)
endif()
if("valgrind" IN_LIST FEATURES)
    list(APPEND UCX_OPTIONS "--with-valgrind=${CURRENT_INSTALLED_DIR}")
else()
    list(APPEND UCX_OPTIONS --without-valgrind)
endif()

# XPMEM ships a library and the release include directory is shared (the xpmem
# port removes debug/include).  The patched configure accepts the exact
# configuration library directory through with_xpmem_libdir.
if("xpmem" IN_LIST FEATURES)
    list(APPEND UCX_OPTIONS "--with-xpmem=${CURRENT_INSTALLED_DIR}")
    list(APPEND UCX_OPTIONS_DEBUG "with_xpmem_libdir=${CURRENT_INSTALLED_DIR}/debug/lib")
    list(APPEND UCX_OPTIONS_RELEASE "with_xpmem_libdir=${CURRENT_INSTALLED_DIR}/lib")
else()
    list(APPEND UCX_OPTIONS --without-xpmem)
endif()

# The registered "cuda" port is a verifier helper (nvcc >= 10.1); it does not
# pin the toolkit version.  Validate the actually installed toolkit against
# UCX's own floor (NVCC_CUDA_MIN_REQUIRED = 12.2 in config/m4/cuda.m4) before
# requesting CUDA.  The real SDK must also provide cuda.h/cuda_runtime.h,
# nvml.h, libcuda, libcudart and libnvidia-ml (configure checks each of them).
if("cuda" IN_LIST FEATURES)
    vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT cuda_root OUT_CUDA_VERSION cuda_version)
    if(cuda_version VERSION_LESS 12.2)
        message(FATAL_ERROR
            "ucx[cuda] requires CUDA >= 12.2 (UCX NVCC_CUDA_MIN_REQUIRED), found ${cuda_version}.")
    endif()
    list(APPEND UCX_OPTIONS "--with-cuda=${cuda_root}")
else()
    list(APPEND UCX_OPTIONS --without-cuda)
endif()

vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${UCX_OPTIONS}
    OPTIONS_DEBUG
        ${UCX_OPTIONS_DEBUG}
    OPTIONS_RELEASE
        ${UCX_OPTIONS_RELEASE}
)
vcpkg_make_install()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
