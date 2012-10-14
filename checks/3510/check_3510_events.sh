#=============================================================================
#
# check_3510_events.sh
# --------------------
#
# Report any events from the 3510's log which have been written today.
# Notifications are a warning, Alerts are errors. Like the cron checker,
# reports "OK" if there are no NEW error messages. So, you can get a
# hundered errors from today's event log, but if the script thinks they've
# already been told about, it will say "ok".
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Uses mon_exec_wrapper.sh RDF 23/03/09
#
# v1.2 Fixed to stop ever-recurring messages, which were a result of storing
#      only the last messages sent. RDF 17/07/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

LAST_BLOCK="${DIR_STATE}/3510_event.log"
	# Where we keep the output from the 3510

SCCLI="$RUN_WRAP sccli"

EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

${SCCLI% *} -t sccli \
    || exit 3

# 3510 event log is not a nice thing to analyze programmatically. Events are
# written over multiple lines, separated by blank lines. Dates are of the
# form "Day Mon DD HH:MM:SS YYYY"

MATCH=$(date "+%a %h %e ")

# Get today's events. Because there are repeat lines in the event log, we
# have to get ALL today's events. For that reason, LAST_BLOCK will hold a
# complete copy of today's events.

if print "show events" | $SCCLI 2>/dev/null >$TMPFILE 
then

	# Cut out today's events. We used to do this straight from the sccli
	# line, but we can't any more, because the sed will always return true

	mv $TMPFILE ${TMPFILE}.2

	sed -n "/^$MATCH/,\$p" ${TMPFILE}.2 >$TMPFILE
	rm ${TMPFILE}.2

	# Now, TMPFILE holds today's event log. If the file is empty, there are
	# no events and, we're done. Exit 10 so there's no all clear

	[[ -s $TMPFILE ]] \
		|| exit 10

	# There are events. Can we remember the events we reported before? If we
	# can, we'd better check they weren't exactly the same as we have now

	if [[ -f $LAST_BLOCK ]]
	then

		# If we have exactly the same events, exit 10. We've nothing more to
		# report.

		cmp -s $TMPFILE $LAST_BLOCK \
			&& exit 10

		# There are new lines. Get them, and put them into $TMPFILE.2

		comm -23 $TMPFILE $LAST_BLOCK >${TMPFILE}.2

		# Now put all today's events into LAST_BLOCK

		mv $TMPFILE $LAST_BLOCK
		
		# And move TMPFILE.2 to TMPFILE

		mv ${TMPFILE}.2 $TMPFILE
	else
		cp $TMPFILE $LAST_BLOCK
	fi

	# Whether we've been comparing or not, TMPFILE contains the events we're
	# interested in. Look to see if there's an "Alert". If there is, this is
	# an ERROR. If not, it's a WARNING

	egrep -s "Alert" $TMPFILE \
		&& EXIT=2 \
		|| EXIT=1

	# Print out the messages from today

	[[ -n $RUN_DIAG && $EXIT -gt 0 ]] \
		&& cat $TMPFILE

else
	EXIT=4
fi

exit $EXIT

