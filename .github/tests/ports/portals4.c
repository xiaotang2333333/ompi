#include <portals4.h>

#include <stdio.h>

int main(void)
{
    int ret;

    ret = PtlInit();
    if (ret != PTL_OK) {
        fprintf(stderr,
                "PtlInit failed: %d (PTL_NO_INIT=%d); the UDP reference "
                "library needs one interface with an IPv4 address (eth0..eth99 "
                "scan, or set PTL_IFACE_NAME)\n",
                ret, PTL_NO_INIT);
        return 1;
    }

    PtlFini();

    printf("Portals4 PtlInit/PtlFini public API passed (UDP transport)\n");
    return 0;
}
