vcpkg_download_distfile(ARCHIVE
    URLS "https://gitlab.inria.fr/knem/knem/uploads//4a43e3eb860cda2bbd5bf5c7c04a24b6/knem-${VERSION}.tar.gz"
    FILENAME "knem-${VERSION}.tar.gz"
    SHA512 4f142a910ac51a590952aa1f36010fc2a1361162a0d5fd98f47d1c90dedbb293d56bd990bded5d4ec91fcc8df3fa3bcf0d126651b5868c557ffb9f3a588cb948
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
)

file(INSTALL "${SOURCE_PATH}/common/knem_io.h"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
)

vcpkg_install_copyright(FILE_LIST
    "${SOURCE_PATH}/COPYING"
    "${SOURCE_PATH}/COPYING.BSD-3"
)
