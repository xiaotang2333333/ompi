#include <psm2.h>

#include <stdio.h>
#include <string.h>

int main(void)
{
    const char *ok_string;
    const char *unknown_string;

    if (PSM2_VERNO_MAJOR != 0x02 || PSM2_VERNO_MINOR != 0x02) {
        fprintf(stderr, "unexpected PSM2_VERNO: 0x%04x\n", PSM2_VERNO);
        return 1;
    }

    ok_string = psm2_error_get_string(PSM2_OK);
    if (ok_string == NULL || strcmp(ok_string, "Success") != 0) {
        fprintf(stderr, "psm2_error_get_string(PSM2_OK) mismatch: '%s'\n",
                ok_string == NULL ? "(null)" : ok_string);
        return 1;
    }

    unknown_string = psm2_error_get_string(PSM2_ERROR_LAST);
    if (unknown_string == NULL || strcmp(unknown_string, "unknown") != 0) {
        fprintf(stderr,
                "psm2_error_get_string(PSM2_ERROR_LAST) mismatch: '%s'\n",
                unknown_string == NULL ? "(null)" : unknown_string);
        return 1;
    }

    printf("PSM2 public error-string API passed (2.2, psm2_init not called)\n");
    return 0;
}
