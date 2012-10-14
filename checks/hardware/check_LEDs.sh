#=============================================================================
#
# check_LEDs.sh
# =============
# 
# Warn if we have any non-green LEDs. Only works from the global zone.  Any
# user
#
# R Fisher 01/2009
#
# v1.0 Initial Relase
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if [[ -n $DIAG_CACHE ]] && [[ -s $DIAG_CACHE ]]
then
	sed -n '/Led State/,/^$/p' $DIAG_CACHE | grep -w on >$TMPFILE

	if [[ -z $(cat $TMPFILE) ]]
	then
		RET=4
	elif [[ -z $(egrep -v " green " $TMPFILE) ]]
	then
		RET=0
	else
		RET=2

		[[ -n $RUN_DIAG ]] && \
			sed -n '/Led State/,/^$/p' $DIAG_CACHE | grep -w on \
			| grep -v " green "
	fi

else
	RET=3
fi

exit $RET


