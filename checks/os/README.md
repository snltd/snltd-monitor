# Operating System Checks

## `check_cron_jobs.sh`

Parses the cron logs to look for failed jobs. On each execution, it
records the line of the log file it last saw, and on the next run, only
searches from that line onwards.

A hard error is triggered if any errors are found in the chunk of
logfile which has been analyzed, or if there is no cron log. Warnings
are never sent. All-clears are never sent.

Diagnostic info displays the offending lines.

## `check_load_avg.sh`

Checks the load average. Set soft and hard limits with the
`LOAD_S_LMT` and `LOAD_H_LMT` values respectively. If these are unset,
a warning will be triggered if the load is greater than the number of
CPU cores the OS can see, and an error at twice that number.

On error, `prstat`'s view of CPU utilization will be displayed. Per-zone
CPU will be included in this output.

##`check_loopback_fs.sh`

If you have zones with loopback mounted filesystems, this script checks
that they are all mounted. It does this by looking for content in the
root of the filesystem. If the directory is empty, the script assumes it
is not mounted. This was a safe check in the environment the script was
written for, but it may not be for you.

Any empty mountpoint sends a hard error, with the relevant `zonecfg`
information for the filesystem as diagnostics.

##`check_messages.sh`
Looks through `/var/adm/messages` in every zone, pulling out messages
with severity `emerg`, `alert`, `crit`, `err`, or `warning`. If only
`warning`s are found, a warning is raised, otherwise it's an error.

As with `check_cron_jobs.sh`, it only looks at new lines in the log.

Diagnostics are the error lines, straight from the log file.

##`check_nfs_mounts.sh`

For each zone on the host, looks at `/etc/vfstab` for NFS mounts, and
checks they are all mounted. Errors if not.

##`check_ntp.sh`

In the global zone, queries the NTP service and counts the number of
`sys_peer`s. If there are less than two, errors. Diagnostic output is
the `assoc` page from `ntpq`.

##`check_paging.sh`

Uses `vmstat` to get paging information. It normally errors if it sees
any paging activity at all, but you can set thresholds by setting
`ANON_PG_LIM` in the config file. It should be a string containing three
space-separated numbers, which are the allowable values of `api`, `apo`,
and `apf`. If any of these three values are exceeded, a warning is
raised.

Diagnostic output is `prstat`s top processes by memory usage.

Because `vmstat` is used, and the first line out of `vmstat` is
cumulative-since-boot, this check has to wait a couple of seconds to get
the information it needs.

##`check_reboot.sh`

Tells you if a zone has rebooted in the interval since the script last
ran. If it has, you get a warning, and diagnostic info is the name and
last boot-time of the zone. Also works for the global zone.

##`check_svcs.sh`

Checks the state of all SMF services in every zone, over `zlogin`. If
any services are in `maintenance` mode, an error is raised. Diagnostic
info is the output of `svcs -x` in the zone.

##`check_swap.sh`

Monitors the amount of free swap space. You can set the warning and
error thresholds with the `SWAP_S_LMT` and `SWAP_H_LMT` config
variables, but they default to 500000 and 200000 respectively.

Diagnostic output is a breakdown of swap space. This check only runs in
the global zone.

##`check_syslog.sh

Just like `check_messages.sh`, but looks at `/var/log/syslog`.

##`check_ufs_space.sh`

Looks at percentage used space in all UFS filesystems and compares with
two thresholds: `UFS_S_LMT` (defaults to 80) and `UFS_H_LMT` (defaults
to 90), and issues a warning or error if they are exceeded.

Diagnostics show every filesystem which is over the soft limit.

##`check_zfs_space.sh`

Like `check_ufs_space.sh`, but for ZFS.

##`check_zones.sh`

Looks to see whether the states of any of the zones (as reported by
`zoneadm list`) have changed since the last run.

Diagnostic output is the previous and current state of the zone(s).

##`check_zpool_space.sh`

Issues a warning or error if any zpool's percent-usage exceeds limits
defined by `ZPOOL_S_LMT` and `ZPOOL_H_LMT`. These default to 75% and 80%
resepectively, as ZFS performance can fall in write-heavy situations
over 80%.

