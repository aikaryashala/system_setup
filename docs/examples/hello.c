/* hello.c - the example from https://aikaryashala.com/system_setup/03_install_c/
 *
 *   clang -g -O0 -Wall -Wextra -o hello hello.c
 *   ./hello
 *   xxd -l 64 hello
 */

#include <stdio.h>

int main(void) {
    int answer = 42;
    printf("Hello from C. The answer is %d.\n", answer);
    return 0;
}
