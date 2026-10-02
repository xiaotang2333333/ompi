#include <sys/ioctl.h>

#include <knem_io.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#if !defined(KNEM_ABI_VERSION)
#error "knem_io.h does not define KNEM_ABI_VERSION"
#endif

#if KNEM_ABI_VERSION < 0x0000000c
#error "knem_io.h reports a KNEM ABI older than 0xc"
#endif

static int expect(int condition, const char *what)
{
    if (!condition)
        fprintf(stderr, "knem: check failed: %s\n", what);
    return condition ? 0 : 1;
}

static int expect_size(size_t actual, size_t expected, const char *what)
{
    if (actual != expected) {
        fprintf(stderr, "knem: check failed: %s (%zu != %zu)\n", what, actual, expected);
        return 1;
    }
    return 0;
}

static int expect_ioctl(unsigned long request, unsigned int number,
                        unsigned int direction, size_t size, const char *what)
{
    if (_IOC_TYPE(request) != (unsigned int)KNEM_CMD_MAGIC ||
        _IOC_NR(request) != number ||
        _IOC_DIR(request) != direction ||
        _IOC_SIZE(request) != size) {
        fprintf(stderr,
                "knem: check failed: %s (type 0x%x nr 0x%x dir 0x%x size %u"
                ", expected type 0x%x nr 0x%x dir 0x%x size %zu)\n",
                what, (unsigned int)_IOC_TYPE(request), (unsigned int)_IOC_NR(request),
                (unsigned int)_IOC_DIR(request), (unsigned int)_IOC_SIZE(request),
                (unsigned int)KNEM_CMD_MAGIC, number, direction, size);
        return 1;
    }
    return 0;
}

int main(void)
{
    int failures = 0;

    struct knem_cmd_param_iovec iovec[2];
    struct knem_cmd_info info;
    struct knem_cmd_bind_offload bind_offload;
    struct knem_cmd_create_region create_region;
    struct knem_cmd_copy_bounded copy_bounded;
    struct knem_cmd_inline_copy_bounded inline_copy_bounded;
    struct knem_cmd_inline_copy inline_copy;

    failures += expect((unsigned)KNEM_ABI_VERSION >= 0x0000000cu,
                       "KNEM_ABI_VERSION >= 0xc");
    failures += expect(strcmp(KNEM_DEVICE_NAME, "knem") == 0,
                       "KNEM_DEVICE_NAME is \"knem\"");
    failures += expect(strcmp(KNEM_DEVICE_FILENAME, "/dev/knem") == 0,
                       "KNEM_DEVICE_FILENAME is /dev/knem");
    failures += expect(KNEM_CMD_MAGIC == 'K', "KNEM_CMD_MAGIC is 'K'");

    failures += expect_ioctl(KNEM_CMD_GET_INFO, 0x10, _IOC_WRITE,
                             sizeof(struct knem_cmd_info), "KNEM_CMD_GET_INFO");
    failures += expect_ioctl(KNEM_CMD_BIND_OFFLOAD, 0x11, _IOC_READ,
                             sizeof(struct knem_cmd_bind_offload), "KNEM_CMD_BIND_OFFLOAD");
    failures += expect_ioctl(KNEM_CMD_CREATE_REGION, 0x21, _IOC_READ | _IOC_WRITE,
                             sizeof(struct knem_cmd_create_region), "KNEM_CMD_CREATE_REGION");
    failures += expect_ioctl(KNEM_CMD_DESTROY_REGION, 0x22, _IOC_READ,
                             sizeof(knem_cookie_t), "KNEM_CMD_DESTROY_REGION");
    failures += expect_ioctl(KNEM_CMD_COPY_BOUNDED, 0x34, _IOC_READ,
                             sizeof(struct knem_cmd_copy_bounded), "KNEM_CMD_COPY_BOUNDED");
    failures += expect_ioctl(KNEM_CMD_COPY, 0x32, _IOC_READ,
                             sizeof(struct knem_cmd_copy), "KNEM_CMD_COPY");
    failures += expect_ioctl(KNEM_CMD_INLINE_COPY_BOUNDED, 0x35, _IOC_READ,
                             sizeof(struct knem_cmd_inline_copy_bounded), "KNEM_CMD_INLINE_COPY_BOUNDED");
    failures += expect_ioctl(KNEM_CMD_INLINE_COPY, 0x33, _IOC_READ,
                             sizeof(struct knem_cmd_inline_copy), "KNEM_CMD_INLINE_COPY");
    failures += expect_ioctl(KNEM_CMD_INIT_SEND, 0x20, _IOC_READ | _IOC_WRITE,
                             sizeof(struct knem_cmd_init_send_param), "KNEM_CMD_INIT_SEND");
    failures += expect_ioctl(KNEM_CMD_INIT_ASYNC_RECV, 0x30, _IOC_READ,
                             sizeof(struct knem_cmd_init_async_recv_param), "KNEM_CMD_INIT_ASYNC_RECV");
    failures += expect_ioctl(KNEM_CMD_SYNC_RECV, 0x31, _IOC_READ,
                             sizeof(struct knem_cmd_sync_recv_param), "KNEM_CMD_SYNC_RECV");

    failures += expect_size(sizeof(struct knem_cmd_info), 4u * sizeof(uint32_t),
                            "struct knem_cmd_info has four uint32_t fields");
    failures += expect(offsetof(struct knem_cmd_info, abi) == 0,
                       "struct knem_cmd_info.abi is first");
    failures += expect(offsetof(struct knem_cmd_info, features) == sizeof(uint32_t),
                       "struct knem_cmd_info.features follows abi");
    failures += expect(offsetof(struct knem_cmd_info, ignored_flags) == 2u * sizeof(uint32_t),
                       "struct knem_cmd_info.ignored_flags follows features");
    failures += expect(offsetof(struct knem_cmd_info, forced_flags) == 3u * sizeof(uint32_t),
                       "struct knem_cmd_info.forced_flags follows ignored_flags");

    failures += expect_size(sizeof(struct knem_cmd_param_iovec), 2u * sizeof(uint64_t),
                            "struct knem_cmd_param_iovec is two uint64_t fields");
    failures += expect(offsetof(struct knem_cmd_param_iovec, base) == 0,
                       "struct knem_cmd_param_iovec.base is first");
    failures += expect(offsetof(struct knem_cmd_param_iovec, len) == sizeof(uint64_t),
                       "struct knem_cmd_param_iovec.len follows base");

    failures += expect_size(sizeof(struct knem_cmd_bind_offload),
                            2u * sizeof(uint32_t) + sizeof(uint64_t),
                            "struct knem_cmd_bind_offload layout");
    failures += expect(offsetof(struct knem_cmd_bind_offload, mask_ptr) == 2u * sizeof(uint32_t),
                       "struct knem_cmd_bind_offload.mask_ptr offset");
    failures += expect(sizeof(knem_bind_flags) == sizeof(uint32_t),
                       "knem_bind_flags is 32-bit");
    failures += expect(sizeof(knem_flags) == sizeof(uint32_t),
                       "knem_flags is 32-bit");
    failures += expect(sizeof(knem_cookie_t) == sizeof(uint64_t),
                       "knem_cookie_t is 64-bit");
    failures += expect(sizeof(knem_status_t) == 1,
                       "knem_status_t is 8-bit");

    failures += expect_size(sizeof(struct knem_cmd_create_region),
                            sizeof(uint64_t) + 4u * sizeof(uint32_t) + sizeof(uint64_t),
                            "struct knem_cmd_create_region layout");
    failures += expect(offsetof(struct knem_cmd_create_region, cookie) ==
                       sizeof(uint64_t) + 4u * sizeof(uint32_t),
                       "struct knem_cmd_create_region.cookie offset");
    failures += expect_size(sizeof(struct knem_cmd_copy_bounded),
                            5u * sizeof(uint64_t) + 4u * sizeof(uint32_t),
                            "struct knem_cmd_copy_bounded layout");
    failures += expect(offsetof(struct knem_cmd_copy_bounded, flags) == 5u * sizeof(uint64_t),
                       "struct knem_cmd_copy_bounded.flags offset");
    failures += expect_size(sizeof(struct knem_cmd_inline_copy_bounded),
                            4u * sizeof(uint64_t) + 6u * sizeof(uint32_t),
                            "struct knem_cmd_inline_copy_bounded layout");
    failures += expect(offsetof(struct knem_cmd_inline_copy_bounded, remote_cookie) ==
                       sizeof(uint64_t) + 2u * sizeof(uint32_t),
                       "struct knem_cmd_inline_copy_bounded.remote_cookie offset");
    failures += expect_size(sizeof(struct knem_cmd_inline_copy),
                            3u * sizeof(uint64_t) + 6u * sizeof(uint32_t),
                            "struct knem_cmd_inline_copy layout");
    failures += expect(offsetof(struct knem_cmd_inline_copy, flags) ==
                       sizeof(uint64_t) + 2u * sizeof(uint32_t) + 2u * sizeof(uint64_t),
                       "struct knem_cmd_inline_copy.flags offset");

    failures += expect(KNEM_STATUS_PENDING == 0 && KNEM_STATUS_SUCCESS == 1 &&
                       KNEM_STATUS_FAILED == 2,
                       "KNEM status enum values");
    failures += expect(KNEM_FEATURE_DMA == (1u << 0), "KNEM_FEATURE_DMA value");
    failures += expect(KNEM_FLAG_DMA == (1u << 0), "KNEM_FLAG_DMA value");
    failures += expect(KNEM_FLAG_ANY_THREAD_MASK ==
                       (KNEM_FLAG_DMATHREAD | KNEM_FLAG_MEMCPYTHREAD),
                       "KNEM_FLAG_ANY_THREAD_MASK composition");
    failures += expect(KNEM_FLAG_ANY_ASYNC_MASK ==
                       (KNEM_FLAG_ASYNCDMACOMPLETE | KNEM_FLAG_ANY_THREAD_MASK),
                       "KNEM_FLAG_ANY_ASYNC_MASK composition");
    failures += expect(KNEM_FLAG_ANY_DMA_MASK ==
                       (KNEM_FLAG_DMA | KNEM_FLAG_ASYNCDMACOMPLETE | KNEM_FLAG_DMATHREAD),
                       "KNEM_FLAG_ANY_DMA_MASK composition");
    failures += expect(KNEM_FLAG_ANY_CREATE_MASK ==
                       (KNEM_FLAG_SINGLEUSE | KNEM_FLAG_ANY_USER_ACCESS),
                       "KNEM_FLAG_ANY_CREATE_MASK composition");
    failures += expect(KNEM_FLAG_ANY_COPY_MASK ==
                       (KNEM_FLAG_DMA | KNEM_FLAG_ASYNCDMACOMPLETE |
                        KNEM_FLAG_DMATHREAD | KNEM_FLAG_MEMCPYTHREAD |
                        KNEM_FLAG_PINLOCAL | KNEM_FLAG_NOTIFY_FD),
                       "KNEM_FLAG_ANY_COPY_MASK composition");

    memset(&info, 0, sizeof(info));
    info.abi = KNEM_ABI_VERSION;
    info.features = KNEM_FEATURE_DMA;
    info.ignored_flags = 0;
    info.forced_flags = KNEM_FLAG_ANY_USER_ACCESS;
    failures += expect(info.abi == KNEM_ABI_VERSION &&
                       info.features == KNEM_FEATURE_DMA &&
                       info.ignored_flags == 0 &&
                       info.forced_flags == KNEM_FLAG_ANY_USER_ACCESS,
                       "struct knem_cmd_info field round-trip");

    iovec[0].base = (uint64_t)(uintptr_t)&info;
    iovec[0].len = (uint64_t)sizeof(info);
    iovec[1].base = (uint64_t)(uintptr_t)iovec;
    iovec[1].len = (uint64_t)sizeof(iovec);
    failures += expect(iovec[0].base == (uint64_t)(uintptr_t)&info &&
                       iovec[0].len == (uint64_t)sizeof(info) &&
                       iovec[1].base == (uint64_t)(uintptr_t)iovec &&
                       iovec[1].len == (uint64_t)sizeof(iovec),
                       "struct knem_cmd_param_iovec field round-trip");

    memset(&bind_offload, 0, sizeof(bind_offload));
    bind_offload.flags = KNEM_BIND_FLAG_CURRENT;
    bind_offload.mask_len = 0;
    bind_offload.mask_ptr = (uint64_t)(uintptr_t)&info;
    failures += expect(bind_offload.flags == KNEM_BIND_FLAG_CURRENT &&
                       bind_offload.mask_len == 0 &&
                       bind_offload.mask_ptr == (uint64_t)(uintptr_t)&info,
                       "struct knem_cmd_bind_offload field round-trip");

    memset(&create_region, 0, sizeof(create_region));
    create_region.iovec_array = (uint64_t)(uintptr_t)iovec;
    create_region.iovec_nr = 2;
    create_region.flags = KNEM_FLAG_SINGLEUSE;
    create_region.protection = 0x3;
    create_region.pad1 = 0;
    create_region.cookie = 0;
    failures += expect(create_region.iovec_array == (uint64_t)(uintptr_t)iovec &&
                       create_region.iovec_nr == 2 &&
                       create_region.flags == KNEM_FLAG_SINGLEUSE &&
                       create_region.protection == 0x3 &&
                       create_region.cookie == 0,
                       "struct knem_cmd_create_region field round-trip");

    memset(&copy_bounded, 0, sizeof(copy_bounded));
    copy_bounded.src_cookie = 1;
    copy_bounded.src_offset = 0;
    copy_bounded.dst_cookie = 2;
    copy_bounded.dst_offset = 4096;
    copy_bounded.length = 64;
    copy_bounded.flags = KNEM_FLAG_PINLOCAL;
    copy_bounded.current_status = KNEM_STATUS_PENDING;
    copy_bounded.async_status_index = 0;
    failures += expect(copy_bounded.src_cookie == 1 &&
                       copy_bounded.dst_cookie == 2 &&
                       copy_bounded.dst_offset == 4096 &&
                       copy_bounded.length == 64 &&
                       copy_bounded.flags == KNEM_FLAG_PINLOCAL &&
                       copy_bounded.current_status == KNEM_STATUS_PENDING &&
                       copy_bounded.async_status_index == 0,
                       "struct knem_cmd_copy_bounded field round-trip");

    memset(&inline_copy_bounded, 0, sizeof(inline_copy_bounded));
    inline_copy_bounded.local_iovec_array = (uint64_t)(uintptr_t)iovec;
    inline_copy_bounded.local_iovec_nr = 2;
    inline_copy_bounded.write = 1;
    inline_copy_bounded.remote_cookie = 7;
    inline_copy_bounded.remote_offset = 0;
    inline_copy_bounded.length = 128;
    inline_copy_bounded.flags = 0;
    inline_copy_bounded.current_status = KNEM_STATUS_SUCCESS;
    inline_copy_bounded.async_status_index = 0;
    failures += expect(inline_copy_bounded.local_iovec_array == (uint64_t)(uintptr_t)iovec &&
                       inline_copy_bounded.local_iovec_nr == 2 &&
                       inline_copy_bounded.write == 1 &&
                       inline_copy_bounded.remote_cookie == 7 &&
                       inline_copy_bounded.length == 128 &&
                       inline_copy_bounded.current_status == KNEM_STATUS_SUCCESS,
                       "struct knem_cmd_inline_copy_bounded field round-trip");

    memset(&inline_copy, 0, sizeof(inline_copy));
    inline_copy.local_iovec_array = (uint64_t)(uintptr_t)iovec;
    inline_copy.local_iovec_nr = 1;
    inline_copy.write = 0;
    inline_copy.remote_cookie = 9;
    inline_copy.remote_offset = 0;
    inline_copy.flags = 0;
    inline_copy.current_status = KNEM_STATUS_FAILED;
    inline_copy.async_status_index = 0;
    failures += expect(inline_copy.local_iovec_nr == 1 &&
                       inline_copy.write == 0 &&
                       inline_copy.remote_cookie == 9 &&
                       inline_copy.current_status == KNEM_STATUS_FAILED,
                       "struct knem_cmd_inline_copy field round-trip");

    if (failures != 0) {
        fprintf(stderr, "knem: %d check(s) failed\n", failures);
        return 1;
    }

    printf("KNEM userspace ABI smoke test passed (KNEM_ABI_VERSION=0x%08x, header only)\n",
           (unsigned)KNEM_ABI_VERSION);
    return 0;
}
