#!/bin/ksh

#=============================================================================
#
# check_zfs_space.sh
# ------------------
#
# Check the usage of all ZFS filesystems. The zpool space check isn't
# enough, because that won't catch zfs filesystems with quotas.
#
# R Fisher 01/2009
#
# v1.0  Initial Release
#
# v1.1  More intelligent formatting, to handle looooong dataset and
#       mountpoint names. RDF 12/02/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

SOFT=${ZFS_S_LMT:-80}	# % full that will cause a warning
HARD=${ZFS_H_LMT:-90}   # % full that will cause an error

# Counters for the times we hit the limits. Hard limits are "errors", soft
# limits are "warnings"

ERRS=0
WARN=0
EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# This is easy. Just get the % full from df, then compare it with the SOFT
# and HARD limits. Count errors and warnings, and exit accordingly.

df -nFzfs | cut -d: -f1 | while read fs
do
	FULL=$(df -v $fs | sed -n '/%$/s/^.* \([0-9]*\)%$/\1/p')

	if [[ $FULL -ge $HARD ]]
	then
		ERRS=$(($ERRS + 1))
	elif [[ $FULL -ge $SOFT ]]
	then
		WARN=$(($WARN + 1))
	fi

done

if [[ $ERRS -gt 0 ]]
then
	EXIT=2
elif [[ $WARN -gt 0 ]]
then
	EXIT=1
fi

# Diag block, if we need it

if [[ -n $RUN_DIAG && $EXIT -gt 0 ]]
then

	# Explain which filesystems are full, or nearly full. Unlike the check_
	# block, this doesn't have any concept of soft or hard limits. It just
	# reports on anything over a threshold.

	df -hFzfs | grep % | sort -nrk5 | while read dev cap use free pc mnt
	do
		pcf=${pc%%%}

		if [[ $pcf -ge $SOFT ]]
		then

			cat<<-EOMSG
			        dataset: $dev
			  capacity used: $pc
			                 (warning threshold is ${SOFT}%)
			    mount point: $mnt
			     data on fs: $(zfs get -Hovalue used $dev)
			          quota: $(zfs get -Hovalue quota $dev)

			EOMSG

		fi

	done

fi

exit $EXIT
