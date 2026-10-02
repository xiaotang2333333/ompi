#include <qthread/qthread.h>
#include <stdio.h>

#define CHECK(call)                                                            \
    do {                                                                       \
        int const rc_ = (call);                                                \
        if (rc_ != QTHREAD_SUCCESS) {                                          \
            fprintf(stderr, "%s failed: %d\n", #call, rc_);                    \
            return 1;                                                          \
        }                                                                      \
    } while (0)

static aligned_t return_42(void *arg)
{
    (void)arg;
    return 42;
}

int main(void)
{
    aligned_t ret = 0;
    aligned_t value = 0;

    CHECK(qthread_initialize());
    CHECK(qthread_fork(return_42, NULL, &ret));
    CHECK(qthread_readFF(&value, &ret));

    if (value != 42) {
        fprintf(stderr, "task returned %lu, expected 42\n",
                (unsigned long)value);
        return 1;
    }

    qthread_finalize();
    puts("qthreads smoke test passed");
    return 0;
}
