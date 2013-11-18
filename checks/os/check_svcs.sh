#!/bin/ksh

#=============================================================================
#
# check_svcs.sh
# -------------
#
# Look for any zones on the machine that has services in a faulted state.
#
# R Fisher 01/2009
#
# v1.0 Initial Release
#
#=============================================================================

. $LIBRARY

#-----------------------------------------------------------------------------
# VARIABLES

EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# Bail if we don't have SMF on this machine.

can_has svcs && [[ -n $ZONE_LIST ]] \
	|| exit 3

# Run in every zone, using the handy zone_run function from the library. As
# soon as we find a zone with faulted services, exit the loop and flag an
# error

for zone in $ZONE_LIST
do

	if [[ -n $(zone_run "svcs -x" $zone) ]]
	then
		EXIT=2
		break
	fi

done

# Diag block, if we need it

if [[ -n $RUN_DIAG && $EXIT -gt 0 ]]
then

	# Run in every zone, using the handy zone_run function from the library.

	for zone in $ZONE_LIST
	do

		if [[ -n $(zone_run "svcs -x" $zone) ]]
		then
			print "\nin zone '$zone'\n"
			zone_run "svcs -xv" $zone
		fi

	done

fi

exit $EXIT
