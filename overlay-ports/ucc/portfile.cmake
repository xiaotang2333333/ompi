vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO openucx/ucc
    REF "v${VERSION}"
    SHA512 638d3c509dc22d0158cbfca202a1a096a176bb9b68da7a9fdedd4338a82c4554ef0fbb868fbff1aafd4c4b0d18216e7e6f9ca4ff623bc27afadd15d9de49d1e5
    HEAD_REF master
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

vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    AUTORECONF
    OPTIONS
        --disable-dependency-tracking
        --disable-gtest
        --without-cuda
        --without-doca_urom
        --without-ibverbs
        --without-mpi
        --without-nccl
        --without-nvls
        --without-rccl
        --without-rdmacm
        --without-rocm
        --without-sharp
        "--with-ucx=${CURRENT_INSTALLED_DIR}"
    OPTIONS_DEBUG
        "with_ucx_libdir=${CURRENT_INSTALLED_DIR}/debug/lib"
    OPTIONS_RELEASE
        "with_ucx_libdir=${CURRENT_INSTALLED_DIR}/lib"
)
vcpkg_make_install()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
