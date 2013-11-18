# Netbackup Checks

## `check_jukebox.sh`

This is not likely to be useful. It counts the number of tape devices
attached to the host, and errors if there are not two.

## `check_nb_clients.sh`

Tries to connect, with `bptestbpcd`, to each host defined in the
`NB_CLIENT_LIST` variable. If any do not respond, an error is raised. If
the host is down (i.e. it does not respond to a `ping`), that's a
warning.

Diagnostic output is the output of the `bptestbpcd` command.

## `check_nb_logs.sh`

Runs `bpdbjobs` to parse the local NetBackup log file, and examines the
output to see if any jobs have failed. If they have, an error is raised,
and the diagnostic info describes the failed job(s).

