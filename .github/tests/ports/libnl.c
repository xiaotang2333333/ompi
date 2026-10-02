#include <netlink/route/link.h>
#include <netlink/socket.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    struct nl_sock *sk;
    struct rtnl_link *link;
    const char *name;

    sk = nl_socket_alloc();
    if (sk == NULL) {
        fprintf(stderr, "nl_socket_alloc returned NULL\n");
        return 1;
    }
    nl_socket_free(sk);

    link = rtnl_link_alloc();
    if (link == NULL) {
        fprintf(stderr, "rtnl_link_alloc returned NULL\n");
        return 1;
    }

    rtnl_link_set_name(link, "vcpkgci0");
    name = rtnl_link_get_name(link);
    if (name == NULL || strcmp(name, "vcpkgci0") != 0) {
        fprintf(stderr, "rtnl_link name round-trip failed: %s\n",
                name != NULL ? name : "(null)");
        rtnl_link_put(link);
        return 1;
    }

    rtnl_link_put(link);
    puts("libnl smoke test passed");
    return 0;
}
