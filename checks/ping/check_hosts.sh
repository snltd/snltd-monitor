#=============================================================================
#
# check_hosts.sh
# --------------
#
# Ping hosts. Error if anything's down. Requires PING_HOSTS to be defined in
# the server config file. That's a whitespace separated list of hostnames.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

EXIT=0
	# Assume everything's going to be up. That's the spirit!

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if [[ -n $PING_HOSTS ]]
then

	for host in $PING_HOSTS
	do
		RESPONSE=$(ping $host 2 2>&1)

		if [[ $RESPONSE == "no answer"* ]]
		then
			ERRORS=1
		
			[[ -n $RUN_DIAG ]] \
				&& print "  host '$host' not responding to ping."

		elif [[ $RESPONSE == *"unknown host"* ]]
		then
			WARNINGS=1

			[[ -n $RUN_DIAG ]] \
				&& print "  host '$host' not resolving."

		elif [[ $RESPONSE == *"is alive"* ]]
		then
			:
		else
			ERRORS=1

			[[ -n $RUN_DIAG ]] \
				&& print "  unknown error:\n\n  $RESPONSE"

		fi

	done

else
	EXIT=3
fi

if [[ -n $ERRORS ]]
then
	EXIT=2
elif [[ -n $WARNINGS ]]
then
	EXIT=1
fi

exit $EXIT
