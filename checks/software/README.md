# Software Checks

## `check_ssh.sh`

Check all the zones on a server are running `sshd`. Rather than just
checking the process is up, try connecting to port 22 through ksh's
`/dev/tcp` construct.

This script will flood the SSH logs with messages. I can't work out a
way for this not to happen, as `sshd` logs all connections at `info`
severity or higher, however they fail.
