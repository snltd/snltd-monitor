Back in 2007 I created a heavily virtualzed Solaris environment running
MySQL, Apache, webDAV, Subversion, Exim, Coldfusion and a bunch of other
stuff.

It was fairly early days for zones, and we couldn't find any monitoring
software that suited our needs particularly well. So, I wrote my own. We ran
this in production for three years, and found it produced excellent results,
with nothing important being missed, and very few false positives. As ever,
your mileage may vary.

The client for whom this software was written no longer exists in any form.
All branding and site-specific information has been removed.

Although I kept the code, I haven't yet been able to find the documentation
I wrote for the system. It's a clean straightforward little system though, and I'm sure anyone
sufficiently interested will work it out in no time.  The scripts are well annotated with usage information, and the code and configuration files are simple.


To get up and running, install the whole lot into `/usr/local/snltd_monitor`.
You need to create an RBAC profile, and information on exactly how to do so
is in the header of the `mon_exec_wrapper.sh` script. There's an SMF manifest
in `lib/svc/manifest/` which will get things running.

Full documentation to follow, once I get hold of a copy. (Or rewrite it.) 
There is also a plugin to [s-audit](https://github.com/snltd/s-audit)
which presents a site health check using
the information generated by this software, but I haven't yet ported it to
the new versions of s-audit.
