#!/bin/ksh

#=============================================================================
#
# check_remote_mon.sh
# -------------------
#
# Check the monitor daemon is running on remote servers. Error if anything's
# down. Requires MON_HOSTS to be defined in the server config file. That's
# a whitespace separated list of hostnames.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Now also checks the elapsed time since each remote monitor last
#      performed a full check. If that time is more than LAST_THRESHOLD, a
#      warning is triggered. RDF 16/06/09
#
# v1.2 Added SSH_TIMEOUT variable. Seems we weren't giving it long enough
#      before. RDF 19/06/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

EXIT=0
	# Assume everything's going to be up. That's the spirit!

SSH="${DIR_BIN}/ssh"
	# We use our own OpenSSH binary, because it supports essential options
	# which Sun's SSH doesn't. (Yet.)

LAST_THRESHOLD="3600"
	# The number of seconds within which each remote monitor must have
	# completed its checks

SSH_TIMEOUT=10
	# Max time for SSH connections

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if [[ -n $MON_HOSTS ]]
then

	[[ -x $SSH ]] || exit 4

	TIME_NOW=$(get_epoch_time)

	for host in $MON_HOSTS
	do

		RET_STR=$($SSH \
			-q \
			-o "BatchMode=yes" \
			-o "StrictHostKeyChecking=no" \
			-o "ConnectTimeout=$SSH_TIMEOUT" \
			$host \
			"pgrep -f snltd_monitor/bin/snltd_monitor_daemon.sh"
		)

		RET_C=$?

		# SSH returns:
		#     0 if the command was exectuted, and worked
		#   255 if it can't make a connection
		#    >0 if the command was executed, but failed

		if [[ $RET_C == 0 ]]
		then
				:
		elif [[ $RET_C == 255 ]]
		then
			WARNINGS=1

			[[ -n $RUN_DIAG ]] \
				&& print "  SSH connection refused by '$host'."

		else
			ERRORS=1

			if [[ -n $RUN_DIAG ]]
			then
				cat<<-EODIAG

				pgrep on '$host' returned ${RET_C}.

				Command output follows, no output suggests no monitor daemon is
				running.

				-------- BEGIN OUTPUT ------

				$RET_STR

				----------END OUTPUT -------

				EODIAG

			fi

		fi

		# If we were able to communicate with the remote host, examine its
		# "last_run" file, and see how long it is since a successful audit
		# was complete.

		if [[ $RET_C -ne 255 ]]
		then
			LAST_RUN=$($SSH \
				-q \
				-o "BatchMode=yes" \
				-o "StrictHostKeyChecking=no" \
				-o "ConnectTimeout=$SSH_TIMEOUT" \
				$host \
				"cat /var/snltd/monitor/logs/last_run"
			)

			RET_C=$?

			if [[ $RET_C -ne 0 ]]
			then
				WARNINGS=1

				[[ -n $RUN_DIAG ]] \
					&& print "no 'last_run' file on ${host}."

			else
				# We know when the remote monitor last ran, we know the time
				# now, so let's work out the time difference in seconds, and
				# compare it to LAST_THRESHOLD

				DELTA_T=$(( $TIME_NOW - $LAST_RUN))

				if [[ $DELTA_T -gt $LAST_THRESHOLD ]]
				then
					ERRORS=1

					if [[ -n $RUN_DIAG ]]
					then
						cat<<-EODIAG

						On host '$host':

						   time since monitor completed (s): $DELTA_T

						               Warning thresold (s): $LAST_THRESHOLD

						EODIAG
					fi

				fi

			fi


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
