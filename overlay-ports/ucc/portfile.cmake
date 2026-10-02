vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO openucx/ucc
    REF "v${VERSION}"
    SHA512 638d3c509dc22d0158cbfca202a1a096a176bb9b68da7a9fdedd4338a82c4554ef0fbb868fbff1aafd4c4b0d18216e7e6f9ca4ff623bc27afadd15d9de49d1e5
    HEAD_REF master
    PATCHES fix-nccl-include-dir.patch
)

# Prepare the same generated inputs as upstream autogen.sh before AUTORECONF.
file(MAKE_DIRECTORY "${SOURCE_PATH}/config/aux")
file(GLOB UCC_TL_DIRS LIST_DIRECTORIES true "${SOURCE_PATH}/src/components/tl/*")
set(UCC_TLS_LIST "")
set(UCC_TL_MAKEFILE "")
set(UCC_TLCP_LIST "")
foreach(UCC_TL_DIR IN LISTS UCC_TL_DIRS)
    if(NOT IS_DIRECTORY "${UCC_TL_DIR}")
        continue()
    endif()
    get_filename_component(UCC_TL_NAME "${UCC_TL_DIR}" NAME)
    string(APPEND UCC_TLS_LIST "m4_include([src/components/tl/${UCC_TL_NAME}/configure.m4])\n")
    string(APPEND UCC_TL_MAKEFILE "SUBDIRS += components/tl/${UCC_TL_NAME}\n")
    if(IS_DIRECTORY "${UCC_TL_DIR}/coll_plugins")
        file(GLOB UCC_TLCP_DIRS LIST_DIRECTORIES true "${UCC_TL_DIR}/coll_plugins/*")
        set(UCC_TL_COLL_MAKEFILE "")
        foreach(UCC_TLCP_DIR IN LISTS UCC_TLCP_DIRS)
            if(NOT IS_DIRECTORY "${UCC_TLCP_DIR}")
                continue()
            endif()
            get_filename_component(UCC_TLCP_NAME "${UCC_TLCP_DIR}" NAME)
            string(APPEND UCC_TLCP_LIST "m4_include([src/components/tl/${UCC_TL_NAME}/coll_plugins/${UCC_TLCP_NAME}/configure.m4])\n")
            string(APPEND UCC_TL_COLL_MAKEFILE "SUBDIRS += coll_plugins/${UCC_TLCP_NAME}\n")
        endforeach()
        file(WRITE "${UCC_TL_DIR}/makefile.coll_plugins.am" "${UCC_TL_COLL_MAKEFILE}")
    endif()
endforeach()
file(WRITE "${SOURCE_PATH}/config/m4/tls_list.m4" "${UCC_TLS_LIST}")
file(WRITE "${SOURCE_PATH}/config/m4/tl_coll_plugins_list.m4" "${UCC_TLCP_LIST}")
file(WRITE "${SOURCE_PATH}/src/components/tl/makefile.am" "${UCC_TL_MAKEFILE}")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        cuda    UCC_CUDA
        ibverbs UCC_IBVERBS
        nccl    UCC_NCCL
        nvls    UCC_NVLS
        rdmacm UCC_RDMACM
)

# Tests, examples and vendor SDK integrations without an available port stay off
# unconditionally.  The UCX dependency and its library directory override are
# mandatory for every configuration.
set(UCC_OPTIONS
    --disable-dependency-tracking
    --disable-gtest
    --without-doca_urom
    --without-mpi
    --without-rccl
    --without-rocm
    --without-sharp
    "--with-ucx=${CURRENT_INSTALLED_DIR}"
)
set(UCC_DEBUG_OPTIONS "with_ucx_libdir=${CURRENT_INSTALLED_DIR}/debug/lib")
set(UCC_RELEASE_OPTIONS "with_ucx_libdir=${CURRENT_INSTALLED_DIR}/lib")

# cuda: the registered cuda port is a verifier; vcpkg_find_cuda returns the
# real toolkit root and the version parsed from nvcc.  config/m4/cuda.m4
# requires CUDA >= 11.0 with nvcc, and an explicit --with-cuda also requires
# NVML (TL CUDA itself needs nvml_happy).
if(UCC_CUDA)
    vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT ucc_cuda_root OUT_CUDA_VERSION ucc_cuda_version)
    if(ucc_cuda_version VERSION_LESS 11.0)
        message(FATAL_ERROR "UCC CUDA support requires CUDA >= 11.0 (config/m4/cuda.m4 CUDA_MIN_REQUIRED_MAJOR=11); found ${ucc_cuda_version} at ${ucc_cuda_root}")
    endif()
    message(STATUS "UCC CUDA toolkit ${ucc_cuda_version}: ${ucc_cuda_root}")
    list(APPEND UCC_OPTIONS "--with-cuda=${ucc_cuda_root}")
else()
    list(APPEND UCC_OPTIONS --without-cuda)
endif()

# nccl: the nccl feature depends on this port's cuda feature.  config/m4/nccl.m4
# checks only nccl.h + ncclCommInitRank (no version pin), and tl_nccl guards the
# >= 2.14.3 non-blocking APIs behind NCCL_VERSION_CODE, so an installed newer
# NCCL is accepted.  Include and library directories come from the registered
# nccl port's FindNCCL helper.
if(UCC_NCCL)
    if(NOT UCC_CUDA)
        message(FATAL_ERROR "ucc[nccl] requires the ucc cuda feature")
    endif()
    list(APPEND CMAKE_MODULE_PATH "${CURRENT_INSTALLED_DIR}/share/nccl")
    find_package(NCCL REQUIRED)
    list(REMOVE_AT CMAKE_MODULE_PATH -1)
    get_filename_component(ucc_nccl_include "${NCCL_INCLUDE_DIRS}" ABSOLUTE)
    get_filename_component(ucc_nccl_libdir "${NCCL_LIBRARIES}" DIRECTORY)
    get_filename_component(ucc_nccl_include_name "${ucc_nccl_include}" NAME)
    if(ucc_nccl_include_name STREQUAL "include")
        get_filename_component(ucc_nccl_prefix "${ucc_nccl_include}" DIRECTORY)
    else()
        # Keep an existing prefix for configure's directory validation; the
        # patched NCCL check takes the real include directory separately.
        set(ucc_nccl_prefix "${ucc_nccl_include}")
    endif()
    message(STATUS "UCC NCCL ${_NCCL_VERSION}: include=${ucc_nccl_include} libdir=${ucc_nccl_libdir}")
    list(APPEND UCC_OPTIONS "--with-nccl=${ucc_nccl_prefix}")
    list(APPEND UCC_OPTIONS "with_nccl_incdir=${ucc_nccl_include}")
    list(APPEND UCC_DEBUG_OPTIONS "with_nccl_libdir=${ucc_nccl_libdir}")
    list(APPEND UCC_RELEASE_OPTIONS "with_nccl_libdir=${ucc_nccl_libdir}")
else()
    list(APPEND UCC_OPTIONS --without-nccl)
endif()

# nvls: config/m4/nvls.m4 requires cuda_happy, CUDA >= 12 and sm_90/sm_100 in
# NVCC_ARCH; the nvls feature depends on cuda.  --with-nvls hard-errors if the
# toolchain cannot provide those gencodes.  Runtime needs NVSwitch/multicast
# hardware, which is not checked at build time.
if(UCC_NVLS)
    if(NOT UCC_CUDA)
        message(FATAL_ERROR "ucc[nvls] requires the ucc cuda feature")
    endif()
    if(ucc_cuda_version VERSION_LESS 12.0)
        message(FATAL_ERROR "UCC NVLS requires CUDA >= 12.0 (config/m4/nvls.m4); found ${ucc_cuda_version}")
    endif()
    list(APPEND UCC_OPTIONS --with-nvls)
else()
    list(APPEND UCC_OPTIONS --without-nvls)
endif()

# config/m4/ibverbs.m4: --with-ibverbs=DIR adds -I$DIR/include and defaults the
# library search to $DIR/lib; the explicit with_ibverbs_libdir variable
# overrides that directory so Debug links the debug rdma-core.
if(UCC_IBVERBS)
    list(APPEND UCC_OPTIONS "--with-ibverbs=${CURRENT_INSTALLED_DIR}")
    list(APPEND UCC_DEBUG_OPTIONS
        "with_ibverbs_libdir=${CURRENT_INSTALLED_DIR}/debug/lib"
    )
    list(APPEND UCC_RELEASE_OPTIONS
        "with_ibverbs_libdir=${CURRENT_INSTALLED_DIR}/lib"
    )
else()
    list(APPEND UCC_OPTIONS --without-ibverbs)
endif()

# config/m4/rdmacm.m4: same prefix/include contract with_rdmacm_libdir override.
if(UCC_RDMACM)
    list(APPEND UCC_OPTIONS "--with-rdmacm=${CURRENT_INSTALLED_DIR}")
    list(APPEND UCC_DEBUG_OPTIONS
        "with_rdmacm_libdir=${CURRENT_INSTALLED_DIR}/debug/lib"
    )
    list(APPEND UCC_RELEASE_OPTIONS
        "with_rdmacm_libdir=${CURRENT_INSTALLED_DIR}/lib"
    )
else()
    list(APPEND UCC_OPTIONS --without-rdmacm)
endif()

vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    AUTORECONF
    OPTIONS
        ${UCC_OPTIONS}
    OPTIONS_DEBUG
        ${UCC_DEBUG_OPTIONS}
    OPTIONS_RELEASE
        ${UCC_RELEASE_OPTIONS}
)
vcpkg_make_install()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
