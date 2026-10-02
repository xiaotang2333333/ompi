vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/waltligon/orangefs/releases/download/${VERSION}/orangefs-${VERSION}.tar.gz"
    FILENAME "orangefs-${VERSION}.tar.gz"
    SHA512 c60c9ae20b9983bb192d7d9f05b59e031b1ee098d98c760a1f01db7e33a98b1d22fb876889d07f6e6e3e500f1b95b4b0378a4fd2f024220c2366d5c7f96e4b2b
)

# statecomp (the build-host state machine compiler) is compiled with
# BUILD_CFLAGS, which only adds the source tree.  pvfs2-config.h is generated
# in the top-level *build* directory, so out-of-tree builds fail with
# "fatal error: pvfs2-config.h: No such file or directory".  Target objects
# already add "-I ."; the patch adds the equivalent -I$(builddir) for
# BUILD_CFLAGS.  We keep the standard out-of-tree build instead of copying the
# whole source tree per configuration (COPY_SOURCE).
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}"
    PATCHES fix-out-of-tree-statecomp.patch
)

# The release tarball ships Makefile.in/module.mk.in but no generated
# configure; regenerate it exactly like the upstream ./prepare script.
vcpkg_execute_required_process(
    COMMAND sh ./prepare
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME "prepare"
)

# Client library and headers only:
#   --disable-server   no pvfs2-server or server-side tools
#   --disable-olib     no liborangefs/libofs wrapper libraries
#   --disable-karma    no GUI (off by default, stated explicitly)
# The kernel module is off by default and must not be requested with
# --without-kernel: OrangeFS treats any --with-kernel/--without-kernel use as a
# source path and aborts when it is not a configured kernel tree.
# No MPI is used anywhere in the client build.
vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        --disable-server
        --disable-olib
        --disable-karma
)
# 'make install' depends on the 'all' target, which also builds the server-side
# user tools. Build only the shared client library and stage it manually.
vcpkg_make_install(TARGETS lib/libpvfs2.so)

string(REGEX REPLACE "\\..*" "" PVFS2_SO_MAJOR "${VERSION}")

foreach(pvfs2_config IN ITEMS rel dbg)
    set(pvfs2_build_dir "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-${pvfs2_config}")
    if(NOT EXISTS "${pvfs2_build_dir}/lib/libpvfs2.so")
        continue()
    endif()
    # The upstream soname is the full version (libpvfs2.so.2.10.1).
    if(pvfs2_config STREQUAL "dbg")
        set(pvfs2_lib_dest "${CURRENT_PACKAGES_DIR}/debug/lib")
    else()
        set(pvfs2_lib_dest "${CURRENT_PACKAGES_DIR}/lib")
    endif()
    file(INSTALL "${pvfs2_build_dir}/lib/libpvfs2.so"
         DESTINATION "${pvfs2_lib_dest}"
         RENAME "libpvfs2.so.${VERSION}")
    file(CREATE_LINK "libpvfs2.so.${VERSION}"
         "${pvfs2_lib_dest}/libpvfs2.so.${PVFS2_SO_MAJOR}"
         SYMBOLIC)
    file(CREATE_LINK "libpvfs2.so.${PVFS2_SO_MAJOR}"
         "${pvfs2_lib_dest}/libpvfs2.so"
         SYMBOLIC)
endforeach()

# Public headers as installed by the upstream install rule, plus the generated
# pvfs2.h (version defines).
set(PVFS2_PUBLIC_HEADERS
    orange.h
    pvfs2-request.h
    pvfs2-debug.h
    pvfs2-sysint.h
    pvfs2-usrint.h
    pvfs2-mgmt.h
    pvfs2-types.h
    pvfs2-util.h
    pvfs2-encode-stubs.h
    pvfs2-hint.h
    pvfs2-compat.h
    pvfs2-mirror.h
)
foreach(pvfs2_header IN LISTS PVFS2_PUBLIC_HEADERS)
    file(INSTALL "${SOURCE_PATH}/include/${pvfs2_header}"
         DESTINATION "${CURRENT_PACKAGES_DIR}/include")
endforeach()
if(EXISTS "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/include/pvfs2.h")
    file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/include/pvfs2.h"
         DESTINATION "${CURRENT_PACKAGES_DIR}/include")
else()
    file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/include/pvfs2.h"
         DESTINATION "${CURRENT_PACKAGES_DIR}/include")
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
