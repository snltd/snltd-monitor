#!/bin/ksh

#=============================================================================
#
# repair_zpool.sh
# ---------------
#
# Have a go at fixing broken zpools. 
#
# v1.0 Initial Relase
#
#=============================================================================

[[ -s $LIBRARY ]] && . $LIBRARY || exit 254

#-----------------------------------------------------------------------------
# VARIABLES

ERR=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# only root can fix a faulty pool

is_root || exit 1

can_has zpool || exit 3

zpool list -Ho name | while read pool
do
	# Is the pool faulty?

	if ! zpool status $pool | egrep -s "state: ONLINE"
	then
		print "$pool is faulty"
	fi

	# Forget about FAULTED devices

	# Get all the unavailable devices and try to online them

	zpool status $pool | sed -n "/ UNAVAIL /s/^.*\(c[0-9][^ ]*\).*$/\1/p" \
	| while read device
	do

		print "onlining device $device in pool $pool"
		if zpool online $pool $device 
		then
			zpool clear $pool
		else
			ERR=$((ERR + 1))
		fi

	done

done

exit $ERR
