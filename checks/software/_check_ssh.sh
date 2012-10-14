#!/bin/ksh

#=============================================================================
#
# check_ssh.sh 
# ============
#
# Check all the zones on a server are running their SSH server. Rather than
# just checking the process is up, try connecting to port 22 through ksh's
# /dev/tcp construct.
# 
# WARNING. This script will flood the SSH logs with messages. I can't work
# out a way for this not to happen, as sshd logs all connections at info
# severity or higher, however they fail. Nagios has the same issue, so it's
# not just me.
#
# v1.0 Initial Release
#
#=============================================================================

[[ -s $LIBRARY ]] && . $LIBRARY || exit 254

#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# We'll cater for servers using zones as well as old ones which don't

if can_has zoneadm && is_global
then
	
	# Loop through each zone checking. Missing SSHes in local zones flag
	# warnings, missing in the global is an ERROR. As soon as we find a
	# missing SSH, just exit. The diag_ script can find out more if it needs
	# to

	zoneadm list | while read zone
	do
		# Get the IP address of the zone, because /dev/tcp isn't able to
		# resolve hostnames. Global is a special case

		if [[ $zone == "global" ]]
		then
			ZIP="127.0.0.1"
		else
			# Get the line AFTER the regular expression. Zones with multiple
			# IP addresses confused the old "clever" way of doing this, so
			# now we get all the ifconfig lines relating to this $zone, and
			# chop up and use the last one

			ZIP=$(ifconfig -a | \
			sed -n -e "/${zone}$/{n;p;}" | tail -1 | cut -d\  -f2)
		fi
		
		# Have a look what we get when we connect to port 22
		unset SHOUT
		read SHOUT 2>/dev/null </dev/tcp/${ZIP}/22 

		if [[ -z $SHOUT ]]
		then

			[[ $zone == "global" ]] \
				&& EXIT=2 \
				|| EXIT=1
			
			break
			
		fi

	done

else
	# We don't have zones. Just check the loopback

	read SHOUT < /dev/tcp/127.0.0.1/22
	
	[[ -n $SHOUT ]] && EXIT=2
fi

exit $EXIT
