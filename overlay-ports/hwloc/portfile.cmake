vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO open-mpi/hwloc
    REF "hwloc-${VERSION}"
    SHA512 890c345253e94c54c76b7f943f50027ac8519f4d6b1136ea923f6b6fbba54b1e8ce788d094949140658dd11af59c86d320be32bd0df0a3e1df47d8204f72e06b
    PATCHES
        fix_shared_win_build.patch
        stdout_fileno.patch
)

if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_MINGW)
    set(OPTIONS ac_cv_prog_cc_c99= # To avoid the compiler check for C99 which will fail for MSVC
                --disable-plugin-dlopen)
endif()

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    list(APPEND OPTIONS "HWLOC_LDFLAGS=-no-undefined")
elseif(VCPKG_TARGET_IS_OSX)
    list(APPEND OPTIONS "HWLOC_LDFLAGS=-framework CoreFoundation")
endif()

# Optional upstream backends, one per feature.  Every backend is passed
# explicitly: without --disable, configure would silently pick up libraries
# from the build machine, and without --enable, a requested feature could
# silently disappear because most probes only hard-error when explicitly
# enabled.
set(HWLOC_FEATURE_OPTIONS "")
foreach(hwloc_backend IN ITEMS libxml2 cairo opencl levelzero libudev cuda nvml)
    if(hwloc_backend IN_LIST FEATURES)
        list(APPEND HWLOC_FEATURE_OPTIONS "--enable-${hwloc_backend}")
    else()
        list(APPEND HWLOC_FEATURE_OPTIONS "--disable-${hwloc_backend}")
    endif()
endforeach()

# ROCm SMI: upstream tries the AMD SMI backend first and fails hard when both
# backends are found at once, and the AMD SMI backend additionally needs the
# /opt/amdgpu headers of ROCm >= 6.4.  Pin the feature to the ROCm SMI
# implementation and hand configure the toolkit that the rocm port located.
if("rsmi" IN_LIST FEATURES)
    include("${CURRENT_INSTALLED_DIR}/share/rocm/vcpkg-port-config.cmake")
    vcpkg_find_rocm(OUT_ROCM_TOOLKIT_ROOT ROCM_TOOLKIT_ROOT)
    list(APPEND HWLOC_FEATURE_OPTIONS
        --enable-rsmi
        --disable-rsmi-amd
        "--with-rocm=${ROCM_TOOLKIT_ROOT}"
    )
else()
    list(APPEND HWLOC_FEATURE_OPTIONS --disable-rsmi)
endif()

# hwloc only auto-detects the hard-coded /usr/local/cuda layout; forward the
# toolkit that the cuda port located (CUDA_PATH/CUDA_HOME or /usr/local/cuda-*).
if("cuda" IN_LIST FEATURES OR "nvml" IN_LIST FEATURES)
    include("${CURRENT_INSTALLED_DIR}/share/cuda/vcpkg-port-config.cmake")
    vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT CUDA_TOOLKIT_ROOT)
    list(APPEND HWLOC_FEATURE_OPTIONS "--with-cuda=${CUDA_TOOLKIT_ROOT}")
endif()

if("levelzero" IN_LIST FEATURES AND VCPKG_LIBRARY_LINKAGE STREQUAL "static" AND VCPKG_TARGET_IS_LINUX)
    # Upstream libze_loader.pc ships no Libs.private, and hwloc resolves it
    # with plain `pkg-config --libs` (never --static), so the C++ runtime the
    # loader needs is missing on static triplets.  hwloc lets configure take
    # the flags from HWLOC_LEVELZERO_LIBS instead; the value is substituted
    # into hwloc.pc, so static consumers inherit -lstdc++ as well.
    set(ENV{HWLOC_LEVELZERO_LIBS} "-lze_loader -lstdc++")
endif()

# pci (libpciaccess) and gl (libXNVCtrl) have no vcpkg dependency port, so
# they cannot be offered as features and stay disabled.
list(APPEND HWLOC_FEATURE_OPTIONS
    --disable-pci
    --disable-gl
)

vcpkg_configure_make(
    SOURCE_PATH "${SOURCE_PATH}"
    AUTOCONFIG
    OPTIONS
        ${OPTIONS}
        ${HWLOC_FEATURE_OPTIONS}
        #--disable-cpuid
        #--disable-picky
)

vcpkg_install_make()
vcpkg_fixup_pkgconfig()

# --enable-libudev is the only probe that stays silent when the dependency is
# missing, so assert that the requested feature really reached the package.
if("libudev" IN_LIST FEATURES)
    file(READ "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/hwloc.pc" HWLOC_PC_CONTENTS)
    if(NOT HWLOC_PC_CONTENTS MATCHES "ludev")
        message(FATAL_ERROR "hwloc[libudev] was requested, but hwloc.pc does not link -ludev (libudev probe did not find the dependency)")
    endif()
endif()

vcpkg_copy_tool_dependencies("${CURRENT_PACKAGES_DIR}/tools/${PORT}/bin")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

if(EXISTS "${CURRENT_PACKAGES_DIR}/tools/hwloc/bin/hwloc-compress-dir")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/tools/hwloc/bin/hwloc-compress-dir" "${CURRENT_INSTALLED_DIR}" "`dirname $0`/../../.." IGNORE_UNCHANGED)
endif()
if(EXISTS "${CURRENT_PACKAGES_DIR}/tools/hwloc/debug/bin/hwloc-compress-dir")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/tools/hwloc/debug/bin/hwloc-compress-dir" "${CURRENT_INSTALLED_DIR}" "`dirname $0`/../../../.." IGNORE_UNCHANGED)
endif()

if(EXISTS "${CURRENT_PACKAGES_DIR}/tools/hwloc/bin/hwloc-gather-topology")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/tools/hwloc/bin/hwloc-gather-topology" "${CURRENT_INSTALLED_DIR}" "`dirname $0`/../../..")
endif()
if(EXISTS "${CURRENT_PACKAGES_DIR}/tools/hwloc/debug/bin/hwloc-gather-topology")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/tools/hwloc/debug/bin/hwloc-gather-topology" "${CURRENT_INSTALLED_DIR}" "`dirname $0`/../../../..")
endif()

# Handle copyright
file(INSTALL "${SOURCE_PATH}/COPYING" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

file(REMOVE "${CURRENT_PACKAGES_DIR}/debug/COPYING.txt"
            "${CURRENT_PACKAGES_DIR}/debug/README.txt"
            "${CURRENT_PACKAGES_DIR}/debug/NEWS.txt"
            "${CURRENT_PACKAGES_DIR}/COPYING.txt"
            "${CURRENT_PACKAGES_DIR}/README.txt"
            "${CURRENT_PACKAGES_DIR}/NEWS.txt"
    )
