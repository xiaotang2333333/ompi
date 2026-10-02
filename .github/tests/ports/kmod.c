#include <libkmod.h>

#include <stdio.h>
#include <syslog.h>

#if defined(__GNUC__)
_Static_assert(__builtin_types_compatible_p(__typeof__(kmod_new),
                                            struct kmod_ctx *(const char *,
                                                              const char *const *)),
               "kmod_new signature mismatch against libkmod.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(kmod_ref),
                                            struct kmod_ctx *(struct kmod_ctx *)),
               "kmod_ref signature mismatch against libkmod.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(kmod_unref),
                                            struct kmod_ctx *(struct kmod_ctx *)),
               "kmod_unref signature mismatch against libkmod.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(kmod_get_dirname),
                                            const char *(const struct kmod_ctx *)),
               "kmod_get_dirname signature mismatch against libkmod.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(kmod_config_get_blacklists),
                                            struct kmod_config_iter *(const struct kmod_ctx *)),
               "kmod_config_get_blacklists signature mismatch against libkmod.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(kmod_config_iter_next),
                                            _Bool (struct kmod_config_iter *)),
               "kmod_config_iter_next signature mismatch against libkmod.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(kmod_config_iter_free_iter),
                                            void (struct kmod_config_iter *)),
               "kmod_config_iter_free_iter signature mismatch against libkmod.h");
#endif

static int expect(int condition, const char *what)
{
    if (!condition)
        fprintf(stderr, "kmod: check failed: %s\n", what);
    return condition ? 0 : 1;
}

static int check_config_iter(struct kmod_config_iter *iter, int has_value,
                             const char *what)
{
    if (iter == NULL) {
        fprintf(stderr, "kmod: check failed: %s iterator is NULL\n", what);
        return 1;
    }

    if (kmod_config_iter_next(iter)) {
        if (kmod_config_iter_get_key(iter) == NULL) {
            fprintf(stderr, "kmod: check failed: %s key is NULL\n", what);
            kmod_config_iter_free_iter(iter);
            return 1;
        }
        if (has_value && kmod_config_iter_get_value(iter) == NULL) {
            fprintf(stderr, "kmod: check failed: %s value is NULL\n", what);
            kmod_config_iter_free_iter(iter);
            return 1;
        }
    }

    kmod_config_iter_free_iter(iter);
    return 0;
}

int main(void)
{
    struct kmod_ctx *ctx;
    struct kmod_ctx *unref_result;
    int failures = 0;

    ctx = kmod_new(NULL, NULL);
    if (ctx == NULL) {
        fprintf(stderr, "kmod: kmod_new returned NULL\n");
        return 1;
    }

    failures += expect(kmod_get_dirname(ctx) != NULL &&
                       kmod_get_dirname(ctx)[0] == '/',
                       "kmod_get_dirname returns an absolute module directory");

    kmod_set_log_priority(ctx, LOG_DEBUG);
    failures += expect(kmod_get_log_priority(ctx) == LOG_DEBUG,
                       "kmod_set_log_priority/kmod_get_log_priority round-trip");
    kmod_set_log_priority(ctx, LOG_ERR);

    failures += check_config_iter(kmod_config_get_blacklists(ctx), 0, "blacklists");
    failures += check_config_iter(kmod_config_get_install_commands(ctx), 1,
                                  "install_commands");
    failures += check_config_iter(kmod_config_get_remove_commands(ctx), 1,
                                  "remove_commands");
    failures += check_config_iter(kmod_config_get_aliases(ctx), 1, "aliases");
    failures += check_config_iter(kmod_config_get_options(ctx), 1, "options");
    failures += check_config_iter(kmod_config_get_softdeps(ctx), 1, "softdeps");
    failures += check_config_iter(kmod_config_get_weakdeps(ctx), 1, "weakdeps");

    failures += expect(kmod_ref(ctx) == ctx, "kmod_ref returns the context");

    unref_result = kmod_unref(ctx);
    if (unref_result != ctx) {
        fprintf(stderr,
                "kmod: kmod_unref released the context while a reference remained\n");
        return 1;
    }
    failures += expect(kmod_unref(ctx) == NULL,
                       "kmod_unref releases the final reference");

    if (failures != 0) {
        fprintf(stderr, "kmod: %d check(s) failed\n", failures);
        return 1;
    }

    printf("kmod public context/config smoke test passed (no module loaded)\n");
    return 0;
}
