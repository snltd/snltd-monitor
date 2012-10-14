#=============================================================================
#
# check_prtdiag.sh
# ================
# 
# Report if prtdiag exited non-zero when the main snltd_monitor.sh script
# ran it.
#
# R Fisher 07/2009
#
# v1.0 Initial Relase
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

E_FILE="${DIR_EXIT}/main_prtdiag.exit"

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if [[ -s $E_FILE ]]
then

	E_VAL=$(cat $E_FILE)

	if [[ $E_VAL -gt 0 ]]
	then
		print "When it was run by the main 'snltd_monitor.sh' script, prtdiag exited ${E_VAL}."
		RET=2
	fi

else
	RET=4
fi

exit $RET


