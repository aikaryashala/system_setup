/* Hello.java - the example from
 * https://aikaryashala.com/system_setup/05_install_java/
 *
 * Compile and run:
 *   javac Hello.java
 *   java Hello
 *   java Hello Ubuntu
 *
 * Or run the source directly, without producing a .class file:
 *   java Hello.java
 */

public class Hello {
    public static void main(String[] args) {
        String who = args.length > 0 ? args[0] : "world";
        System.out.println("Hello, " + who + "!");
        System.out.println("Running on Java " + System.getProperty("java.version"));
    }
}
