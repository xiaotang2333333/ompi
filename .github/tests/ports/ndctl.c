#include <daxctl/libdaxctl.h>
#include <ndctl/libndctl.h>

#include <stdio.h>

static int expect(int condition, const char *what)
{
    if (!condition)
        fprintf(stderr, "ndctl: check failed: %s\n", what);
    return condition ? 0 : 1;
}

int main(void)
{
    struct ndctl_ctx *ndctx = NULL;
    struct daxctl_ctx *daxctx = NULL;
    struct ndctl_bus *bus;
    struct daxctl_region *region;
    unsigned int bus_count = 0;
    unsigned int region_count = 0;
    int failures = 0;

    if (ndctl_new(&ndctx) != 0 || ndctx == NULL) {
        fprintf(stderr, "ndctl: ndctl_new failed\n");
        return 1;
    }

    if (daxctl_new(&daxctx) != 0 || daxctx == NULL) {
        fprintf(stderr, "ndctl: daxctl_new failed\n");
        ndctl_unref(ndctx);
        return 1;
    }

    ndctl_bus_foreach(ndctx, bus) {
        failures += expect(ndctl_bus_get_ctx(bus) == ndctx,
                           "ndctl_bus_get_ctx returns the owning context");
        failures += expect(ndctl_bus_get_provider(bus) != NULL,
                           "ndctl_bus_get_provider returns a provider name");
        bus_count++;
    }

    for (region = daxctl_region_get_first(daxctx); region != NULL;
         region = daxctl_region_get_next(region)) {
        failures += expect(daxctl_region_get_ctx(region) == daxctx,
                           "daxctl_region_get_ctx returns the owning context");
        failures += expect(daxctl_region_get_devname(region) != NULL,
                           "daxctl_region_get_devname returns a device name");
        region_count++;
    }

    daxctl_unref(daxctx);
    ndctl_unref(ndctx);

    if (failures != 0) {
        fprintf(stderr, "ndctl: %d check(s) failed\n", failures);
        return 1;
    }

    printf("ndctl/libdaxctl context + enumeration smoke test passed "
           "(%u nd bus(es), %u dax region(s); no memory state changed)\n",
           bus_count, region_count);
    return 0;
}
