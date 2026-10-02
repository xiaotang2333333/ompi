#include <xpmem.h>

#include <stddef.h>
#include <stdio.h>
#include <string.h>

static int (*volatile xpmem_version_ref)(void) = xpmem_version;
static xpmem_segid_t (*volatile xpmem_make_ref)(void *vaddr, size_t size,
                                                int permit_type, void *permit_value) = xpmem_make;
static int (*volatile xpmem_remove_ref)(xpmem_segid_t segid) = xpmem_remove;
static xpmem_apid_t (*volatile xpmem_get_ref)(xpmem_segid_t segid, int flags,
                                              int permit_type, void *permit_value) = xpmem_get;
static int (*volatile xpmem_release_ref)(xpmem_apid_t apid) = xpmem_release;
static void *(*volatile xpmem_attach_ref)(struct xpmem_addr addr, size_t size,
                                          void *vaddr) = xpmem_attach;
static int (*volatile xpmem_detach_ref)(void *vaddr) = xpmem_detach;

#if defined(__GNUC__)
_Static_assert(__builtin_types_compatible_p(__typeof__(xpmem_version), int (void)),
               "xpmem_version signature mismatch against xpmem.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(xpmem_make),
                                            xpmem_segid_t (void *, size_t, int, void *)),
               "xpmem_make signature mismatch against xpmem.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(xpmem_remove),
                                            int (xpmem_segid_t)),
               "xpmem_remove signature mismatch against xpmem.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(xpmem_get),
                                            xpmem_apid_t (xpmem_segid_t, int, int, void *)),
               "xpmem_get signature mismatch against xpmem.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(xpmem_release),
                                            int (xpmem_apid_t)),
               "xpmem_release signature mismatch against xpmem.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(xpmem_attach),
                                            void *(struct xpmem_addr, size_t, void *)),
               "xpmem_attach signature mismatch against xpmem.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(xpmem_detach),
                                            int (void *)),
               "xpmem_detach signature mismatch against xpmem.h");
#endif

static int expect(int condition, const char *what)
{
    if (!condition)
        fprintf(stderr, "xpmem: check failed: %s\n", what);
    return condition ? 0 : 1;
}

int main(void)
{
    int failures = 0;
    struct xpmem_addr address;

    failures += expect(xpmem_version_ref != NULL &&
                       xpmem_make_ref != NULL && xpmem_remove_ref != NULL &&
                       xpmem_get_ref != NULL && xpmem_release_ref != NULL &&
                       xpmem_attach_ref != NULL && xpmem_detach_ref != NULL,
                       "libxpmem exports xpmem_version/make/remove/get/release/attach/detach");

    failures += expect(XPMEM_MAXADDR_SIZE == (size_t)-1, "XPMEM_MAXADDR_SIZE value");
    failures += expect(XPMEM_ERRNO_NOPROC == 2004, "XPMEM_ERRNO_NOPROC value");
    failures += expect(XPMEM_RDONLY == 0x1 && XPMEM_RDWR == 0x2, "XPMEM permission flags");
    failures += expect(XPMEM_PERMIT_MODE == 0x1, "XPMEM_PERMIT_MODE value");

    failures += expect(sizeof(xpmem_segid_t) == 8 && sizeof(xpmem_apid_t) == 8,
                       "xpmem_segid_t and xpmem_apid_t are 64-bit");
    failures += expect((xpmem_segid_t)-1 < 0 && (xpmem_apid_t)-1 < 0,
                       "xpmem_segid_t and xpmem_apid_t are signed");

    failures += expect(offsetof(struct xpmem_addr, apid) == 0,
                       "struct xpmem_addr.apid is first");
    failures += expect(offsetof(struct xpmem_addr, offset) == sizeof(xpmem_apid_t),
                       "struct xpmem_addr.offset follows apid");
    failures += expect(sizeof(struct xpmem_addr) ==
                       offsetof(struct xpmem_addr, offset) + sizeof(off_t),
                       "struct xpmem_addr layout");

    memset(&address, 0, sizeof(address));
    address.apid = (xpmem_apid_t)4096;
    address.offset = (off_t)8192;
    failures += expect(address.apid == (xpmem_apid_t)4096 &&
                       address.offset == (off_t)8192,
                       "struct xpmem_addr field round-trip");

    if (failures != 0) {
        fprintf(stderr, "xpmem: %d check(s) failed\n", failures);
        return 1;
    }

    printf("XPMEM userspace library smoke test passed (symbols linked, no /dev/xpmem access)\n");
    return 0;
}
