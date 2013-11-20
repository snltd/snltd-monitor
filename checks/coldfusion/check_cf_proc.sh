#!/bin/ksh

#=============================================================================
#
# check_cf_proc.sh
# ----------------
#
# Checks for Coldfusion processes.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
#=============================================================================

. $LIBRARY

#-----------------------------------------------------------------------------
# VARIABLES

# The list of zones to study can be defined in the server config file.
# If one isn't given, we look at all zones.

CF_ZONES=${CF_ZONES:=$ZONE_LIST}

DIR_CF="/usr/local/coldfusion"

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

is_global || exit 3

for zone in $CF_ZONES
do
	# There should be two bin/coldfusion processes running

	PROCS=$(pgrep -fz $zone bin/coldfusion 2>/dev/null | wc -l)
	PROCS=${PROCS##* }

	if [[ $PROCS -ne 2 ]]
	then
		# Do we think there should be Coldfusion running here?

		[[ -d $DIR_CF ]] || continue

		# Any missing (or extra) processes means we flag an error

		ERRORS=true

		[[ -n $RUN_DIAG ]] \
			&& cat<<-EOOUT
			In zone '$zone':

			Expected two bin/coldfusion processes, but found ${PROCS}.

			Output of

			  pgrep -fl -z $zone bin/coldfusion

			follows:

			  ---------- BEGIN OUTPUT ------------

				$(pgrep -fl -z $zone bin/coldfusion)

			  ----------- END OUTPUT -------------
			EOOUT

	else
		FOUND=1
	fi


done

if [[ -n $ERRORS ]]
then
	EXIT=2
elif [[ -n $FOUND ]]
then
	EXIT=0
else
	EXIT=3
fi

exit $EXIT
