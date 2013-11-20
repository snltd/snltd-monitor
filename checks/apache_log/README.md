# Apache Log Checks

## `check_apache_log.sh`

Looks in any local zone named in the `APACHE_ZONES` variable for a
`/var/apache/logs` directory. If that directory is not found, but an
`httpd` process is, an error is raised, as Apache is logging to a
non-standard place.

All logs under `/var/apache/logs` less than 24 hours old are examined,
and if they contain any errors or warnings, they are reported. A warning
is also raised if the log file is excessively large.

## `check_php_log.sh`

As for `check_apache_log.sh`, but only looks at
`var/apache/logs/php_error.log`.
