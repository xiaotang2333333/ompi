# Every optional package is explicitly enabled or disabled; do not probe host
# libraries when a feature is absent.
foreach(package IN ITEMS
    knem libltdl libnl memkind munge ofi portals4 psm2 pvfs2
    ucc ucx valgrind xpmem zlib zlibng
)
    if(package IN_LIST FEATURES)
        list(APPEND OPENMPI_FEATURE_OPTIONS "--with-${package}=${CURRENT_INSTALLED_DIR}")
        if(package MATCHES "^(libltdl|libnl|munge|ofi|portals4|psm2|ucx|xpmem|zlib|zlibng)$")
            list(APPEND OPENMPI_FEATURE_OPTIONS_DEBUG "--with-${package}-libdir=${CURRENT_INSTALLED_DIR}/debug/lib")
            list(APPEND OPENMPI_FEATURE_OPTIONS_RELEASE "--with-${package}-libdir=${CURRENT_INSTALLED_DIR}/lib")
        elseif(package MATCHES "^(memkind|pvfs2|ucc)$")
            # OAC_CHECK_PACKAGE reads these variables even where upstream does
            # not declare a corresponding --with-*-libdir command-line option.
            list(APPEND OPENMPI_FEATURE_OPTIONS_DEBUG "with_${package}_libdir=${CURRENT_INSTALLED_DIR}/debug/lib")
            list(APPEND OPENMPI_FEATURE_OPTIONS_RELEASE "with_${package}_libdir=${CURRENT_INSTALLED_DIR}/lib")
        endif()
    else()
        list(APPEND OPENMPI_FEATURE_OPTIONS "--without-${package}")
    endif()
endforeach()

# Alternate threading implementations belong in a consumer's overlay, not in
# non-exclusive features or triplet switches. Keep the standard pthread backend.
list(APPEND OPENMPI_FEATURE_OPTIONS
    --with-threads=pthreads --without-argobots --without-qthreads)

if("valgrind" IN_LIST FEATURES)
    list(APPEND OPENMPI_FEATURE_OPTIONS --enable-memchecker)
else()
    list(APPEND OPENMPI_FEATURE_OPTIONS --disable-memchecker)
endif()
set(OPENMPI_MCA_NO_BUILD)
if("libnl" IN_LIST FEATURES)
    list(APPEND OPENMPI_FEATURE_OPTIONS "with_libnl_incdir=${CURRENT_INSTALLED_DIR}/include/libnl3")
else()
    # --without-libnl alone does not disable embedded PRRTE's netlink MCA.
    list(APPEND OPENMPI_MCA_NO_BUILD prtereachable-netlink)
endif()
if(OPENMPI_MCA_NO_BUILD)
    list(JOIN OPENMPI_MCA_NO_BUILD "," disabled_components)
    list(APPEND OPENMPI_FEATURE_OPTIONS "--enable-mca-no-build=${disabled_components}")
endif()
if("zlibng" IN_LIST FEATURES AND ZLIB_COMPAT)
    message(FATAL_ERROR "openmpi[zlibng] needs native zlib-ng (ZLIB_COMPAT=OFF), not a replacement for zlib.")
endif()

# PBS, SGE and Slurm adapters need scheduler commands only at runtime. The other
# boolean integrations below likewise do not require development libraries.
foreach(package IN ITEMS pbs sge slurm usnic cma ft)
    if(package IN_LIST FEATURES)
        list(APPEND OPENMPI_FEATURE_OPTIONS "--with-${package}")
    else()
        list(APPEND OPENMPI_FEATURE_OPTIONS "--without-${package}")
    endif()
endforeach()
if("romio" IN_LIST FEATURES)
    list(APPEND OPENMPI_FEATURE_OPTIONS --enable-io-romio)
else()
    list(APPEND OPENMPI_FEATURE_OPTIONS --disable-io-romio)
endif()
if("treematch" IN_LIST FEATURES)
    list(APPEND OPENMPI_FEATURE_OPTIONS --with-treematch=yes)
else()
    list(APPEND OPENMPI_FEATURE_OPTIONS --with-treematch=no)
endif()

if("cuda" IN_LIST FEATURES)
    vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT cuda_root)
    list(APPEND OPENMPI_FEATURE_OPTIONS "--with-cuda=${cuda_root}")
else()
    list(APPEND OPENMPI_FEATURE_OPTIONS --without-cuda)
endif()

# Licensed SDKs and cluster-specific development packages are not public source
# dependencies. Like vcpkg's cuda/cudnn ports, require a real SDK installation.
# Set OPENMPI_<NAME>_ROOT in a custom triplet; its contents must match the target.
foreach(package IN ITEMS gpfs hcoll ime lsf lustre rocm tm cray-xpmem ugni udreg)
    if(NOT package IN_LIST FEATURES)
        list(APPEND OPENMPI_FEATURE_OPTIONS "--without-${package}")
        continue()
    endif()
    string(TOUPPER "${package}" sdk_name)
    string(REPLACE "-" "_" sdk_name "${sdk_name}")
    set(root_var "OPENMPI_${sdk_name}_ROOT")
    if(NOT DEFINED ${root_var} OR NOT IS_DIRECTORY "${${root_var}}")
        message(FATAL_ERROR "openmpi[${package}] needs an installed target SDK. Set ${root_var} to its prefix in your custom triplet; this SDK is not downloaded automatically.")
    endif()
    set(sdk_root "${${root_var}}")
    if(package MATCHES "^(cray-xpmem|ugni|udreg)$")
        if(package STREQUAL "cray-xpmem")
            set(module cray-xpmem)
        else()
            set(module "cray-${package}")
        endif()
        set(sdk_pc "")
        foreach(directory IN ITEMS lib/pkgconfig lib64/pkgconfig share/pkgconfig)
            if(EXISTS "${sdk_root}/${directory}/${module}.pc")
                set(sdk_pc "${sdk_root}/${directory}/${module}.pc")
                break()
            endif()
        endforeach()
        if(sdk_pc STREQUAL "")
            message(FATAL_ERROR "${root_var} must contain ${module}.pc in lib/pkgconfig, lib64/pkgconfig or share/pkgconfig.")
        endif()
        vcpkg_host_path_list(PREPEND ENV{PKG_CONFIG_PATH}
            "${sdk_root}/lib/pkgconfig" "${sdk_root}/lib64/pkgconfig" "${sdk_root}/share/pkgconfig")
        # Query the exact SDK file: vcpkg-make prepends installed package paths,
        # which could otherwise shadow this SDK with xpmem's cray-xpmem.pc.
        vcpkg_find_acquire_program(PKGCONFIG)
        set(pkgconfig_options)
        if(package STREQUAL "cray-xpmem")
            list(APPEND pkgconfig_options --static)
        endif()
        string(TOUPPER "${module}" pkgconfig_prefix)
        string(REPLACE "-" "_" pkgconfig_prefix "${pkgconfig_prefix}")
        foreach(flag IN ITEMS cflags libs)
            vcpkg_execute_required_process(
                COMMAND "${PKGCONFIG}" ${pkgconfig_options} "--${flag}" "${sdk_pc}"
                WORKING_DIRECTORY "${SOURCE_PATH}"
                LOGNAME "pkgconfig-${package}-${flag}"
                OUTPUT_VARIABLE sdk_flags
                OUTPUT_STRIP_TRAILING_WHITESPACE
            )
            string(TOUPPER "${flag}" flag_name)
            list(APPEND OPENMPI_FEATURE_OPTIONS "${pkgconfig_prefix}_${flag_name}=${sdk_flags}")
        endforeach()
        list(APPEND OPENMPI_FEATURE_OPTIONS "--with-${package}=yes")
    else()
        list(APPEND OPENMPI_FEATURE_OPTIONS "--with-${package}=${sdk_root}")
    endif()
endforeach()
