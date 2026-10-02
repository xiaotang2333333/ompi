#include <stdint.h>

#include <valgrind/valgrind.h>
#include <valgrind/memcheck.h>

#include <stdio.h>
#include <string.h>

#if !defined(__VALGRIND_MAJOR__) || !defined(__VALGRIND_MINOR__)
#error "valgrind.h does not provide __VALGRIND_MAJOR__/__VALGRIND_MINOR__"
#endif

#if __VALGRIND_MAJOR__ < 3 || (__VALGRIND_MAJOR__ == 3 && __VALGRIND_MINOR__ < 6)
#error "Valgrind client-request headers older than 3.6 are not supported"
#endif

static int expect(int condition, const char *what)
{
    if (!condition)
        fprintf(stderr, "valgrind: check failed: %s\n", what);
    return condition ? 0 : 1;
}

int main(void)
{
    int failures = 0;
    unsigned char byte = 0x5a;
    unsigned char vbits[sizeof(byte)];
    unsigned long leaked = 0;
    unsigned long dubious = 0;
    unsigned long reachable = 0;
    unsigned long suppressed = 0;
    unsigned int running = RUNNING_ON_VALGRIND;
    unsigned int addressable;
    unsigned int defined;
    unsigned int vbits_result;
    unsigned int errors;

    failures += expect(running <= 8u, "RUNNING_ON_VALGRIND returned a plausible nesting count");

    addressable = VALGRIND_CHECK_MEM_IS_ADDRESSABLE(&byte, sizeof(byte));
    failures += expect(addressable == 0, "VALGRIND_CHECK_MEM_IS_ADDRESSABLE is benign (0)");

    defined = VALGRIND_CHECK_MEM_IS_DEFINED(&byte, sizeof(byte));
    failures += expect(defined == 0, "VALGRIND_CHECK_MEM_IS_DEFINED is benign (0)");

    VALGRIND_MAKE_MEM_UNDEFINED(&byte, sizeof(byte));
    VALGRIND_MAKE_MEM_DEFINED(&byte, sizeof(byte));
    failures += expect(VALGRIND_CHECK_MEM_IS_DEFINED(&byte, sizeof(byte)) == 0,
                       "VALGRIND_MAKE_MEM_DEFINED leaves defined memory");

    memset(vbits, 0xa5, sizeof(vbits));
    vbits_result = VALGRIND_GET_VBITS(&byte, vbits, sizeof(byte));
    if (running == 0u) {
        failures += expect(vbits_result == 0,
                           "VALGRIND_GET_VBITS defaults to 0 outside Valgrind");
    } else {
        failures += expect(vbits_result == 1,
                           "VALGRIND_GET_VBITS succeeds under Valgrind");
        failures += expect(vbits[0] == 0x00,
                           "defined byte has no undefined bits under Valgrind");
    }

    VALGRIND_COUNT_LEAKS(leaked, dubious, reachable, suppressed);
    if (running == 0u) {
        failures += expect(leaked == 0 && dubious == 0 && reachable == 0 && suppressed == 0,
                           "VALGRIND_COUNT_LEAKS defaults to 0 outside Valgrind");
    }

    errors = VALGRIND_COUNT_ERRORS;
    failures += expect(errors == 0, "VALGRIND_COUNT_ERRORS is 0");

    VALGRIND_DO_LEAK_CHECK;

    if (failures != 0) {
        fprintf(stderr, "valgrind: %d check(s) failed\n", failures);
        return 1;
    }

    printf("Valgrind client-request header smoke test passed (headers %d.%d, RUNNING_ON_VALGRIND=%u)\n",
           __VALGRIND_MAJOR__, __VALGRIND_MINOR__, running);
    return 0;
}
