vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO cornelisnetworks/opa-psm2
    REF "PSM2_${VERSION}"
    SHA512 d2d7ad487adee84ce0408a931892895dcbc5fe4dd36db8431f940a693eb0989e3b434f3684a86699824b5f0cd609ec2f8fb84989cb2a22b95b9547824ee980dc
    HEAD_REF master
)

# libpsm2 includes <rdma/hfi/hfi1_user.h> unconditionally. The rdma-core vcpkg
# package publishes that kernel UAPI header only inside its build tree
# (publish_internal_headers), so vendor the same header, pinned to the
# baseline rdma-core v62.0, for this build. It is a build-time input only.
vcpkg_download_distfile(HFI1_USER_HEADER
    URLS "https://raw.githubusercontent.com/linux-rdma/rdma-core/v62.0/kernel-headers/rdma/hfi/hfi1_user.h"
    FILENAME "rdma-core-v62.0-hfi1_user.h"
    SHA512 bc5bdb8c3dee8974a0e9fa50704980a93f99c21c0585ee54ce9302a25ff11333be6fdd810cba76d27acf450eea22cd812636cbed6736b4e9b6783485c62c1115
)
file(INSTALL "${HFI1_USER_HEADER}"
     DESTINATION "${SOURCE_PATH}/include/vcpkg-uapi/rdma/hfi"
     RENAME "hfi1_user.h")

vcpkg_cmake_get_vars(cmake_vars_file)
include("${cmake_vars_file}")

set(PSM2_LIB_MAJOR 2) # psm2.h: PSM2_VERNO_MAJOR 0x02
set(PSM2_LIB_MINOR 2) # psm2.h: PSM2_VERNO_MINOR 0x02
set(PSM2_SO_FILENAME "libpsm2.so.${PSM2_LIB_MAJOR}.${PSM2_LIB_MINOR}")

if(VCPKG_BUILD_TYPE STREQUAL "debug")
    set(PSM2_CONFIGS debug)
elseif(VCPKG_BUILD_TYPE STREQUAL "release")
    set(PSM2_CONFIGS release)
else()
    set(PSM2_CONFIGS release debug)
endif()

# PSM2 has no configure script. Drive make directly with the target compiler
# and flags detected by vcpkg; buildflags.mak accepts command line overrides
# for CC/AR/BASE_FLAGS/EXTRA_LIBS and WERROR (its only compiler switch is a
# hard-coded -Werror, which is dropped for modern compilers).
foreach(psm2_config IN LISTS PSM2_CONFIGS)
    if(psm2_config STREQUAL "debug")
        set(psm2_build_dir "${CURRENT_BUILDTREES_DIR}/psm2-${TARGET_TRIPLET}-dbg")
        set(psm2_flags "${VCPKG_COMBINED_C_FLAGS_DEBUG} -I${CURRENT_INSTALLED_DIR}/include")
        set(psm2_extra_libs "-L${CURRENT_INSTALLED_DIR}/debug/lib")
    else()
        set(psm2_build_dir "${CURRENT_BUILDTREES_DIR}/psm2-${TARGET_TRIPLET}-rel")
        set(psm2_flags "${VCPKG_COMBINED_C_FLAGS_RELEASE} -I${CURRENT_INSTALLED_DIR}/include")
        set(psm2_extra_libs "-L${CURRENT_INSTALLED_DIR}/lib")
    endif()

    set(psm2_make_command
        make
        "CC=${VCPKG_DETECTED_CMAKE_C_COMPILER}"
        "BASE_FLAGS=${psm2_flags}"
        "EXTRA_LIBS=${psm2_extra_libs}"
        "WERROR="
        "IFS_HFI_HEADER_PATH=${SOURCE_PATH}/include/vcpkg-uapi"
        "OUTDIR=${psm2_build_dir}"
    )
    if(DEFINED VCPKG_DETECTED_CMAKE_AR AND NOT VCPKG_DETECTED_CMAKE_AR STREQUAL "")
        list(APPEND psm2_make_command "AR=${VCPKG_DETECTED_CMAKE_AR}")
    endif()
    if(psm2_config STREQUAL "debug")
        list(APPEND psm2_make_command "PSM_DEBUG=1")
    endif()
    list(APPEND psm2_make_command all)

    vcpkg_execute_build_process(
        COMMAND ${psm2_make_command}
        WORKING_DIRECTORY "${SOURCE_PATH}"
        LOGNAME "build-${TARGET_TRIPLET}-${psm2_config}"
    )
endforeach()

foreach(psm2_config IN LISTS PSM2_CONFIGS)
    if(psm2_config STREQUAL "debug")
        set(psm2_build_dir "${CURRENT_BUILDTREES_DIR}/psm2-${TARGET_TRIPLET}-dbg")
        set(psm2_lib_dest "${CURRENT_PACKAGES_DIR}/debug/lib")
    else()
        set(psm2_build_dir "${CURRENT_BUILDTREES_DIR}/psm2-${TARGET_TRIPLET}-rel")
        set(psm2_lib_dest "${CURRENT_PACKAGES_DIR}/lib")
    endif()

    file(INSTALL "${psm2_build_dir}/${PSM2_SO_FILENAME}"
         DESTINATION "${psm2_lib_dest}")
    file(CREATE_LINK "${PSM2_SO_FILENAME}"
         "${psm2_lib_dest}/libpsm2.so.${PSM2_LIB_MAJOR}"
         SYMBOLIC)
    file(CREATE_LINK "libpsm2.so.${PSM2_LIB_MAJOR}"
         "${psm2_lib_dest}/libpsm2.so"
         SYMBOLIC)

    set(psm2_pc_content "prefix=\${pcfiledir}/../..
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: libpsm2
Description: PSM2 (Performance Scaled Messaging 2) user-space library
Version: ${VERSION}
Libs: -L\${libdir} -lpsm2
Libs.private: -lrt -ldl -lnuma -pthread
Cflags: -I\${includedir}
")
    file(MAKE_DIRECTORY "${psm2_lib_dest}/pkgconfig")
    file(WRITE "${psm2_lib_dest}/pkgconfig/libpsm2.pc" "${psm2_pc_content}")
endforeach()

file(INSTALL
    "${SOURCE_PATH}/psm2.h"
    "${SOURCE_PATH}/psm2_mq.h"
    "${SOURCE_PATH}/psm2_am.h"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include")

vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
