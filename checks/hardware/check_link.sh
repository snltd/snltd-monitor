#!/bin/ksh

#=============================================================================
#
# check_link.sh
# -------------
#
# Check to see if we have a consistent link speed on all our cabled ethernet
# ports. We've had some oddities with autoneg and changing speeds on the
# 10.10.4 network, so I thought it would be a good idea to monitor it.
#
# Now requires the following in /etc/security/exec_attr
#
# snltd Monitor:solaris:cmd:::/sbin/dladm:privs=sys_net_config,net_rawaccess
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Uses pfexec and RBAC. RDF 23/03/09
#
#=============================================================================

. $LIBRARY

#-----------------------------------------------------------------------------
# VARIABLES

STATE_FILE="${DIR_STATE}/dladm.state"

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# We need dladm for this

can_has dladm || exit 4

# dladm keeps changing. Do we need to use show-ether or show-dev?

pfexec dladm help 2>&1 | egrep -s "show-ether" \
	&& DLARG="show-ether" \
	|| DLARG="show-dev"

# All we're going to do is record what dladm tells us about the physical
# links, and compare it to what it told us last time. This may cause false
# positives if Sun continue to mess with dladm, but I'll write something
# more intelligent if I have to

pfexec dladm $DLARG >$TMPFILE

if [[ -f $STATE_FILE ]]
then

	if ! cmp -s $STATE_FILE $TMPFILE
	then
		EXIT=2

		if [[ -n $RUN_DIAG ]]
		then
			print "previous datalink information:\n"
			cat $STATE_FILE
			print "\ncurrent datalink information:\n"
			cat $TMPFILE
		fi

	fi

fi

mv $TMPFILE $STATE_FILE

exit $EXIT

