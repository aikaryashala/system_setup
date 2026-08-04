"""stats.py - a small module for report.py to import.

Used by https://aikaryashala.com/system_setup/04_install_py/ to show what
stepping *into* another file looks like in the debugger.
"""


def mean(numbers):
    """The average. Raises ZeroDivisionError on an empty list."""
    return sum(numbers) / len(numbers)


def median(numbers):
    """The middle value once the numbers are in order."""
    ordered = sorted(numbers)
    middle = len(ordered) // 2

    if len(ordered) % 2 == 1:
        return ordered[middle]
    return (ordered[middle - 1] + ordered[middle]) / 2


def spread(numbers):
    """How far apart the largest and smallest values are."""
    return max(numbers) - min(numbers)


def summarise(numbers):
    """Everything above, in one dictionary."""
    return {
        "count": len(numbers),
        "mean": mean(numbers),
        "median": median(numbers),
        "spread": spread(numbers),
    }
