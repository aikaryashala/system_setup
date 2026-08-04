/* overflow.c - a deliberate bug, from
 * https://aikaryashala.com/system_setup/03_install_c/
 *
 * Compiled normally it often appears to work, which is what makes this kind of
 * bug dangerous. Compiled with the address sanitizer it fails immediately and
 * tells you exactly which line was at fault:
 *
 *   clang -g -O0 -fsanitize=address -o overflow overflow.c
 *   ./overflow
 */

#include <stdio.h>

int main(void) {
    int numbers[4] = {1, 2, 3, 4};

    numbers[4] = 99;   /* one element past the end of the array */

    printf("%d\n", numbers[0]);
    return 0;
}
