#=============================================================================
#
# check_diag.sh
# =============
# 
# Just look for "fail"s in the output of prtdiag -v
#
# R Fisher 07/2009
#
# v1.0 Initial Release
#
# v1.1 Changed the grep string from "fail" to "failed", because v245s have a
#      FANFAIL light, which, even if it's off, is in the prtdiag output. RDF
#      21/07/09.
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if [[ -n $DIAG_CACHE ]] && [[ -s $DIAG_CACHE ]]
then

	if egrep -is "failed" $DIAG_CACHE && [[ -n $RUN_DIAG ]]
	then
		egrep -i "failed" $DIAG_CACHE
		RET=2
	fi

else
	RET=4
fi

exit $RET


