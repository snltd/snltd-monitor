# DAV checks

These checks monitor the correct function of an Apache webDAV server.
You probably don't have one.

## `check_dav_proc.sh`

Looks for Apache `httpd` process in any zones defined in the `DAV_ZONES`
variable. Raises a warning if there are more than `PROC_MAX` (defaults
to 10), or an error if there are none at all.

## `check_dav_read.sh`

Uses `curl` to read a file from one or more DAV servers defined in the
`DAV_S_LIST` variable. It expects this file to be found at
`/snltd_monitor/dav_testfile_read`, but does not care about the content.
If the file is not retrieved, an error is raised. Diagnostic info is the
full error from `curl`.

## `check_dav_write.sh`

As for `check_dav_read.sh`, but uploads a test file to each of the
`DAV_S_LIST` hosts. Expects to find a share called `snltd_monitor`.
