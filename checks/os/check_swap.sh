#!/bin/ksh

#=============================================================================
#
# check_swap.sh
# -------------
#
# Makes sure we have swap space.
#
# R Fisher 01/2009
#
# v1.0  Initial Release
#
# v1.1  Changed thresholds RDF 24/02/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

WARN=${SWAP_S_LMT:-500000}
ERROR=${SWAP_H_LMT:-200000}
	# Thresholds of free swap space, in k

EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

AVAIL=$(swap -s | sed 's/^.* \([0-9]*\)k available/\1/')

if [[ $AVAIL -lt $ERROR ]]
then
	EXIT=2
elif [[ $AVAIL -lt $WARN ]]
then
	EXIT=1
fi

if [[ -n $RUN_DIAG && $EXIT -gt 0 ]]
then
	# Not every Solaris revision's swap(1) has the -h option, but we want to
	# use it if it does

	swap -h 2>&1 | egrep -s human && OPT="-h"

	cat <<-EODIAG
	Low swap space detected.

	      swap available: ${AVAIL}k

	   warning threshold: ${WARN}k
	     error threshold: ${ERROR}k

	Output of swap -s ${OPT}:

	EODIAG

	swap $OPT -s 2>&1
	print "\nOutput of swap -l ${OPT}:\n"
	swap $OPT -l 2>&1
fi


exit $EXIT
