#!/bin/ksh

#=============================================================================
#
# check_verity_procs.sh
# ---------------------
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
# If one isn't given, we look at coldfusion zones

V_ZONES=${V_ZONES:=$CF_ZONES}

DIR_CF="/usr/local/coldfusion"

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

is_global || exit 3

for zone in $V_ZONES
do
	# There should be two bin/coldfusion processes running

	PROCS=$(pgrep -fz $zone $DIR_CF/verity 2>/dev/null | wc -l)
	PROCS=${PROCS##* }

	if [[ $PROCS -lt 2 ]]
	then
		# Do we think there should be Verity running here?

		[[ -d $DIR_CF ]] || continue

		# Any missing (or extra) processes means we flag an error

		ERRORS=true

		[[ -n $RUN_DIAG ]] \
			&& cat<<-EOOUT
			In zone '$zone':

			Expected at least two verity processes, but found ${PROCS}.

			Output of

			  pgrep -fl -z $zone ${DIR_CF}/verity

			follows:

			  ---------- BEGIN OUTPUT ------------

				$(pgrep -fl -z $zone ${DIR_CF}/verity)

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

