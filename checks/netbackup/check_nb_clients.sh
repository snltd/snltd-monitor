#=============================================================================
#
# check_netbackup_clients.sh
# --------------------------
#
# See if we can connect to a list of Netbackup clients. Requires the
# "NB_CLIENT_LIST" variable is defined in the machine config file
#
# R Fisher 03/2009
#
# v1.0 Initial Release
#
# v1.1 Now runs as non-root user, via the mon_exec_wrapper.sh RDF 05/04/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

TESTCMD="$RUN_WRAP bptestbpcd"

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if [[ -n $NB_CLIENT_LIST ]] && $RUN_WRAP -t bptestbpcd
then

	for host in $NB_CLIENT_LIST
	do

		# See if the host is up first, because bptestbpcd (who think of
		# these command names?) takes ages to time out

		if ping $host 1 >/dev/null 2>&1
		then
			$TESTCMD -host $host  >/dev/null 2>&1
			RET=$?

			if [[ $RET != 0 ]]
			then
				ERRORS=1

				[[ -n $RUN_DIAG ]] \
					&& print \
					"Could not connect to '${host}'. bptestbpcd exited ${RET}."

			fi

		else
			WARNINGS=1

			[[ -n $RUN_DIAG ]] \
				&& print "Could not ping host '${host}'."

		fi

	done

	if [[ -n $ERRORS ]]
	then
		EXIT=2
	elif [[ -n $WARNING ]]
	then
		EXIT=1
	else
		EXIT=0
	fi

else
	EXIT=3
fi

exit $EXIT
