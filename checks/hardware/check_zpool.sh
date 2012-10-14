#=============================================================================
#
# check_zpool.sh
# --------------
#
# Check the status of all the ZFS pools on the box
#
# R Fisher 01/2009
#
# v1.0 Initial Release
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

can_has zpool \
	|| exit 3

[[ $(zpool list) == "no pools available" ]] \
	&& exit 3

if zpool status | grep state: | egrep -sv ONLINE 
then
	 EXIT=2
elif zpool status | egrep -s "scrub: resilver in progress"
then
	EXIT=1
else
	EXIT=0
fi

# Diag code, if we need it

if [[ $EXIT -gt 0 ]] && [[ -n $RUN_DIAG ]]
then
	zpool list -Ho name | while read pool
	do
		# Is the pool not ONLINE?

		if ! zpool status $pool | egrep -s "state: ONLINE"
		then
			print "$pool is faulty"
			zpool status $pool
		elif zpool status space | egrep -s "scrub: resilver"
		then
			zpool status $pool | egrep %
		fi

	done
fi

exit $EXIT
