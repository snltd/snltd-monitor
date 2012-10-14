#=============================================================================
#
# check_3510_batteries.sh 
# -----------------------
#
# Check the batteries.  Expired means a warning, a status other than "OK" is
# a fault. 
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

SCCLI="$RUN_WRAP sccli"

EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

${SCCLI% *} -t sccli \
	|| exit 3

# Query the 3510 once, and cache the info in a temp file.

if print "show battery-status" | $SCCLI >$TMPFILE 2>/dev/null
then

	BATT_EXP_INFO=$(grep "Expiration Status:" $TMPFILE | egrep -v "OK$")

	if [[ -n $BATT_EXP_INFO ]]
	then
		EXIT=1

		[[ -n $RUN_DIAG ]] \
			&& print "  $BATT_EXP_INFO"

	fi

	# Now look to see if the batteries are functioning

	BATT_STAT_INFO=$(grep "Hardware Status:" $TMPFILE | egrep -v "OK$")

	if [[ -n $BATT_STAT_INFO ]]
	then
		EXIT=2

		[[ -n $RUN_DIAG ]] \
			&& print "  $BATT_STAT_INFO"

	fi
else
	EXIT=4
fi

exit $EXIT

