#!/bin/ksh

#=============================================================================
#
# check_jukebox.sh
# ----------------
#
# Looks to see if the jukebox is visible.
#
# R Fisher 03/2009
#
# v1.0 Initial Release
#
# v1.1 Now runs as non-root user, via the mon_exec_wrapper.sh RDF 05/04/09
#
# v1.2 Disregard disks, only look at /dev/rmt objects. RDF 23/08/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

INFO="$RUN_WRAP bptpcinfo"
	# Path to bptpcinfo. Who names these things?

EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if $RUN_WRAP -t bptpcinfo
then

	# Just look for two lines with the /dev/rmt reference.

	NUM=$($INFO -o - 2>/dev/null | grep -c "/dev/rmt")

	if [[ $NUM != 2 ]]
	then
		EXIT=2

		if [[ -n $RUN_DIAG ]]
		then
			cat<<-EOERR
				Expected to find two tape devices, but found ${NUM}.

				Output of 'bptpcinfo -o - | grep /dev/rmt' follows:
			EOERR

			$INFO -o - | grep "/dev/rmt"
		fi

	fi
else
	EXIT=3
fi

exit $EXIT

