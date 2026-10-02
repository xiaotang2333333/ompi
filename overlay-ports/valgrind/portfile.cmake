vcpkg_download_distfile(ARCHIVE
    URLS "https://sourceware.org/pub/valgrind/valgrind-${VERSION}.tar.bz2"
    FILENAME "valgrind-${VERSION}.tar.bz2"
    SHA512 4522e345fe31bc10478f21ab261cf7b3e509d80fe98fd0c7c9778ac9a9f90e1d8fa6e54a37c2e23114c01c95131035103fc1e78661710d7f45f5d564a31c1015
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

# Header-only: Open MPI's memchecker includes <valgrind/valgrind.h> and
# <valgrind/memcheck.h> and does not link against any Valgrind library.
file(INSTALL
    "${SOURCE_PATH}/include/valgrind.h"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include/valgrind"
    RENAME "valgrind.h"
)
file(INSTALL
    "${SOURCE_PATH}/memcheck/memcheck.h"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include/valgrind"
    RENAME "memcheck.h"
)

# These two headers have their own permissive license, not Valgrind's GPL.
set(client_header_licenses "")
foreach(header IN ITEMS include/valgrind.h memcheck/memcheck.h)
    file(READ "${SOURCE_PATH}/${header}" contents)
    string(FIND "${contents}" "*/" license_end)
    if(license_end EQUAL -1)
        message(FATAL_ERROR "Could not locate the client-header license in ${header}")
    endif()
    math(EXPR license_end "${license_end} + 2")
    string(SUBSTRING "${contents}" 0 "${license_end}" license)
    string(APPEND client_header_licenses "${header}\n${license}\n\n")
endforeach()
file(WRITE "${CURRENT_BUILDTREES_DIR}/client-headers-license.txt" "${client_header_licenses}")
vcpkg_install_copyright(FILE_LIST "${CURRENT_BUILDTREES_DIR}/client-headers-license.txt")
