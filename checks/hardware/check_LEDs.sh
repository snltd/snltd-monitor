#!/bin/ksh

#=============================================================================
#
# check_LEDs.sh
# =============
#
# Warn if we have any non-green LEDs. Only works from the global zone.  Any
# user
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
	sed -n '/Led State/,/^$/p' $DIAG_CACHE | grep -w on >$TMPFILE

	if [[ -s $TMPFILE ]]
	then
		EXIT=4
	elif [[ -z $(egrep -v " green " $TMPFILE) ]]
	then
		EXIT=0
	else
		EXIT=2

		[[ -n $RUN_DIAG ]] && \
			sed -n '/Led State/,/^$/p' $DIAG_CACHE | grep -w on \
			| grep -v " green "
	fi

else
	EXIT=3
fi

exit $EXIT


