# Dashboard Checks

## `check_data_send.sh`

This isn't a check at all. It uses `ssh` and `scp` to transfer the
results of all the other checks to a remote host. This was written to
feed data into an [s-audit](https://github.com/snltd/s-audit) plugin
page, which displayed a dashboard.

`DASH_CONNECTOR` must be set and of the form `user@host`. Suitable key
exchange is, of course, required. The `ssh` binary must support the
`ConnectTimeout` feature, which some Solaris 10 (and older) SSH
implementations do not.
