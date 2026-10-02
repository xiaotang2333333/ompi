vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

string(REGEX REPLACE [[^([0-9]+[.][0-9]+).*$]] [[\1]] OpenMPI_SHORT_VERSION "${VERSION}")

vcpkg_download_distfile(ARCHIVE
    URLS "https://download.open-mpi.org/release/open-mpi/v${OpenMPI_SHORT_VERSION}/openmpi-${VERSION}.tar.gz"
    FILENAME "openmpi-${VERSION}.tar.gz"
    SHA512 014e09a0050f928cf87ed48741daa52eb2b8652785981818e7b9a89578a7cd315a049d6e3aef6914954d1fbfe967d61521028d7b4a3295ddf90f8f243bf318a0
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    PATCHES fix-optional-packages.patch
)

# The release tarball ships pre-generated aclocal.m4/Makefile.in/configure
# files that are older than the m4 files patched above.  Make would then try
# to regenerate them, but a release tarball cannot be regenerated: AC_INIT
# probes the version through config/opal_get_version.sh, which only exists in
# git checkouts.  Refresh the timestamps of the shipped generated files
# (including the embedded PMIx/PRRTE/ROMIO copies), keeping aclocal.m4 older
# than the files generated from it.
file(GLOB_RECURSE openmpi_generated_aclocal LIST_DIRECTORIES false
    "${SOURCE_PATH}/*aclocal.m4"
)
file(GLOB_RECURSE openmpi_generated_files LIST_DIRECTORIES false
    "${SOURCE_PATH}/*Makefile.in"
    "${SOURCE_PATH}/*config.h.in"
    "${SOURCE_PATH}/*configure"
)
if(openmpi_generated_aclocal)
    file(TOUCH ${openmpi_generated_aclocal})
endif()
if(openmpi_generated_files)
    file(TOUCH ${openmpi_generated_files})
endif()

vcpkg_find_acquire_program(PERL)
cmake_path(GET PERL PARENT_PATH PERL_PATH)
vcpkg_add_to_path("${PERL_PATH}")

# Put wrapper data dir side-by-side to wrapper executables dir instead of loosing debug data.
# vcpkg-make appends these to the configuration-specific options.
vcpkg_list(PREPEND VCPKG_MAKE_CONFIGURE_OPTIONS_DEBUG [[--datadir=\${prefix}/../tools/openmpi/debug/share]])
vcpkg_list(PREPEND VCPKG_MAKE_CONFIGURE_OPTIONS_RELEASE [[--datadir=\${prefix}/tools/openmpi/share]])
if(VCPKG_TARGET_IS_OSX)
    # This ensures that vcpkg-fixup-macho-rpath succeeds
    # CoreFoundation and IOKit are transitive dependencies of static hwloc,
    # but hwloc.pc does not report them.
    string(APPEND VCPKG_LINKER_FLAGS " -headerpad_max_install_names -framework CoreFoundation -framework IOKit")
endif()

set(OPENMPI_FEATURE_OPTIONS)
set(OPENMPI_FEATURE_OPTIONS_DEBUG)
set(OPENMPI_FEATURE_OPTIONS_RELEASE)
set(OPENMPI_LANGUAGES C CXX)
vcpkg_backup_env_variables(VARS PKG_CONFIG_PATH)
include("${CURRENT_PORT_DIR}/feature-options.cmake")
if("fortran" IN_LIST FEATURES)
    # vcpkg-make does not forward a Fortran compiler or FCFLAGS itself.
    # Detect them with the target toolchain, including when cross-compiling.
    vcpkg_cmake_get_vars(fortran_vars ADDITIONAL_LANGUAGES Fortran)
    include("${fortran_vars}")
    list(APPEND OPENMPI_LANGUAGES Fortran)
    list(APPEND OPENMPI_FEATURE_OPTIONS
        --enable-mpi-fortran=yes
        "FC=${VCPKG_DETECTED_CMAKE_Fortran_COMPILER}"
    )
    foreach(config IN ITEMS DEBUG RELEASE)
        list(APPEND OPENMPI_FEATURE_OPTIONS_${config}
            "FCFLAGS=${VCPKG_COMBINED_Fortran_FLAGS_${config}}"
        )
    endforeach()
else()
    list(APPEND OPENMPI_FEATURE_OPTIONS --enable-mpi-fortran=no)
endif()

vcpkg_make_configure(
    COPY_SOURCE
    SOURCE_PATH "${SOURCE_PATH}"
    LANGUAGES ${OPENMPI_LANGUAGES}
    OPTIONS
        --disable-dependency-tracking
        "--with-hwloc=${CURRENT_INSTALLED_DIR}"
        "--with-libevent=${CURRENT_INSTALLED_DIR}"
        --with-pmix=internal
        --with-prrte=internal
        --without-libev
        ${OPENMPI_FEATURE_OPTIONS}
    OPTIONS_DEBUG
        --enable-debug
        "--with-hwloc-libdir=${CURRENT_INSTALLED_DIR}/debug/lib"
        "--with-libevent-libdir=${CURRENT_INSTALLED_DIR}/debug/lib"
        ${OPENMPI_FEATURE_OPTIONS_DEBUG}
    OPTIONS_RELEASE
        "--with-hwloc-libdir=${CURRENT_INSTALLED_DIR}/lib"
        "--with-libevent-libdir=${CURRENT_INSTALLED_DIR}/lib"
        ${OPENMPI_FEATURE_OPTIONS_RELEASE}
)
vcpkg_make_install()
vcpkg_restore_env_variables(VARS PKG_CONFIG_PATH)
vcpkg_fixup_pkgconfig()

# pmix_config.h records the configure command line. Redact its build-machine
# paths without changing the generated C string syntax.
foreach(dir IN ITEMS "" "debug/")
    set(pmix_config "${CURRENT_PACKAGES_DIR}/${dir}include/pmix/src/include/pmix_config.h")
    if(EXISTS "${pmix_config}")
        foreach(abs_path IN ITEMS
            "${CURRENT_PACKAGES_DIR}"
            "${CURRENT_BUILDTREES_DIR}"
            "${CURRENT_INSTALLED_DIR}"
            "${DOWNLOADS}"
        )
            if(NOT abs_path STREQUAL "")
                vcpkg_replace_string(
                    "${pmix_config}"
                    "${abs_path}"
                    "VCPKG_REDACTED_PATH"
                    IGNORE_UNCHANGED
                )
            endif()
        endforeach()
    endif()
endforeach()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

configure_file("${CURRENT_PORT_DIR}/mpi-wrapper.cmake" "${CURRENT_PACKAGES_DIR}/share/${PORT}/mpi-wrapper.cmake" @ONLY)

vcpkg_install_copyright(FILE_LIST
    "${SOURCE_PATH}/LICENSE"
    "${SOURCE_PATH}/docs/license/mpich.txt"
    "${SOURCE_PATH}/3rd-party/openpmix/LICENSE"
    "${SOURCE_PATH}/3rd-party/prrte/LICENSE"
    "${SOURCE_PATH}/3rd-party/treematch/LICENSE"
    "${SOURCE_PATH}/3rd-party/treematch/COPYING"
)
