vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/thom311/libnl/releases/download/libnl3_12_0/libnl-${VERSION}.tar.gz"
    FILENAME "libnl-${VERSION}.tar.gz"
    SHA512 6230b8cab608355346030cf32f37c43983b1d1b632cb7677ae383d4f2369b4a3773b35d2d51007d3b9c16f333aaf351682c4602b3d229cd602eec5ad53efd6f3
)

vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

# The release tarball marks the route parser sources as nodist, so flex and
# bison are required to generate lib/route/{pktloc_*,ematch_*}.c (same as the
# upstream and distribution builds).
find_program(FLEX NAMES flex)
find_program(BISON NAMES bison)
if(NOT FLEX OR NOT BISON)
    message(FATAL_ERROR
        "libnl requires flex and bison to build its route parser.\n"
        "On Debian and Ubuntu derivatives: sudo apt install flex bison\n"
        "On recent Red Hat and Fedora derivatives: sudo dnf install flex bison\n"
        "On Arch Linux and derivatives: sudo pacman -S flex bison")
endif()

# --disable-cli keeps every command line utility out of the build; the
# remaining libraries (core, route, genl, nf, xfrm, idiag) are all built from
# the single upstream Makefile.am because libnl has no per-library switch.
# Open MPI only consumes core and route.
vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        --disable-cli
        --disable-dependency-tracking
)
vcpkg_make_install()
vcpkg_fixup_pkgconfig()

# /etc/libnl (pktloc/classid tables) is not relocatable and unused by Open MPI.
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/etc"
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/etc"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
