#!/bin/ksh

#=============================================================================
#
# check_PSUs.sh
# -------------
# 
# Check all PSUs in the machine are powered up and functioning correctly.
#
# R Fisher 01/2009
#
# v1.0 Initial Relase
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if [[ -n $DIAG_CACHE ]] && [[ -s $DIAG_CACHE ]]
then

	if [[ -n $(egrep P_PWR $DIAG_CACHE | egrep -v okay$) ]]
	then
		RET=2

		[[ -n $RUN_DIAG ]] && \
			egrep "P_PWR" $DIAG_CACHE | egrep -v okay$

	else
		RET=0
	fi

else
	RET=4
fi

exit $RET


