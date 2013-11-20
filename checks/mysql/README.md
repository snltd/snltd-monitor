# MySQL Checks

These are, as usual, quite environment-specific, but they may be useful
to a wider audience.

## `check_mysql_conn.sh`

Checks a connection to a MySQL database and perform a `SELECT`. It
expects a database to be in place, created as follows:

    mysql> CREATE DATABASE snltd_monitor;
    mysql> GRANT SELECT ON snltd_monitor.* TO 'snltd_monitor'@'%' IDENTIFIED BY 'l3-Wd.xx9';
    mysql> USE snltd_monitor;
    mysql> CREATE TABLE check_table(pkey int, value varchar(10));
    mysql> INSERT INTO check_table VALUES(0, "connected");

The script connects to MySQL on every host listed in the
`MYSQL_CONN_HOSTS` variable. The hosts do not need to be zones on the
local machine, as `mysql -h` operates over the network. The script needs
`mysql` to be in the `PATH`. A suitable binary is included with
`snltd_monitor`.

An "access denied" (1045) error triggers a warning, anything else other
than a successful return of `connected` is an error.

## `check_mysql_proc.sh`

This script examines the process table to see if `mysqld` is running in
the zones named in `MYSQL_ZONES` which contain the directory pointed to
by `MYSQL_DATA_DIR`, which defaults to `/data/mysql`. Those zones must be on
the local machine. The script does not expect to see MySQL in the global
zone.

## `check_mysql_sync.sh`

Written to keep an eye on master-master replicated pairs of MySQL
databases, this script uses credentials found in `etc/mysql_connect` to
connect to each database in the `MYSQL_SYNC_LIST` variable, and
compares the master and slave statuses.

`MYSQL_SYNC_LIST` is a colon-separated list of comma-separated pairs.
For instance:

    identity-01,identity-02:billing-01,billing-02

And here is an example `mysql_connect` file.

```
[client]
    user = snltd_monitor
    password = l3-Wd.xx9
```

You can define a custom maximum acceptable difference in binlog offsets
with the `MYSQL_SYNC_DIFF` variable. The default is 5000.

If the binlog positions differ by more than `MYSQL_SYNC_DIFF`, a warning
is raised. If master and slave are using different binlog files, or if
either database is down, then that's an error. If the slave process is
not running on either host, that is also an error.

Diagnostic output is the binlog file and offset of each node, with slave
and master status.

## `check_mysql_threads.sh`

Uses the `MYSQL_CONN_VARIABLE` to connect to hosts and ask the MySQL
engine how many threads are currently running. If no connection can be
made, an error is sent. If the number of threads exceeds
`MYSQL_MAX_THREADS` (default 100), a warning is raised.

