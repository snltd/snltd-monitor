#=============================================================================
#
# check_zfs_space.sh
# ------------------
#
# Check free space in all the zpools on the box.  Percent usage greater than
# WARN is a warning, greater than ERROR is, yes, an error.
#
# R Fisher 01/2009
#
# v1.0 Initial Release
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

WARN=80
ERROR=90

EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if can_has zpool && [[ $(zpool list) != "no pools available" ]]
then

	zpool list -Hocapacity | while read use
	do
		PCU=${use%%%}

		if [[ $PCU -gt $ERROR ]]
		then
			ERRORS=true
		elif [[ $PCU -gt $WARN ]]
		then
			WARNS=true
		fi

	done

	if [[ -n $ERRORS ]]
	then
		EXIT=2
	elif [[ -n $WARNS ]]
	then
		EXIT=1
	fi

	# Diag block, if we need it

	if [[ -n $RUN_DIAG && -n "${ERRORS}$WARNS" ]]
	then

		zpool list -Honame,capacity | while read pool use
		do
			PCU=${use%%%}

			[[ $PCU -gt $WARN ]] \
				&& print "  pool '$pool' at $use capacity."

		done

	fi

else
	EXIT=3
fi

exit $EXIT
