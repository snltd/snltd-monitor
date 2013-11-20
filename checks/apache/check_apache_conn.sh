#!/bin/ksh

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

. $LIBRARY

#-----------------------------------------------------------------------------
# VARIABLES

CURL="${DIR_BIN}/curl"
	# Path to curl binary. Part of the monitor distribution
EXIT=0
TO=5
	# Timeout for cURL

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

ZONES=${APACHE_ZONES:=$(get_apache_zones $ZONE_LIST)}

[[ -x $CURL ]] && [[ -n $APACHE_ZONES ]] || exit 3

for zone in $ZONES
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
	 	EXIT=2

		[[ -n $RUN_DIAG ]] \
			&& cat<<-EODIAG
			Failed to connect to Apache server on ${zone} with ${TO}s timeout.

			curl returned ${CURL_RET}. Error diagnosis follows:

			$(curl_diag $CURL_RET)

			EODIAG

	fi

done

exit $EXIT

