#!/bin/ksh

#=============================================================================
#
# check_nb_logs.sh
# ----------------
#
# Examines the output of bpdbjobs to see if anything has failed.
#
# R Fisher 03/2009
#
# v1.0 Initial Release
#
# v1.1 Now runs as non-root user, via the mon_exec_wrapper.sh RDF 05/04/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

BPDBJOBS="$RUN_WRAP bpdbjobs"

typeset -i FAILS=0

EXIT=0

STATE_FILE="${DIR_STATE}/nbjobs"
	# Marker file

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if $RUN_WRAP -t bpdbjobs
then
	RUN_DIAG=1

	if [[ -f $STATE_FILE ]]
	then
		TSTAMP=$(cat $STATE_FILE)
	else
		TSTAMP=$(get_epoch_time)
	fi

	print "$TSTAMP"
	$BPDBJOBS -most_columns | \
		nawk -v val=$TSTAMP -F, '
				($9 > val && $4 > 0) {
					print $1
				}' \
		| while read id
	do
		((FAILS += 1))
		FAILLIST="$FAILLIST,$id"
	done

	if [[ $FAILS -gt 0 ]]
	then
		EXIT=2

		if [[ -n $RUN_DIAG ]]
		then
			print "Found $FAILS failed NetBackup jobs. bpdbjobs output follows:\n"

			$BPDBJOBS -jobid ${FAILLIST#,}
		fi

	fi

else
	EXIT=3
fi

exit $EXIT

