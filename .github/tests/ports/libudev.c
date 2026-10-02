#include <libudev.h>

#include <stdio.h>

int main(void)
{
    struct udev *udev;
    struct udev *unref_result;
    int failures = 0;

    udev = udev_new();
    if (udev == NULL) {
        fprintf(stderr, "libudev: udev_new returned NULL\n");
        return 1;
    }

    if (udev_ref(udev) != udev) {
        fprintf(stderr, "libudev: udev_ref did not return the context\n");
        udev_unref(udev);
        return 1;
    }

    unref_result = udev_unref(udev);
    if (unref_result != udev) {
        fprintf(stderr,
                "libudev: udev_unref released the context while a reference remained\n");
        return 1;
    }

    if (udev_unref(udev) != NULL) {
        fprintf(stderr, "libudev: final udev_unref did not return NULL\n");
        failures++;
    }

    if (udev_unref(NULL) != NULL) {
        fprintf(stderr, "libudev: udev_unref(NULL) did not return NULL\n");
        failures++;
    }

    if (failures != 0)
        return 1;

    printf("libudev context smoke test passed "
           "(udev_new/udev_ref/udev_unref; no udev daemon required)\n");
    return 0;
}
