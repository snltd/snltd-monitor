#!/bin/ksh

#=============================================================================
#
# check_apache_dav_proc.sh
# ------------------------
#
# Checks for the right number of Apache httpd processes. Just a slightly
# changed version of check_apache_proc.sh
#
# R Fisher 03/2009
#
# v1.0 Initial Release
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

PROC_MIN=2
PROC_MAX=10
	# Minimum and maximum httpd processes we expect to find. Much tighter
	# than for a standard Apache server.

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

is_global && [[ -n $DAV_ZONES ]] || exit 3

for zone in $DAV_ZONES
do

	# See how many httpd process are running, and check it lies inside the
	# allowable limits

	HCNT=$(pgrep -z $zone httpd | wc -l)
	HCNT=${HCNT##* }

	if (( $HCNT < $PROC_MIN || $HCNT > $PROC_MAX ))
	then
		[[ $HCNT == 0 ]] && ERRORS=1 || WARNINGS=1

		[[ -n $RUN_DIAG ]] && cat<<-EOOUT
In zone '$zone':

Expected between $PROC_MIN and $PROC_MAX httpd processes, but found ${HCNT}.

			EOOUT

	fi

done

if [[ -n $ERRORS ]]
then
	EXIT=2
elif [[ -n $WARNINGS ]]
then
	EXIT=1
else
	EXIT=0
fi

exit $EXIT

