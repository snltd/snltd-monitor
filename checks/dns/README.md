# DNS Checks

## `check_dns_proc.sh`

Looks in any local zone in the `DNS_ZONES` variable, and, if it finds
a `/var/named` directory inside it, checks for a running `named`
process. If it does not find one, it errors. If `DNS_ZONES` is not set,
the script looks inside all NGZs.

## `check_dns_resolve.sh`

This script examines the `DNS_Q_LIST` variable, which is of the form

    server:host=address server:host=address...

It will use `dig` to request `server` does a DNS lookup on `host`, and
check that the returned value is equal to `address`. You can make as
many requests as you like, to as many DNS servers as you like.

For instance, the following line in a host config file will tell the
script to check that `internal_dns` resolves `host1` to `192.168.1.42`,
and that `external_dns` resolves `snltd.co.uk` to `72.2.112.239`.

```shell
export DNS_Q_LIST="internal_dns:host1=192.168.1.42 external_dns:snltd.co.uk=72.2.112.239"
```

If a host resolves to multiple addresses (e.g. google.com), the answer
should be a comma-separated list of those addresses.

A suitable `dig` binary is included in the `snltd_monitor` distribution.
