/* Stats.java - a small class for Report.java to use.
 *
 * From https://aikaryashala.com/system_setup/05_install_java/
 */

public class Stats {

    /** The average. Returns 0 for an empty array. */
    public static double mean(int[] numbers) {
        if (numbers.length == 0) {
            return 0;
        }
        int total = 0;
        for (int n : numbers) {
            total += n;
        }
        return (double) total / numbers.length;
    }

    /** The largest value. */
    public static int max(int[] numbers) {
        int best = numbers[0];
        for (int n : numbers) {
            if (n > best) {
                best = n;
            }
        }
        return best;
    }

    /** The smallest value. */
    public static int min(int[] numbers) {
        int worst = numbers[0];
        for (int n : numbers) {
            if (n < worst) {
                worst = n;
            }
        }
        return worst;
    }

    /** How far apart the largest and smallest values are. */
    public static int spread(int[] numbers) {
        return max(numbers) - min(numbers);
    }
}
