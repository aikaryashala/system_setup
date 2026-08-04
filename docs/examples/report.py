"""report.py - the program to run under the debugger.

Keep this file and stats.py in the same directory, then:

    python3 report.py                 # run it - it crashes at the end, on purpose
    python3 -m pdb report.py          # walk through it a line at a time
    python3 -m pdb -c continue report.py   # let it crash, then inspect the wreckage

The crash at the bottom is deliberate. Finding out *why* it happens, without
adding a single print statement, is the point of the exercise.
"""

import stats

READINGS = [12, 7, 3, 21, 9, 15]


def show(title, numbers):
    summary = stats.summarise(numbers)
    print(f"--- {title} ---")
    for key, value in summary.items():
        print(f"{key:>7}: {value}")


def main():
    show("readings", READINGS)

    # This one is empty, and mean() divides by len(numbers).
    missing = []
    show("missing", missing)


if __name__ == "__main__":
    main()
