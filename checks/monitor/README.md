# Monitor Checks

## `check_remote_mon.sh`

This script lets instances of `snltd_monitor` check up on one another.
Put a list of hosts in the `MON_HOSTS` config variable, and the script
will try to `ssh` into each of those hosts, and look in the process
table for `snltd_monitor_daemon.sh`. Naturally, this requires suitable
key exchange, and will bloat your `lastlog`. Failing to connect, or not
finding the running process, flags an error.

If a connection is made, and the process is running, the script will
issue a second remote command to see how long it is since the remote
monitor last ran. It will issue a warning it that was more than one hour
ago.

