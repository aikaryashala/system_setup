/* Report.java - the program that uses Stats.java.
 *
 * Keep both files in the same directory, then:
 *
 *   javac Report.java          # javac finds and compiles Stats.java too
 *   java Report
 *   java Report 4 8 15 16 23 42
 *
 * From https://aikaryashala.com/system_setup/05_install_java/
 */

public class Report {

    public static void main(String[] args) {
        int[] readings = parse(args);

        System.out.println("--- readings ---");
        System.out.printf("  count: %d%n", readings.length);
        System.out.printf("   mean: %.2f%n", Stats.mean(readings));
        System.out.printf("    max: %d%n", Stats.max(readings));
        System.out.printf("    min: %d%n", Stats.min(readings));
        System.out.printf(" spread: %d%n", Stats.spread(readings));
    }

    /** Use the numbers given on the command line, or a default set. */
    private static int[] parse(String[] args) {
        if (args.length == 0) {
            return new int[] {12, 7, 3, 21, 9, 15};
        }

        int[] numbers = new int[args.length];
        for (int i = 0; i < args.length; i++) {
            numbers[i] = Integer.parseInt(args[i]);
        }
        return numbers;
    }
}
