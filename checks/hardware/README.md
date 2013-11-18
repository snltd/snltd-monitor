# Hardware Checks

These checks were written to work with the Sun T2000, v210/v240, v245
and v100. I can't be sure what else they will or won't work with,
particularly the things that poke around with `prtdiag`.

## `check_LEDs.sh`

Raises an error if any chassis LEDs are in a state other than `GREEN`.

## `check_PSUs.sh`

Errors if any power supply does not report as `okay`.

## `SUNW,Sun-Fire-T200/check_PSUs.sh`

Raises an error if any of the power supplies on a T200 chassis are  in
the `disabled` state. That normally indicates a loss of supply.

## `check_cpus.sh`

Raises an error if any CPU is not in the `online` state.

## `check_diag.sh`

Parses the output of `prtdiag`, and raises an error if it finds any
component is described as being `failed`.

## `check_disk_errs.sh`

Firstly, counts the disks the system can see, compares that number with
the count on the last run, and raise an error if the number's gone down,
or a warning if it's gone up.

Next, count soft and hard errors on each disk. If there are hard errors,
raise an error. If the number of soft errors exceeds the value of
`S_ERR_LMT`, raise a warning.

## `check_fmd.sh`

Look at FMD output. If there are corrected faults, pass them through as
a warning. If there are unresolved faults, send them as errors.

To run as non-root, requires the following in `/etc/security/exec_attr`

    snltd Monitor:solaris:cmd:::/usr/sbin/fmadm:euid=0

## `check_link.sh`

Checks the status of all physical network links and compares them to the
values obtained on the last run. If any have changed, raise an error and
pass them through. Good for catching flaky connections that change speed
or duplex.

Requires the following in `/etc/security/exec_attr`

    snltd Monitor:solaris:cmd:::/sbin/dladm:privs=sys_net_config,net_rawaccess

## `check_metadevices.sh`

Looks at the status of SVM devices. Resyncing mirrors raise a warning,
anything else that's not `Okay` raises an error. Diagnostics describe
the metadevice, its underlying physical device, and its mountpoint. Not
tested with metasets.

## `check_prtdiag.sh`

Ensures that, when `snltd_monitor.sh` ran `prtdiag`, it worked. The
reasons this must exist were lost with my original documentation.

## `check_zpool.sh`

Check the health of ZFS zpools. Resilvering pools raise a warning, any
state that is not `ONLINE` is an error. Diagnostics are the full status
of the pool.
