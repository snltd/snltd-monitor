#=============================================================================
#
# check_reboot.sh
# ---------------
#
# Have we rebooted since last run? Zone-aware.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Changed to use new "permanent" state directroy, and smarter reporting
#      of global zone. RDF 24/02/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

EXIT=10
	# Tells the monitor not to send an "all clear" on success

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

for zone in $ZONE_LIST
do
	STATE_FILE="${DIR_PERM}/last_boot.$zone"

	zone_run "who -b" $zone >$TMPFILE

	if [[ -f $STATE_FILE ]]
	then

		if ! cmp -s $STATE_FILE $TMPFILE
		then
			EXIT=1

			if [[ -n $RUN_DIAG ]]
			then

				[[ $zone == "global" ]] \
					&& PRT="Server '$(uname -n)'" \
					|| PRT="Zone '$zone'"

				print "$PRT has rebooted since last check.\n"
				print "Output of 'who -b' follows:\n"
				cat $TMPFILE
				print
			fi

		fi

	fi
	
	mv $TMPFILE $STATE_FILE
done

exit $EXIT
