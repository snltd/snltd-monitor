#!/bin/ksh

#=============================================================================
#
# check_PSUs.sh
# -------------
# 
# Check all PSUs in the machine are powered up and functioning correctly.
# Specific to T2000 platforms.
#
# v1.0 Initial Relase
#
#=============================================================================

#[[ -s $LIBRARY ]] && . $LIBRARY || exit 254

#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if [[ -s $DIAG_CACHE ]]
then

	if grep -w PS $DIAG_CACHE | egrep -s disabled
	then
		EXIT=2
		[[ -n $RUN_DIAG ]] && egrep PS.*disabled $DIAG_CACHE
	else
		EXIT=0
	fi

else
	RET=3
fi

exit $EXIT
