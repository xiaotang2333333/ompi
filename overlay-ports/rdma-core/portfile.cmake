vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO linux-rdma/rdma-core
    REF "v${VERSION}"
    SHA512 83bf1c9a64f83fba6001b5df10de2d5c8887dbe6ac4032b6fdcedd385e4d5e3345411eee17c94675a9c4ea4fc30c30d89c5fea1b1eb6b2dad34354285c90aeef
    HEAD_REF master
    PATCHES
        0001-disable-tests.patch
        0002-disable-examples.patch
        0003-disable-documentation.patch
        0004-disable-infiniband-diags.patch
        0005-disable-srp-daemon.patch
        0006-disable-kernel-boot.patch
        0007-disable-librspreload.patch
        0008-enable-static-libs-only.patch
)

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "static" ENABLE_STATIC)

if("neighbor-resolution" IN_LIST FEATURES)
    set(ENABLE_RESOLVE_NEIGH ON)
else()
    set(ENABLE_RESOLVE_NEIGH OFF)
endif()

vcpkg_get_vcpkg_installed_python(PYTHON3)
vcpkg_find_acquire_program(PKGCONFIG)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DENABLE_RESOLVE_NEIGH=${ENABLE_RESOLVE_NEIGH}
        -DNO_MAN_PAGES=ON
        -DNO_PYVERBS=ON
        -DENABLE_STATIC="${ENABLE_STATIC}"
        # rdma-core 65.0 unconditionally installs rdma-sysusers.conf to
        # ${SYSUSERS_DIR} (default /usr/lib/sysusers.d, an absolute host path).
        # Point it at a scratch directory inside the package so the install
        # cannot write outside the package tree; it is removed below because
        # this port packages libraries and headers only.
        -DSYSUSERS_DIR=${CURRENT_PACKAGES_DIR}/share/rdma-core/sysusers.d
        -DVCPKG_LOCK_FIND_PACKAGE_PythonLibs=ON
        -DVCPKG_LOCK_FIND_PACKAGE_Systemd=OFF
        -DVCPKG_LOCK_FIND_PACKAGE_UDev=OFF
        -DVCPKG_LOCK_FIND_PACKAGE_cython=OFF
        -DVCPKG_LOCK_FIND_PACKAGE_pandoc=OFF
        -DVCPKG_LOCK_FIND_PACKAGE_rst2man=OFF
        -DPython_EXECUTABLE=${PYTHON3}
        -DPKG_CONFIG_EXECUTABLE=${PKGCONFIG}
    MAYBE_UNUSED_VARIABLES
        PKG_CONFIG_EXECUTABLE
        VCPKG_LOCK_FIND_PACKAGE_PythonLibs
        VCPKG_LOCK_FIND_PACKAGE_cython
        VCPKG_LOCK_FIND_PACKAGE_pandoc
        VCPKG_LOCK_FIND_PACKAGE_rst2man
)

vcpkg_cmake_install()

vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/etc")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/libexec")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/etc")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/libexec")

# Library/header packaging: drop the v65 systemd sysusers snippet and, when
# neighbor resolution is enabled, the upstream daemons and their system
# integration files. The libraries (including the ibacmp provider plugin) are
# kept.
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/share/rdma-core/sysusers.d")
if("neighbor-resolution" IN_LIST FEATURES)
    # ibacm/iwpmd are installed to sbin (rdma_sbin_executable); ib_acme is the
    # only bin tool built by the ibacm subdirectory.
    file(REMOVE
        "${CURRENT_PACKAGES_DIR}/bin/ib_acme"
        "${CURRENT_PACKAGES_DIR}/debug/bin/ib_acme"
    )
    file(REMOVE_RECURSE
        "${CURRENT_PACKAGES_DIR}/sbin"
        "${CURRENT_PACKAGES_DIR}/debug/sbin"
        "${CURRENT_PACKAGES_DIR}/lib/udev"
        "${CURRENT_PACKAGES_DIR}/debug/lib/udev"
        "${CURRENT_PACKAGES_DIR}/lib/systemd"
        "${CURRENT_PACKAGES_DIR}/debug/lib/systemd"
    )
endif()

if("kernel-headers" IN_LIST FEATURES)
    # Public Linux UAPI headers mirrored from the kernel tree by
    # kernel-headers/update. Install only the rdma/** subtree: PSM2 needs
    # <rdma/hfi/hfi1_user.h> plus its transitive includes (rdma_user_ioctl.h,
    # hfi1_ioctl.h, ib_user_mad.h, rdma_user_ioctl_cmds.h). The linux/**
    # subset stays internal so the toolchain's <linux/...> headers are not
    # shadowed. No kernel modules, daemons or tools are added.
    file(INSTALL "${SOURCE_PATH}/kernel-headers/rdma"
         DESTINATION "${CURRENT_PACKAGES_DIR}/include")
endif()

set(RDMA_CORE_COPYRIGHT_FILES
    "${SOURCE_PATH}/COPYING.md"
    "${SOURCE_PATH}/COPYING.BSD_MIT"
    "${SOURCE_PATH}/COPYING.GPL2"
    "${SOURCE_PATH}/ccan/LICENSE.CCO"
    "${SOURCE_PATH}/ccan/LICENSE.MIT"
    "${SOURCE_PATH}/providers/hfi1verbs/hfiverbs.h"
    "${SOURCE_PATH}/providers/ipathverbs/COPYING"
    "${SOURCE_PATH}/COPYING.BSD_FB"
)
if("kernel-headers" IN_LIST FEATURES)
    # Shipped UAPI headers carry their own SPDX terms:
    #   hfi1_user.h:      ((GPL-2.0 WITH Linux-syscall-note) OR BSD-3-Clause)
    #   rdma_user_ioctl.h ((GPL-2.0 WITH Linux-syscall-note) OR Linux-OpenIB)
    list(APPEND RDMA_CORE_COPYRIGHT_FILES
        "${SOURCE_PATH}/kernel-headers/rdma/hfi/hfi1_user.h"
        "${SOURCE_PATH}/kernel-headers/rdma/rdma_user_ioctl.h"
    )
endif()
vcpkg_install_copyright(FILE_LIST ${RDMA_CORE_COPYRIGHT_FILES})
