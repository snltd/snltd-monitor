#=============================================================================
#
# check_ufs_space.sh
# ------------------
#
# R Fisher 01/2009
#
# Check the usage of all UFS filesystems
#
# v1.0 Initial Relase
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

typeset -L15 mnt dev
	# For formatting

SOFT=80	# % full that will cause a warning
HARD=90 # % full that will cause an error

# Counters for the times we hit the limits. Hard limits are "errors", soft
# limits are "warnings"

ERRS=0 
WARN=0
EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# This is easy. Just get the % full from df, then compare it with the SOFT
# and HARD limits. Count errors and warnings, and exit accordingly.

df -nFufs | cut -d: -f1 | while read fs
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

	df -vFufs | grep %$ | sort -nrk6 | while read mnt dev blk use free pc
	do
		pcf=${pc%%%}
		[[ $pcf -ge $SOFT ]] && print "  $mnt [$dev] at $pc"
	done

fi

exit $EXIT
