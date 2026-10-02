#include <pvfs2.h>

#include <stdint.h>
#include <stdio.h>

#if PVFS2_VERSION_MAJOR != 2 || PVFS2_VERSION_MINOR != 10
#error "unexpected installed OrangeFS/PVFS2 version"
#endif

int main(void)
{
    PVFS_hint hint = PVFS_HINT_NULL;
    PVFS_hint copy = PVFS_HINT_NULL;
    uint32_t rank = 3;
    int ret;

    ret = PVFS_hint_add(&hint, PVFS_HINT_RANK_NAME, (int)sizeof(rank), &rank);
    if (ret != 0 || hint == PVFS_HINT_NULL) {
        fprintf(stderr, "PVFS_hint_add(rank) failed: ret=%d hint=%p\n", ret,
                (void *)hint);
        return 1;
    }

    rank = 4;
    ret = PVFS_hint_add(&hint, PVFS_HINT_RANK_NAME, (int)sizeof(rank), &rank);
    if (ret != -PVFS_EEXIST) {
        fprintf(stderr,
                "PVFS_hint_add(duplicate rank) mismatch: ret=%d, expected %d\n",
                ret, -PVFS_EEXIST);
        return 1;
    }

    if (PVFS_hint_check(&hint, PVFS_HINT_RANK_NAME) != -PVFS_EEXIST) {
        fprintf(stderr, "PVFS_hint_check(rank) did not report the added hint\n");
        return 1;
    }

    if (PVFS_hint_check_transfer(&hint) != 1) {
        fprintf(stderr, "PVFS_hint_check_transfer(rank) mismatch: expected 1\n");
        return 1;
    }

    ret = PVFS_hint_copy(hint, &copy);
    if (ret != 0 || copy == PVFS_HINT_NULL) {
        fprintf(stderr, "PVFS_hint_copy failed: ret=%d copy=%p\n", ret,
                (void *)copy);
        return 1;
    }

    ret = PVFS_hint_replace(&hint, PVFS_HINT_RANK_NAME, (int)sizeof(rank),
                            &rank);
    if (ret != 0) {
        fprintf(stderr, "PVFS_hint_replace(rank) failed: ret=%d\n", ret);
        return 1;
    }

    PVFS_hint_free(&hint);
    if (hint != PVFS_HINT_NULL) {
        fprintf(stderr, "PVFS_hint_free did not clear the hint pointer\n");
        return 1;
    }

    PVFS_hint_free(&copy);
    if (copy != PVFS_HINT_NULL) {
        fprintf(stderr, "PVFS_hint_free(copy) did not clear the hint pointer\n");
        return 1;
    }

    printf("PVFS2/OrangeFS hint API passed (2.10.%d, no server contact)\n",
           PVFS2_VERSION_SUB);
    return 0;
}
