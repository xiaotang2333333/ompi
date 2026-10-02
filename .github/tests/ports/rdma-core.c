#include <infiniband/verbs.h>
#include <rdma/rdma_cma.h>
#include <rdma/hfi/hfi1_user.h>
#include <rdma/hfi/hfi1_ioctl.h>
#include <rdma/ib_user_mad.h>
#include <rdma/rdma_user_ioctl.h>
#include <rdma/rdma_user_ioctl_cmds.h>

#include <stddef.h>
#include <stdio.h>

static struct rdma_event_channel *(*volatile rdma_create_event_channel_ref)(void) =
    rdma_create_event_channel;
static void (*volatile rdma_destroy_event_channel_ref)(struct rdma_event_channel *channel) =
    rdma_destroy_event_channel;
static int (*volatile rdma_create_id_ref)(struct rdma_event_channel *channel,
                                          struct rdma_cm_id **id, void *context,
                                          enum rdma_port_space ps) = rdma_create_id;
static int (*volatile rdma_destroy_id_ref)(struct rdma_cm_id *id) = rdma_destroy_id;
static struct ibv_context **(*volatile rdma_get_devices_ref)(int *num_devices) =
    rdma_get_devices;
static void (*volatile rdma_free_devices_ref)(struct ibv_context **list) =
    rdma_free_devices;

#if defined(__GNUC__)
_Static_assert(__builtin_types_compatible_p(__typeof__(ibv_rate_to_mult),
                                            int (enum ibv_rate)),
               "ibv_rate_to_mult signature mismatch against verbs.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(mult_to_ibv_rate),
                                            enum ibv_rate (int)),
               "mult_to_ibv_rate signature mismatch against verbs.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(ibv_rate_to_mbps),
                                            int (enum ibv_rate)),
               "ibv_rate_to_mbps signature mismatch against verbs.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(mbps_to_ibv_rate),
                                            enum ibv_rate (int)),
               "mbps_to_ibv_rate signature mismatch against verbs.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(rdma_create_event_channel),
                                            struct rdma_event_channel *(void)),
               "rdma_create_event_channel signature mismatch against rdma_cma.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(rdma_destroy_event_channel),
                                            void (struct rdma_event_channel *)),
               "rdma_destroy_event_channel signature mismatch against rdma_cma.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(rdma_create_id),
                                            int (struct rdma_event_channel *,
                                                 struct rdma_cm_id **, void *,
                                                 enum rdma_port_space)),
               "rdma_create_id signature mismatch against rdma_cma.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(rdma_destroy_id),
                                            int (struct rdma_cm_id *)),
               "rdma_destroy_id signature mismatch against rdma_cma.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(rdma_get_devices),
                                            struct ibv_context **(int *)),
               "rdma_get_devices signature mismatch against rdma_cma.h");
_Static_assert(__builtin_types_compatible_p(__typeof__(rdma_free_devices),
                                            void (struct ibv_context **)),
               "rdma_free_devices signature mismatch against rdma_cma.h");
#endif

static int expect(int condition, const char *what)
{
    if (!condition)
        fprintf(stderr, "rdma-core: check failed: %s\n", what);
    return condition ? 0 : 1;
}

static int expect_ioctl(unsigned long request, unsigned int number,
                        unsigned int direction, size_t size, const char *what)
{
    if (_IOC_TYPE(request) != (unsigned int)RDMA_IOCTL_MAGIC ||
        _IOC_NR(request) != number ||
        _IOC_DIR(request) != direction ||
        _IOC_SIZE(request) != size) {
        fprintf(stderr,
                "rdma-core: check failed: %s (type 0x%x nr 0x%x dir 0x%x size %u"
                ", expected type 0x%x nr 0x%x dir 0x%x size %zu)\n",
                what, (unsigned int)_IOC_TYPE(request), (unsigned int)_IOC_NR(request),
                (unsigned int)_IOC_DIR(request), (unsigned int)_IOC_SIZE(request),
                (unsigned int)RDMA_IOCTL_MAGIC, number, direction, size);
        return 1;
    }
    return 0;
}

int main(void)
{
    int failures = 0;

    failures += expect(IBV_RATE_MAX == 0 && IBV_RATE_2_5_GBPS == 2 &&
                       IBV_RATE_10_GBPS == 3 && IBV_RATE_40_GBPS == 7 &&
                       IBV_RATE_100_GBPS == 16 && IBV_RATE_400_GBPS == 21 &&
                       IBV_RATE_1200_GBPS == 24,
                       "enum ibv_rate values");

    failures += expect(ibv_rate_to_mult(IBV_RATE_2_5_GBPS) == 1 &&
                       ibv_rate_to_mult(IBV_RATE_10_GBPS) == 4 &&
                       ibv_rate_to_mult(IBV_RATE_40_GBPS) == 16 &&
                       ibv_rate_to_mult(IBV_RATE_400_GBPS) == 160,
                       "ibv_rate_to_mult arithmetic");
    failures += expect(mult_to_ibv_rate(1) == IBV_RATE_2_5_GBPS &&
                       mult_to_ibv_rate(4) == IBV_RATE_10_GBPS &&
                       mult_to_ibv_rate(16) == IBV_RATE_40_GBPS &&
                       mult_to_ibv_rate(160) == IBV_RATE_400_GBPS,
                       "mult_to_ibv_rate arithmetic");
    failures += expect(mult_to_ibv_rate(0) == IBV_RATE_MAX &&
                       mult_to_ibv_rate(3) == IBV_RATE_MAX &&
                       ibv_rate_to_mult(IBV_RATE_MAX) == -1,
                       "rate multiple conversion rejects unknown values");

    failures += expect(ibv_rate_to_mbps(IBV_RATE_10_GBPS) == 10000 &&
                       ibv_rate_to_mbps(IBV_RATE_100_GBPS) == 103125 &&
                       ibv_rate_to_mbps(IBV_RATE_400_GBPS) == 425000 &&
                       ibv_rate_to_mbps(IBV_RATE_1200_GBPS) == 1275000,
                       "ibv_rate_to_mbps arithmetic");
    failures += expect(mbps_to_ibv_rate(10000) == IBV_RATE_10_GBPS &&
                       mbps_to_ibv_rate(103125) == IBV_RATE_100_GBPS &&
                       mbps_to_ibv_rate(425000) == IBV_RATE_400_GBPS,
                       "mbps_to_ibv_rate arithmetic");
    failures += expect(mbps_to_ibv_rate(1) == IBV_RATE_MAX &&
                       ibv_rate_to_mbps(IBV_RATE_MAX) == -1,
                       "mbps conversion rejects unknown values");
    failures += expect(mult_to_ibv_rate(ibv_rate_to_mult(IBV_RATE_40_GBPS)) ==
                       IBV_RATE_40_GBPS &&
                       mbps_to_ibv_rate(ibv_rate_to_mbps(IBV_RATE_40_GBPS)) ==
                       IBV_RATE_40_GBPS,
                       "rate conversion round-trips");

    failures += expect(HFI1_USER_SWMAJOR == 6 && HFI1_USER_SWMINOR == 3,
                       "HFI1_USER_SWMAJOR/SWMINOR values");
    failures += expect(sizeof(struct hfi1_user_info) == 28 &&
                       offsetof(struct hfi1_user_info, userversion) == 0 &&
                       offsetof(struct hfi1_user_info, subctxt_cnt) == 8 &&
                       offsetof(struct hfi1_user_info, uuid) == 12,
                       "struct hfi1_user_info layout");
    failures += expect(sizeof(struct hfi1_ctxt_info) == 40 &&
                       offsetof(struct hfi1_ctxt_info, runtime_flags) == 0 &&
                       offsetof(struct hfi1_ctxt_info, rcvegr_size) == 8 &&
                       offsetof(struct hfi1_ctxt_info, num_active) == 12 &&
                       offsetof(struct hfi1_ctxt_info, sdma_ring_size) == 36,
                       "struct hfi1_ctxt_info layout");
    failures += expect(sizeof(struct hfi1_tid_info) == 24 &&
                       offsetof(struct hfi1_tid_info, vaddr) == 0 &&
                       offsetof(struct hfi1_tid_info, tidlist) == 8 &&
                       offsetof(struct hfi1_tid_info, tidcnt) == 16 &&
                       offsetof(struct hfi1_tid_info, length) == 20,
                       "struct hfi1_tid_info layout");
    failures += expect(sizeof(struct hfi1_base_info) == 120 &&
                       offsetof(struct hfi1_base_info, hw_version) == 0 &&
                       offsetof(struct hfi1_base_info, bthqp) == 12 &&
                       offsetof(struct hfi1_base_info, sc_credits_addr) == 16,
                       "struct hfi1_base_info layout");

    failures += expect_ioctl(HFI1_IOCTL_ASSIGN_CTXT, 0xE1, _IOC_READ | _IOC_WRITE,
                             sizeof(struct hfi1_user_info), "HFI1_IOCTL_ASSIGN_CTXT");
    failures += expect_ioctl(HFI1_IOCTL_CTXT_INFO, 0xE2, _IOC_WRITE,
                             sizeof(struct hfi1_ctxt_info), "HFI1_IOCTL_CTXT_INFO");
    failures += expect_ioctl(HFI1_IOCTL_USER_INFO, 0xE3, _IOC_WRITE,
                             sizeof(struct hfi1_base_info), "HFI1_IOCTL_USER_INFO");
    failures += expect_ioctl(HFI1_IOCTL_TID_UPDATE, 0xE4, _IOC_READ | _IOC_WRITE,
                             sizeof(struct hfi1_tid_info), "HFI1_IOCTL_TID_UPDATE");
    failures += expect_ioctl(HFI1_IOCTL_TID_FREE, 0xE5, _IOC_READ | _IOC_WRITE,
                             sizeof(struct hfi1_tid_info), "HFI1_IOCTL_TID_FREE");
    failures += expect_ioctl(HFI1_IOCTL_CREDIT_UPD, 0xE6, _IOC_NONE, 0,
                             "HFI1_IOCTL_CREDIT_UPD");
    failures += expect_ioctl(HFI1_IOCTL_RECV_CTRL, 0xE8, _IOC_WRITE,
                             sizeof(int), "HFI1_IOCTL_RECV_CTRL");
    failures += expect_ioctl(HFI1_IOCTL_POLL_TYPE, 0xE9, _IOC_WRITE,
                             sizeof(int), "HFI1_IOCTL_POLL_TYPE");
    failures += expect_ioctl(HFI1_IOCTL_ACK_EVENT, 0xEA, _IOC_WRITE,
                             sizeof(unsigned long), "HFI1_IOCTL_ACK_EVENT");
    failures += expect_ioctl(HFI1_IOCTL_SET_PKEY, 0xEB, _IOC_WRITE,
                             sizeof(unsigned short), "HFI1_IOCTL_SET_PKEY");
    failures += expect_ioctl(HFI1_IOCTL_CTXT_RESET, 0xEC, _IOC_NONE, 0,
                             "HFI1_IOCTL_CTXT_RESET");
    failures += expect_ioctl(HFI1_IOCTL_TID_INVAL_READ, 0xED, _IOC_READ | _IOC_WRITE,
                             sizeof(struct hfi1_tid_info), "HFI1_IOCTL_TID_INVAL_READ");
    failures += expect_ioctl(HFI1_IOCTL_GET_VERS, 0xEE, _IOC_READ,
                             sizeof(int), "HFI1_IOCTL_GET_VERS");

    failures += expect_ioctl(IB_USER_MAD_REGISTER_AGENT, 0x01, _IOC_READ | _IOC_WRITE,
                             sizeof(struct ib_user_mad_reg_req), "IB_USER_MAD_REGISTER_AGENT");
    failures += expect_ioctl(IB_USER_MAD_UNREGISTER_AGENT, 0x02, _IOC_WRITE,
                             sizeof(unsigned int), "IB_USER_MAD_UNREGISTER_AGENT");
    failures += expect_ioctl(IB_USER_MAD_ENABLE_PKEY, 0x03, _IOC_NONE, 0,
                             "IB_USER_MAD_ENABLE_PKEY");
    failures += expect_ioctl(IB_USER_MAD_REGISTER_AGENT2, 0x04, _IOC_READ | _IOC_WRITE,
                             sizeof(struct ib_user_mad_reg_req2), "IB_USER_MAD_REGISTER_AGENT2");

    failures += expect(rdma_create_event_channel_ref != NULL &&
                       rdma_destroy_event_channel_ref != NULL &&
                       rdma_create_id_ref != NULL &&
                       rdma_destroy_id_ref != NULL &&
                       rdma_get_devices_ref != NULL &&
                       rdma_free_devices_ref != NULL,
                       "librdmacm exports rdma_create_event_channel, "
                       "rdma_destroy_event_channel, rdma_create_id, rdma_destroy_id, "
                       "rdma_get_devices and rdma_free_devices");

    if (failures != 0) {
        fprintf(stderr, "rdma-core: %d check(s) failed\n", failures);
        return 1;
    }

    printf("rdma-core v65 consumer passed (libibverbs rate API, librdmacm symbols, "
           "kernel UAPI headers; no RDMA device opened)\n");
    return 0;
}
