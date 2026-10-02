#include <mpi.h>

#include <stdio.h>
#include <string.h>

static int expect(int condition, const char *what)
{
    if (!condition)
        fprintf(stderr, "openmpi: check failed: %s\n", what);
    return condition ? 0 : 1;
}

int main(int argc, char **argv)
{
    int failures = 0;
    int initialized = -1;
    int finalized = -1;
    int rank = -1;
    int size = -1;
    int version = -1;
    int subversion = -1;
    int namelen = 0;
    char procname[MPI_MAX_PROCESSOR_NAME];
    int rc;

    memset(procname, 0, sizeof(procname));

    rc = MPI_Initialized(&initialized);
    failures += expect(rc == MPI_SUCCESS && initialized == 0,
                       "MPI_Initialized is 0 before MPI_Init");

    rc = MPI_Init(&argc, &argv);
    if (rc != MPI_SUCCESS) {
        fprintf(stderr, "openmpi: MPI_Init failed with %d\n", rc);
        return 1;
    }

    rc = MPI_Initialized(&initialized);
    failures += expect(rc == MPI_SUCCESS && initialized == 1,
                       "MPI_Initialized is 1 after MPI_Init");

    rc = MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    failures += expect(rc == MPI_SUCCESS && rank == 0,
                       "singleton rank is 0");

    rc = MPI_Comm_size(MPI_COMM_WORLD, &size);
    failures += expect(rc == MPI_SUCCESS && size == 1,
                       "singleton size is 1");

    rc = MPI_Get_version(&version, &subversion);
    failures += expect(rc == MPI_SUCCESS &&
                       version == MPI_VERSION && subversion == MPI_SUBVERSION,
                       "MPI_Get_version matches compile-time MPI_VERSION/MPI_SUBVERSION");
    failures += expect(version >= 3, "MPI version is at least 3");

    rc = MPI_Get_processor_name(procname, &namelen);
    failures += expect(rc == MPI_SUCCESS && namelen > 0 &&
                       (size_t)namelen < sizeof(procname) &&
                       procname[namelen] == '\0',
                       "MPI_Get_processor_name returned a NUL-terminated name");

    rc = MPI_Finalize();
    failures += expect(rc == MPI_SUCCESS, "MPI_Finalize returned MPI_SUCCESS");

    rc = MPI_Finalized(&finalized);
    failures += expect(rc == MPI_SUCCESS && finalized == 1,
                       "MPI_Finalized is 1 after MPI_Finalize");

    if (failures != 0) {
        fprintf(stderr, "openmpi: %d check(s) failed\n", failures);
        return 1;
    }

    printf("Open MPI singleton smoke test passed (MPI-%d.%d, rank %d of %d, host %s)\n",
           version, subversion, rank, size, procname);
    return 0;
}
