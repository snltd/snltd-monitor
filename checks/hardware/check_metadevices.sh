#!/bin/ksh

#=============================================================================
#
# check_metadevices.sh
# --------------------
#
# Errors or warns if anything's in a state other than Okay. Only works
# from the global zone. Any user.
#
# R Fisher 01/2009
#
# v1.0 Initial Relase
#
#=============================================================================

. $LIBRARY

#-----------------------------------------------------------------------------
# VARIABLES

EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# Metastat is such a cheap operation we can run it a couple of times

if can_has metastat && metadb >/dev/null 2>&1
then

	if metastat | egrep -s Maintenance
	then
		EXIT=2
	elif metastat | egrep -s Resyncing
	then
		EXIT=1
	else
		EXIT=0
	fi

	# Diag code, if we need it.

	if [[ $EXIT -gt 0 ]] && [[ -n $RUN_DIAG ]]
	then

		metastat | egrep Mirror | while read dev junk
		do
			topdev=${dev%:}
			unset STATE

			mpt=$(df -h | sed -n "/dsk\/$topdev /s/^.* //p")

			[[ -z $mpt ]] && swap -l | egrep -s "dsk/$topdev" && mpt="swap"

			if metastat $topdev | egrep -si Resyncing
			then
				STATE="Resyncing"
				EXTRA=" ($(metastat $topdev | sed -n '/%/s/^.*: //p'))"
			elif metastat $topdev | egrep -si Maintenance
			then
				STATE="Needs maintenance"
			fi

			if [[ -n $STATE ]]
			then
				# Tell sed to get the lines preceding the STATE in topdev's
				# metastat output. One of those lines will begin with the
				# name of the metadevice which is in the given STATE.

				subdev=$(metastat $topdev | sed -n -e \
				"/${STATE}/{g;1!p;};h" -e h | sed -n '/^d/s/:.*$//p')

				print -n "md $subdev in state \"$STATE\"${EXTRA}. "
				print "Part of $topdev, mounted on $mpt"
			fi

		done

	fi

else
	EXIT=3
fi

exit $EXIT
