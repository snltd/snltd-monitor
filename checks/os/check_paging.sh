#!/bin/ksh

#=============================================================================
#
# check_paging.sh
# ---------------
#
# Look to see if there's any anonymous paging on the box.
#
# R Fisher 01/2009
#
# v1.0 Initial Release
#
# v2.0 Rewritten to print diagnostic info. RDF 19/02/09
#
# v2.1 Beefed up diagnostics. RDF 23/02/09
#
# v2.2 Added ANON_PG_LIM variable. RDF 21/07/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

EXIT=0

ANON_PG_LIM=${ANON_PG_LIM:-0 0 0}
	# Three numbers, which are the allowable values of api apo apf

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# Just get a bit of vmstat info, shovel it into variables, and see if
# there's more anonymous paging activity than there should be. We used to
# flag a warning if there was any paging, but now we allow a certain amount
# on certain machines. The limit is defined by the ANON_PG_LIM variable

vmstat -p 2 2 > $TMPFILE

tail -1 $TMPFILE | read swap free re mf fr de sr epi epi epf api apo apf junk

print $ANON_PG_LIM | read apil apol apfl

# If any of the three limits are exceeded, that's a warning

if [[ $api -gt $apil || $apo -gt $apol || $apf -gt $apfl ]]
then
	EXIT=1

	if [[ -n $RUN_DIAG ]]
	then
		cat $TMPFILE
		print "\nOutput of 'prstat -Zn10 -s size' follows:\n"
		prstat -Zn10 -s size 1 1
	fi

fi

exit $EXIT
