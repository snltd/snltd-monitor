#=============================================================================
#
# check_3510_redundancy.sh
# ------------------------
#
# Get information on the redundancy state of the 3510.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Uses mon_exec_wrapper.sh RDF 23/03/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

DEF_MODE="Active-Active"
	# The redundancy mode we expect to find

DEF_STAT="Enabled"

SCCLI="$RUN_WRAP sccli"

EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

${SCCLI% *} -t sccli \
    || exit 3

# Query the 3510 once, and cache the info in a temp file

if print "show redundancy-mode" | $SCCLI >$TMPFILE 2>/dev/null
then

	MODE=$(sed -n "/Redundancy mode/s/^.*: //p" $TMPFILE)
	STAT=$(sed -n "/Redundancy status/s/^.*: //p" $TMPFILE)

	if [[ $MODE != $DEF_MODE ]]
	then
		EXIT=2

		if [[ -n $RUN_DIAG ]]
		then
			print "      Expected redundancy mode: $DEF_MODE"
			print "       Current redundancy mode: $MODE"
		fi

	fi

	# Now look at the redundancy status

	if [[ $STAT != $DEF_STAT ]]
	then
		EXIT=2

		if [[ -n $RUN_DIAG ]]
		then
			print "    Expected redundancy status: $DEF_STAT"
			print "     Current redundancy status: $STAT"
		fi

	fi

else
	EXIT=4
fi

exit $EXIT
