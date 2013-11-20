# Coldfusion Checks

I can't imagine anyone else is messed-up enough to need these, but here
they are.

## `check_cf_conn.sh`

Loop through all zones defined in `CF_ZONES` (they do not have to be on
the local host), making a `curl` request for a remote file which
contains nothing but the string `CONNECTED`. Error if this fails.

Diagnostics are full `curl` output.

## `check_cf_proc.sh`

Loop through `CF_ZONES` looking for Coldfusion's `coldfusion` process.
Error if it isn't running, but `/usr/local/coldfusion` exists.

## `check_verity_procs.sh`

Just like `check_cf_proc.sh`, but for the `verity` process.
