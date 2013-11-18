# Checks

The scripts in this directory shouldn't be run manually, only through
the `snltd_auditor.sh` master script, which sets vital variables.

Here are the guidelines for coding.

Check scripts are named `check_<test>`, and don't print anything, they
just exit with a code which tells the master script something. Exit
codes are:

* `0`: the test was passed - no fault
* `1`: the test failed
* `2`: the test could not be run
* `3`: the test ran, but results were ambiguous

Scripts which check the state of the hardware go in `hardware/`, those
which check the health of the operating system scripts in `os/, scripts
to monitor Apache are in `apache/` and so-on. `snltd_monitor.sh` will
pick up new checks, and new classes of checks, each time it runs.

Each directory has its own `README.md`, explaining the checks it
contains.

