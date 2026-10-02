#include <munge.h>
#include <stdio.h>
#include <string.h>

#define CHECK_MUNGE(call)                                                      \
    do {                                                                       \
        munge_err_t const rc_ = (call);                                        \
        if (rc_ != EMUNGE_SUCCESS) {                                           \
            const char *msg_ = munge_strerror(rc_);                            \
            fprintf(stderr, "%s failed: %d (%s)\n", #call, (int)rc_,           \
                    msg_ != NULL ? msg_ : "unknown error");                    \
            return 1;                                                          \
        }                                                                      \
    } while (0)

int main(void)
{
    munge_ctx_t ctx;
    char *realm = NULL;
    char *socket_path = NULL;
    int cipher = -1;
    int mac = -1;
    int zip = -1;
    int ttl = -1;
    int ignore_ttl = 0;
    int ignore_replay = 0;
    int unused = 0;
    const char *msg;

    ctx = munge_ctx_create();
    if (ctx == NULL) {
        fprintf(stderr, "munge_ctx_create returned NULL\n");
        return 1;
    }

    CHECK_MUNGE(munge_ctx_set(ctx, MUNGE_OPT_CIPHER_TYPE, MUNGE_CIPHER_AES128));
    CHECK_MUNGE(munge_ctx_set(ctx, MUNGE_OPT_MAC_TYPE, MUNGE_MAC_SHA256));
    CHECK_MUNGE(munge_ctx_set(ctx, MUNGE_OPT_ZIP_TYPE, MUNGE_ZIP_NONE));
    CHECK_MUNGE(munge_ctx_set(ctx, MUNGE_OPT_REALM, "vcpkg-ci-realm"));
    CHECK_MUNGE(munge_ctx_set(ctx, MUNGE_OPT_TTL, MUNGE_TTL_DEFAULT));
    CHECK_MUNGE(
        munge_ctx_set(ctx, MUNGE_OPT_SOCKET, "/tmp/vcpkg-ci-munge.sock"));
    CHECK_MUNGE(munge_ctx_set(ctx, MUNGE_OPT_IGNORE_TTL, 1));
    CHECK_MUNGE(munge_ctx_set(ctx, MUNGE_OPT_IGNORE_REPLAY, 1));

    CHECK_MUNGE(munge_ctx_get(ctx, MUNGE_OPT_CIPHER_TYPE, &cipher));
    CHECK_MUNGE(munge_ctx_get(ctx, MUNGE_OPT_MAC_TYPE, &mac));
    CHECK_MUNGE(munge_ctx_get(ctx, MUNGE_OPT_ZIP_TYPE, &zip));
    CHECK_MUNGE(munge_ctx_get(ctx, MUNGE_OPT_REALM, &realm));
    CHECK_MUNGE(munge_ctx_get(ctx, MUNGE_OPT_TTL, &ttl));
    CHECK_MUNGE(munge_ctx_get(ctx, MUNGE_OPT_SOCKET, &socket_path));
    CHECK_MUNGE(munge_ctx_get(ctx, MUNGE_OPT_IGNORE_TTL, &ignore_ttl));
    CHECK_MUNGE(munge_ctx_get(ctx, MUNGE_OPT_IGNORE_REPLAY, &ignore_replay));

    if (cipher != MUNGE_CIPHER_AES128) {
        fprintf(stderr, "cipher option round-trip failed: %d\n", cipher);
        munge_ctx_destroy(ctx);
        return 1;
    }
    if (mac != MUNGE_MAC_SHA256) {
        fprintf(stderr, "mac option round-trip failed: %d\n", mac);
        munge_ctx_destroy(ctx);
        return 1;
    }
    if (zip != MUNGE_ZIP_NONE) {
        fprintf(stderr, "zip option round-trip failed: %d\n", zip);
        munge_ctx_destroy(ctx);
        return 1;
    }
    if (ttl != MUNGE_TTL_DEFAULT) {
        fprintf(stderr, "ttl option round-trip failed: %d\n", ttl);
        munge_ctx_destroy(ctx);
        return 1;
    }
    if (realm == NULL || strcmp(realm, "vcpkg-ci-realm") != 0) {
        fprintf(stderr, "realm option round-trip failed\n");
        munge_ctx_destroy(ctx);
        return 1;
    }
    if (socket_path == NULL ||
        strcmp(socket_path, "/tmp/vcpkg-ci-munge.sock") != 0) {
        fprintf(stderr, "socket option round-trip failed\n");
        munge_ctx_destroy(ctx);
        return 1;
    }
    if (ignore_ttl != 1 || ignore_replay != 1) {
        fprintf(stderr, "ignore flags round-trip failed\n");
        munge_ctx_destroy(ctx);
        return 1;
    }

    if (munge_ctx_get(ctx, 4242, &unused) != EMUNGE_BAD_ARG) {
        fprintf(stderr, "invalid option did not report EMUNGE_BAD_ARG\n");
        munge_ctx_destroy(ctx);
        return 1;
    }
    msg = munge_ctx_strerror(ctx);
    if (msg == NULL || msg[0] == '\0') {
        fprintf(stderr, "munge_ctx_strerror did not report the error\n");
        munge_ctx_destroy(ctx);
        return 1;
    }

    munge_ctx_destroy(ctx);
    puts("munge smoke test passed");
    return 0;
}
