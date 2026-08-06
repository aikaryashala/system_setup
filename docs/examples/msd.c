/* msd.c - the second example from
 * https://aikaryashala.com/system_setup/book/08-stopping-time/
 *
 * Adds the most significant digit of two numbers. For 345 and 52 the answer
 * is 3 + 5 = 8.
 *
 *   clang -g msd.c -o msd
 *   ./msd
 *   lldb ./msd
 */

#include <stdio.h>

int most_significant_digit(int number)
{
    while (number >= 10)
    {
        number = number / 10;
    }

    return number;
}

int main()
{
    int num1;
    int num2;
    int msd1;
    int msd2;
    int total;

    printf("To add the most significant digits of two numbers.\n");

    printf("Enter the first number: ");
    scanf("%i", &num1);

    printf("Enter the second number: ");
    scanf("%i", &num2);

    msd1 = most_significant_digit(num1);
    msd2 = most_significant_digit(num2);

    total = msd1 + msd2;

    printf("Sum of MSDs(Most Significant Digits) of two numbers is %i.\n", total);

    return 0;
}
