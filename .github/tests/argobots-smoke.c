#include <abt.h>
#include <stdio.h>

#define CHECK(call)                                                        \
    do {                                                                   \
        int code = (call);                                                  \
        if (code != ABT_SUCCESS) {                                         \
            fprintf(stderr, "%s failed: %d\n", #call, code);               \
            return 1;                                                      \
        }                                                                  \
    } while (0)

static void work(void *argument)
{
    *(int *)argument = 42;
}

int main(int argc, char **argv)
{
    ABT_xstream xstream;
    ABT_pool pool;
    ABT_thread thread;
    int value = 0;

    CHECK(ABT_init(argc, argv));
    CHECK(ABT_xstream_self(&xstream));
    CHECK(ABT_xstream_get_main_pools(xstream, 1, &pool));
    CHECK(ABT_thread_create(pool, work, &value, ABT_THREAD_ATTR_NULL, &thread));
    CHECK(ABT_thread_join(thread));
    CHECK(ABT_thread_free(&thread));
    CHECK(ABT_finalize());

    if (value != 42) {
        fprintf(stderr, "Argobots thread did not execute\n");
        return 1;
    }
    puts("Argobots thread smoke test passed");
    return 0;
}
