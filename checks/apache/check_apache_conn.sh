#=============================================================================
#
# check_apache_conn.sh
# --------------------
#
# Checks it can connect to Apache.
# 
# Requires curl and that APACHE_ZONES is a whitespace separated list of
# servers to connect to. Does not need any special privileges.
#
# Requires that target Apache configurations allow the connection.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
# 
# v1.1 Added max-time to cURL transer. RDF 30/11/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

CURL="${DIR_BIN}/curl"
	# Path to curl binary. Part of the monitor distribution

EXIT=0
TO=5
	# Timeout for cURL

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

[[ -x $CURL ]] && [[ -n $APACHE_ZONES ]] \
	|| exit 3

for zone in $APACHE_ZONES
do
	URL="http://${zone}"

	$CURL \
		--connect-timeout $TO \
		--max-time $(($TO + 2)) \
		--fail \
		--silent \
		-o /dev/null \
	 "$URL" 
	
	CURL_RET=$?

	if [[ $CURL_RET != 0 ]]
	then
	 	ERRORS=1

		[[ -n $RUN_DIAG ]] \
			&& cat<<-EODIAG
			Failed to connect to Apache server on ${zone} with ${TO}s timeout.
			
			curl returned ${CURL_RET}. Error diagnosis follows:

			$(curl_diag $CURL_RET)

			EODIAG

	fi

done

if [[ -n $ERRORS ]]
then
	EXIT=2
else
	EXIT=0
fi

exit $EXIT

