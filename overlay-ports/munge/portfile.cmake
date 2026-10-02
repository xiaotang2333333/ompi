vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/dun/munge/releases/download/munge-${VERSION}/munge-${VERSION}.tar.xz"
    FILENAME "munge-${VERSION}.tar.xz"
    SHA512 b7f0badfcde54786e330c8bc3fe625c99818cd154654a111f3a05462b0002394ee7581e7005eae4849bac98f4287650bf38050720bd522aa0a445d118b65bc29
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
)

set(MUNGE_CRYPTO_PREFIX "${CURRENT_INSTALLED_DIR}")
if(CMAKE_HOST_WIN32)
    string(REGEX REPLACE "^([a-zA-Z]):/" "/\\1/" MUNGE_CRYPTO_PREFIX "${MUNGE_CRYPTO_PREFIX}")
endif()

vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        # Use the vcpkg OpenSSL instead of probing the build machine.
        --with-crypto-lib=openssl
        # Do not install service/config files for the build machine's init system.
        --with-systemdunitdir=no
        --with-systemdsysusersdir=no
        --with-sysvinitddir=no
        --with-sysconfigdir=no
        --with-logrotateddir=no
        # Keep the compiled-in client socket out of the relocated install prefix.
        --with-runstatedir=/run
    OPTIONS_RELEASE
        "--with-openssl-prefix=${MUNGE_CRYPTO_PREFIX}"
        "--with-pkgconfigdir=${MUNGE_CRYPTO_PREFIX}/lib/pkgconfig"
    OPTIONS_DEBUG
        "--with-openssl-prefix=${MUNGE_CRYPTO_PREFIX}/debug"
        "--with-pkgconfigdir=${MUNGE_CRYPTO_PREFIX}/debug/lib/pkgconfig"
)
vcpkg_make_install()
vcpkg_fixup_pkgconfig()

# The upstream install hooks create /etc, /var and /run subtrees even when the
# matching service files are disabled; none of them belong in the package.
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/etc"
    "${CURRENT_PACKAGES_DIR}/run"
    "${CURRENT_PACKAGES_DIR}/var"
    "${CURRENT_PACKAGES_DIR}/debug/etc"
    "${CURRENT_PACKAGES_DIR}/debug/run"
    "${CURRENT_PACKAGES_DIR}/debug/var"
)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST
    "${SOURCE_PATH}/COPYING"
    "${SOURCE_PATH}/COPYING.LESSER"
)
