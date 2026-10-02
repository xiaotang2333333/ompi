set(LIBSYSTEMD_PATCHES
  disable-warning-nonnull.patch
  only-libsystemd.patch
  pkgconfig.patch
  fix-2604-build.patch
)
if("libudev" IN_LIST FEATURES)
  list(APPEND LIBSYSTEMD_PATCHES enable-libudev.patch)
endif()

vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO systemd/systemd
  REF "v${VERSION}"
  SHA512 63d15da49e7580952a48a0b50df20c1b398e4b77edf259510b0cdb9022e919387baadf2190194a50f1f582b83e0768c13997a4189cf0fb6a61b65015496d9c80
  PATCHES
    ${LIBSYSTEMD_PATCHES}
)

set(static false)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
  set(static pic)
endif()

set(LIBSYSTEMD_MESON_OPTIONS
  -Dmode=release
  -Dstatic-libsystemd=${static}
  -Dtests=false
  -Ddns-over-tls=false
  -Dtranslations=false
  -Dacl=disabled
  -Dapparmor=disabled
  -Daudit=disabled
  -Dblkid=disabled
  -Dbpf-framework=disabled
  -Dbzip2=disabled
  -Ddbus=disabled
  -Delfutils=disabled
  -Dfdisk=disabled
  -Dgcrypt=disabled
  -Dglib=disabled
  -Dgnutls=disabled
  -Dkmod=disabled
  -Dlibcurl=disabled
  -Dlibcryptsetup=disabled
  -Dlibfido2=disabled
  -Dlibidn=disabled
  -Dlibidn2=disabled
  -Dlibiptc=disabled
  -Dmicrohttpd=disabled
  -Dopenssl=disabled
  -Dp11kit=disabled
  -Dpam=disabled
  -Dpcre2=disabled
  -Dpolkit=disabled
  -Dpwquality=disabled
  -Dpasswdqc=disabled
  -Dseccomp=disabled
  -Dselinux=disabled
  -Dtpm2=disabled
  -Dxenctrl=disabled
  -Dxkbcommon=disabled
  -Dzlib=disabled
  -Dlz4=enabled
  -Dxz=enabled
  -Dzstd=enabled
)
if("libudev" IN_LIST FEATURES)
  list(APPEND LIBSYSTEMD_MESON_OPTIONS -Dstatic-libudev=${static})
endif()

vcpkg_find_acquire_program(PYTHON3)
x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PYTHON_EXECUTABLE "${PYTHON3}"
    PACKAGES "jinja2"
)

vcpkg_configure_meson(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    ${LIBSYSTEMD_MESON_OPTIONS}
  ADDITIONAL_BINARIES
    "gperf = ['${CURRENT_HOST_INSTALLED_DIR}/tools/gperf/gperf${VCPKG_HOST_EXECUTABLE_SUFFIX}']"
)

vcpkg_install_meson()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_fixup_pkgconfig()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSES/README.md" "${SOURCE_PATH}/LICENSE.LGPL2.1"
  COMMENT [[
This port provides libsystemd.so/.a, which is based on sources in
src/basic, src/fundamental, src/systemd and src/libsystemd.

The libudev feature additionally provides libudev.so/.a, which is based on
sources in src/libudev and the same src/basic and src/systemd code.
]])
