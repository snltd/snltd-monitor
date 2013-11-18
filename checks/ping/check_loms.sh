#!/bin/ksh

#=============================================================================
#
# check_loms.sh
# -------------
#
# Ping host LOMs. Error if anything's down. Requires PING_HOSTS to be
# defined in the server config file. That's a whitespace separated list of
# hostnames. Also requires PING_LOMS to be defined.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Use OMIT_LOMS variable. RDF 25/04/10
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

EXIT=0
	# Assume everything's going to be up. That's the spirit!

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if [[ -n $PING_HOSTS && -n $PING_LOMS ]]
then

	for host in $PING_HOSTS
	do

		[[ $OMIT_LOMS == *" $host "* ]] \
			&& continue

		# Local site naming convention is to attach -lom to a hostname for
		# the LOM. You may need to change this.

		host="${host}-lom"

		RESPONSE=$(ping $host 2 2>&1)

		if [[ $RESPONSE == "no answer"* ]]
		then
			ERRORS=1

			[[ -n $RUN_DIAG ]] \
				&& print "  LOM '$host' not responding to ping."

		elif [[ $RESPONSE == *"unknown host"* ]]
		then
			WARNINGS=1

			[[ -n $RUN_DIAG ]] \
				&& print "  LOM name '$host' does not resolve."

		elif [[ $RESPONSE == *"is alive" ]]
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
