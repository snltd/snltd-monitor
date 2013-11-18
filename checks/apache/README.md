# Apache Checks

These scripts were written to be run in the global zones of machines
which had many NGZs running different versions of Apache. For that
reason, they will only run in a global zone.

## `check_apache_conn.sh`

Connects, on port 80, to every zone on the host which has
`/usr/local/apache`, or, if it is defined, every host listed in the
`APACHE_ZONES` variable. If any zone does not respond, an error is
raised, with the full `curl` output sent as diagnostics.

Requires a usable `curl` binary.

## `check_apache_proc.sh`

Counts the number of `httpd` process running in each zone, from a list
chosen as by `check_apache_conn.sh`. If that number is less than two or
greater than 75, raise a warning. If it is zero, raise an error.
