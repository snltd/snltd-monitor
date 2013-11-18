#!/bin/ksh

#=============================================================================
#
# check_3510_disks.sh
# -------------------
#
# Get and examine information on all the disks in the 3510.
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

${SCCLI% *} -t sccli || exit 3

if print "show disks" | $SCCLI >$TMPFILE 2>/dev/null
then

	if [[ -n $(awk '{ print $6 }' $TMPFILE | egrep -v \
	"^Status$|^$|^ONLINE$") ]]
	then
		EXIT=2
		[[ -n $RUN_DIAG ]] && cat $TMPFILE
	fi

else
	EXIT=4
fi

exit $EXIT
