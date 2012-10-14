#=============================================================================
#
# check_3510_enclosure.sh
# -----------------------
#
# Get and examine diagnostics  from the 3510. This ought to catch anything
# physically or electrically wrong with it, including completely failted
# disks or controllers. 
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

if print "show enclosure-status" | $SCCLI >$TMPFILE 2>/dev/null
then

	if egrep -s Fault $TMPFILE
	then
		EXIT=2

		[[ -n $RUN_DIAG ]] \
			&& cat $TMPFILE

	fi

else
	EXIT=4
fi

exit $EXIT
