#!/bin/ksh

#=============================================================================
#
# check_dav_write.sh
# ------------------
#
# Checks we can upload a file to webDAV.
#
# Requires curl and that DAV_S_LIST is a whitespace separated list of
# servers to connect to.
#
# Requires that target Apache configurations allow the connection, and that
# the file is there. How to set up the DAV server is in the wiki.
#
# R Fisher 03/2009
#
# v1.0 Initial Release
#
#=============================================================================

. $LIBRARY

#-----------------------------------------------------------------------------
# VARIABLES

EXIT=0

SOURCE="${DIR_STATE}/dav_testfile_write"

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

can_has curl && [[ -n $DAV_S_LIST ]] || exit 3

date >$SOURCE

for server in $DAV_S_LIST
do
	URL="https://${server}/snltd_monitor/"

	# Curl. Don't worry about --insecure. It just tells it not worry about
	# the self-signed cert we use on the dav server. --fail tells curl to
	# properly fail if it can't get the file - without it, you get exit 0
	# and the web server's output in the $SOURCE file.

	curl --fail \
		--connect-timeout 4 \
		--max-time 6 \
		--silent \
		--insecure \
		--config ${DIR_CONFIG}/dav_connect \
		--upload-file $SOURCE \
	$URL

	CURL_RET=$?

	if [[ $CURL_RET != 0 ]] || [[ ! -s $SOURCE ]]
	then
	 	ERRORS=1

		[[ -n $RUN_DIAG ]] \
			&& cat <<-EOERR
			Failed to transfer test file over webDAV.

			     server: $server
			        url: $URL
			  curl exit: $CURL_RET
			     target: $SOURCE

			curl diagnostic follows:
			$(curl_diag $CURL_RET)

			EOERR
	fi

done

if [[ -n $ERRORS ]]
then
	EXIT=2
else
	EXIT=0
fi

exit $EXIT

