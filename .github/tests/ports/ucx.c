#include <ucp/api/ucp.h>

#include <stdio.h>
#include <string.h>

#if UCP_API_MAJOR != 1 || UCP_API_MINOR != 22
#error "unexpected installed UCX UCP API version"
#endif

int main(void)
{
    unsigned major_version = 0;
    unsigned minor_version = 0;
    unsigned release_number = 0;
    const char *version_string;

    ucp_get_version(&major_version, &minor_version, &release_number);
    version_string = ucp_get_version_string();

    if (major_version != 1 || minor_version != 22 || release_number != 0) {
        fprintf(stderr,
                "ucp_get_version mismatch: got %u.%u.%u, expected 1.22.0\n",
                major_version, minor_version, release_number);
        return 1;
    }

    if (version_string == NULL) {
        fprintf(stderr, "ucp_get_version_string returned NULL\n");
        return 1;
    }

    if (strcmp(version_string, "1.22.0") != 0) {
        fprintf(stderr,
                "ucp_get_version_string mismatch: got '%s', expected '1.22.0'\n",
                version_string);
        return 1;
    }

    printf("UCX public get-version API passed: %s (%u.%u.%u)\n", version_string,
           major_version, minor_version, release_number);
    return 0;
}
