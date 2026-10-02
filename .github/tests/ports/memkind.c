#include <memkind.h>
#include <stdio.h>

int main(void)
{
    enum { BLOCK = 256 };
    unsigned char *buf;
    unsigned char *zeroed;
    int i;

    buf = (unsigned char *)memkind_malloc(MEMKIND_DEFAULT, BLOCK);
    if (buf == NULL) {
        fprintf(stderr, "memkind_malloc(MEMKIND_DEFAULT) returned NULL\n");
        return 1;
    }
    for (i = 0; i < BLOCK; i++) {
        buf[i] = (unsigned char)(i % 251);
    }
    for (i = 0; i < BLOCK; i++) {
        if (buf[i] != (unsigned char)(i % 251)) {
            fprintf(stderr, "DEFAULT allocation mismatch at byte %d\n", i);
            memkind_free(MEMKIND_DEFAULT, buf);
            return 1;
        }
    }
    memkind_free(MEMKIND_DEFAULT, buf);

    zeroed = (unsigned char *)memkind_calloc(MEMKIND_DEFAULT, 1, BLOCK);
    if (zeroed == NULL) {
        fprintf(stderr, "memkind_calloc(MEMKIND_DEFAULT) returned NULL\n");
        return 1;
    }
    for (i = 0; i < BLOCK; i++) {
        if (zeroed[i] != 0) {
            fprintf(stderr, "DEFAULT calloc block not zeroed at byte %d\n", i);
            memkind_free(MEMKIND_DEFAULT, zeroed);
            return 1;
        }
    }
    memkind_free(MEMKIND_DEFAULT, zeroed);

    puts("memkind smoke test passed");
    return 0;
}
