#!/bin/ksh

#=============================================================================
#
# check_cf_conn.sh
# ----------------
#
# Checks it can connect to Coldfusion.  Requires a very basic ColdFusion
# page called "snltd_monitor.sh" is in the document root of the default
# vhost.
#
# Requires curl, and that CF_ZONES is a whitespace separated list of servers
# to connect to.
#
# Requires that target Apache configurations allow the connection. For
# dev-01 zones I've added cs-dev-01z-ngfl.gov.uk to the allow line on the
# default vhost. For cs-w-01 I added cs-w-01z-ngfl.gov.uk etc.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Better error reporting. RDF 23/03/09
#
#=============================================================================

. $LIBRARY

#-----------------------------------------------------------------------------
# VARIABLES

REM_FILE="snltd_monitor.cfm"
	# Remote file to get

REM_STR="^CONNECTED$"
	# String to look for in remote file

EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

can_has curl || exit 3

[[ -n $CF_ZONES ]] || exit 3

for zone in $CF_ZONES
do

	URL="http://${zone}/$REM_FILE"

	curl \
		--connect-timeout 2 \
		--fail \
		--silent \
	"$URL" >$TMPFILE

	CURL_RET=$?

	if [[ $CURL_RET == 0 ]] && egrep -s "$REM_STR" $TMPFILE
	then
		FOUND=1
	else
	 	ERRORS=1

		[[ -n $RUN_DIAG ]] \
			&& cat<<-EOOUT

			Failed to successfully retrieve '${REM_FILE}' from

				$URL

			This may indicate a failure in either Coldfusion or Apache.

			curl returned ${CURL_RET}. Error diagnosis follows:

			$(curl_diag $CURL_RET)

			Contents of downloaded file (if any) follow:

			--- BEGIN RETRIEVED FILE ---

			$(cat $TMPFILE)

			---- END RETRIEVED FILE ----
			EOOUT

	fi

done

if [[ -n $ERRORS ]]
then
	EXIT=2
elif [[ -n $FOUND ]]
then
	EXIT=0
else
	EXIT=3
fi

exit $EXIT

