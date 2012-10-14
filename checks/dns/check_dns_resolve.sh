#=============================================================================
#
# check_dns_resolve.sh
# --------------------
#
# Checks BIND works
#
# Requires a 'dig' binary in bin/arch/ and DNS_SERVERS to be defined in the
# machine config file.
#
# Can use DNS_Q_LIST variables in the machine config file. This takes the
# form DNS_Q_LIST=dns_server@name,addr:dns_server@name,addr....
# where dns_server is the server to send the request to, name is the name to
# look up, and addr is the address we expect back
#
# R Fisher 03/2009
#
# v1.0 Initial Release
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# We need a dig binary

can_has dig \
	|| exit 3

# We need a DNS_Q_LIST

[[ -n $DNS_Q_LIST ]] \
	|| exit 3

# Parse the DNS_SRV list

for entry in $(print $DNS_Q_LIST | tr ":" " ")
do
	server=${entry%@*}
	question=${entry#*@}
	question=${question%,*}
	expected=${entry#*,}

	answer=$(dig \
		+time=1 \
		+short \
		$question \
		@$server 2>&1)

	if [[ "$answer" == "$expected" ]]
	then
		:
	elif [[ "$answer" == *"connection timed out"* ]]
	then
		ERROR=1

		[[ -n $RUN_DIAG ]] \
			&& print "connection timed out on ${server}."

	else
		WARNING=1
		[[ -n $RUN_DIAG ]] \
			&& cat<<-EOERR
			Unexpected response from ${server}.

			  looked up: $question
			   expected: $expected
			        got: $answer

			EOERR
	fi

done

if [[ -n $ERROR ]]
then
	EXIT=2
elif [[ -n $WARNING ]]
then
	EXIT=1
else
	EXIT=0
fi

exit $EXIT

