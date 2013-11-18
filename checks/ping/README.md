# Ping Checks

## `check_hosts.sh`

Pings every host in the `PING_HOSTS` variable, with a two second
timeout. If any hostname does not resolve, a warning is raised. If a
host resolves but does not respond, that's an error.

## `check_loms.sh`

This script probably won't be much use. It is a duplicate of
`check_hosts.sh`, but appends `-lom` to every hostname. This was the
naming convention I used at the site for which I wrote this program.
