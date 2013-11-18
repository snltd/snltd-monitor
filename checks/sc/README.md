# SC Checks

Ask an ALOM system-controller for its IP address, and ping that address.
Note that some hosts (e.g. T2000s) don't present that information to the
OS, so the first step will fail.

You may have your LOMs on a subnet which can't be reached from the
hosts, so this check may not be useful to you. Furthermore, my
environment had LOMs on the `10.10.8.0` subnet, so the script checks
that the IP is on that net. I imagine you'll need to change it, which
you can by setting `LOM_SUBNET` in your config files.

