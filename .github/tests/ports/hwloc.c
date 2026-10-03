/* Smoke consumer for the hwloc overlay port: exercise the public topology
   API so that both the installed headers and the built library are verified. */
#include <stdio.h>
#include <stdlib.h>

#include <hwloc.h>

int main(void)
{
    hwloc_topology_t topology;
    int depth;

    if (hwloc_topology_init(&topology) != 0) {
        fprintf(stderr, "hwloc_topology_init failed\n");
        return EXIT_FAILURE;
    }
    if (hwloc_topology_load(topology) != 0) {
        fprintf(stderr, "hwloc_topology_load failed\n");
        hwloc_topology_destroy(topology);
        return EXIT_FAILURE;
    }

    depth = (int) hwloc_topology_get_depth(topology);
    if (depth <= 0) {
        fprintf(stderr, "unexpected topology depth %d\n", depth);
        hwloc_topology_destroy(topology);
        return EXIT_FAILURE;
    }

    printf("hwloc api=0x%x: depth=%d root_objects=%u\n", hwloc_get_api_version(),
           depth, hwloc_get_nbobjs_by_depth(topology, 0));

    hwloc_topology_destroy(topology);
    return EXIT_SUCCESS;
}
