#!/bin/ksh

#=============================================================================
#
# check_apache_proc.sh
# --------------------
#
# Checks for the right number of Apache httpd processes. Does not need any
# special privileges.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v2.0 Smarter rewrite. RDF 23/02/09
#
# v2.1 Get netstat info RDF 28/04/09
#
# v2.2 Raised PROC_MAX RDF 15/10/09
#
#=============================================================================

. $LIBRARY

#-----------------------------------------------------------------------------
# VARIABLES

PROC_MIN=2
PROC_MAX=75
	# Minimum and maximum httpd processes we expect to find

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

is_global || exit 3

# The list of zones to study can be defined in the server config file.
# If one isn't given, we look at all zones and find ones with an Apache
# directory.

ZONES=${APACHE_ZONES:=$(get_apache_zones $ZONE_LIST)}

# Exit if there are no zones to study

[[ -n $ZONES ]] || exit 3

for zone in $ZONES
do

	# See how many httpd process are running, and check it lies inside the
	# allowable limits

	HCNT=$(pgrep -z $zone httpd | wc -l)
	HCNT=${HCNT##* }

	if (( $HCNT < $PROC_MIN || $HCNT > $PROC_MAX ))
	then

		[[ $HCNT == 0 ]] \
			&& ERRORS=1 \
			|| WARNINGS=1

		if [[ -n $RUN_DIAG ]]
		then
			cat<<-EOOUT
In zone '$zone':

Found Apache directory ${DIR_APACHE}.

Expected between $PROC_MIN and $PROC_MAX httpd processes, but found ${HCNT}.

Output of 'netstat -an' follows:

			EOOUT
			zone_run "netstat -an" $zone
			print
		fi

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
