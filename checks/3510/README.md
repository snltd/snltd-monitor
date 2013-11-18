# 3510 Checks

These checks monitor the health of a Sun 3510 storage array. You
probably don't have any of these, so can ignore them.

All the scripts use `sccli` to query the 3510 in-band. You have to run
this as a genuine `root` user, so the `mon_exec_wrapper.sh` script must
be available and configured.

## `check_3510_batteries.sh`

Gets the expiration and hardware status for the 3510 batteries.  Expiry
information is considered worthy of a warning; any hardware report other
than `ok` is serious, so flags an error.

## `check_3510_disks.sh`

Gets the status of all disks in the array, and raises an error if any of
them are not `ONLINE`.

## `check_3510_enclosure.sh`

Gets the enclosure status, and raises an error if it finds a fault.
Diagnostics are the output of the `sccli` query.

## `check_3510_events.sh`

Parses the 3510's event log. Raises an error if there are any `Alert`s
in the log. Only looks at messages from today, and never examines the
same log lines twice.

Diagnostics are all error lines from the parsed chunk of the event log.

## `check_3510_redundancy.sh`

Checks the 3510 controllers are in `Active-Active` redundancy mode. If
not, raise and error and report the actual mode as diagnostics.

## `check_multipath.sh`

Counts the number of paths to a 3510. Run as root, or as a normal user
with the `file_dac_read` and `sys_devices` privileges. Assuming you run
the script as the `monitor` user:

    # usermod -P monitor
    # usermod -K defaultpriv=Basic,file_dac_read,sys_devices monitor

This is quite a thorough multipathing check, and I've used it with
success in other applications.

Raises an error if four distinct paths aren't found.
