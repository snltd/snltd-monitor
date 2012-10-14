#=============================================================================
#
# check_cron_jobs.sh
# ------------------
#
# Look to see if any cron jobs have failed. Zone-aware.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Fairly substantial change. Now remembers the last line it looked at,
#      and examines the whole log from that point.
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

LOGFILE="var/cron/log"
EXIT=10
	# Default exit, assuming no errors, is 10. That means the monitor won't
	# send an "all clear" if a fault disappears.

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

for zone in global #$ZONE_LIST
do
	F_PATH="$(get_zone_root_dir $zone)/$LOGFILE"

	if [[ -r $F_PATH && -s $F_PATH ]]
	then
		LAST_LINE_FILE="${DIR_STATE}/cron_log_last.$zone"
		LAST_BLOCK="${DIR_STATE}/cron_log.$zone"

		# If the log hasn't changed since the last time we ran, move on

		[[ -f $LAST_BLOCK ]] && [[ $LAST_BLOCK -nt $F_PATH ]] \
			&& continue

		# We're only interested in the part of the log file since the last
		# time we looked. Previously we looked at lines from "today", but
		# that could mean us missing something that failed just before
		# midnight. Every time we look at the log file, we record the last
		# "exit" line. That is, the last line beginning with a <. This has
		# the time and date in, along with a PID, so is sufficiently close
		# to being unique.

		# If we have a recorded last line, tell sed to print the lines from
		# that line to the end of the log file. If we don't, get all the log
		# file from TODAY. I know we could theroetically miss something just
		# before midnight, but it's unlikely, and I couldn't think of a more
		# convenient way to do this. It's either every error in the log, or
		# some arbitrary cut-off point.

		if [[ -f $LAST_LINE_FILE ]]
		then
			SED_PTN="/^$(cat $LAST_LINE_FILE)/"
		else
			L1=$(sed -n "/ $(date "+%b %e") .*$(date "+%Y")$/{=;q;}" $F_PATH)

			# Get the number of the line with the first occurrence of
			# today's date. We're going to tell sed to get the line BEFORE
			# that.

			if [[ -n $L1 ]]
			then
				SED_PTN="$(($L1 - 2))"
			else
				continue
			fi

		fi

		# Run sed

		sed "1,${SED_PTN}d" $F_PATH >$TMPFILE

		# And record the last "<" line in the original log. We don't want to
		# look at the whole file, but it seems a safe bet that there will be
		# a suitable match in the last 20 lines

		tail -20 $F_PATH | egrep "^<" | tail -1 >$LAST_LINE_FILE

		# Move on to the next zone if we don't have any lines

		[[ -s $TMPFILE ]] \
			|| continue

		# Get anything in TMPFILE that isn't in LAST_BLOCK, assuming that
		# exists
		
		if [[ -f $LAST_BLOCK ]]
		then
			TFILE2="${TMPFILE}$$"
			comm -23 $TMPFILE $LAST_BLOCK >$TFILE2
			mv $TFILE2 $TMPFILE
		fi

		# Move on to the next zone if we don't have any lines

		[[ -s $TMPFILE ]] \
			|| continue

		# Jobs which don't exit 0 are recorded with rc=ret_code tagged on
		# the end of their closing log line. Failed jobs can also have "exec
		# failed" on an additional, fourth, log line. On any error, set the
		# exit value to 1

		if egrep -s "rc=[0-9]*$|^exec" $TMPFILE 
		then
			LOOP_ERR=1
			ERRORS=1
			cp $TMPFILE $LAST_BLOCK
		fi

		# Diagnostic block, if we need it

		if [[ -n $RUN_DIAG ]] && [[ $LOOP_ERR -gt 0 ]]
		then

			# It's quite tricky to pull chunks out of the cron log. The
			# format is as follows:
			
			# CMD: command
			# >  the time (+some other info) the job began
			# <  the time (+some other info) the job ended. Ends rc=x if x > 0
			# Possibly an exec failed line
			
			# I tried loads of clever sedding, thought I had a good
			# solution, but then found out that the output from jobs can be
			# interleaved, so you can't just pull consecutive lines out.
			
			# You have to go on the PID. So, let's get a list of failed
			# PIDs, then pull out chunks relating to them. Also get part of
			# the date string, because PIDs get recycled. Using fields 3-6
			# isn't 100% foolproof, but it should suffice. (It will fail if
			# a job ticks over a day boundary, or if the same PID got used
			# on the same day. Of course, this only applies to failed jobs.)

			print \
			"in zone '$zone' the following cron jobs exited non-zero:"

			egrep "^< .*rc=[0-9]*$" $TMPFILE | \
			while read line
			do
				MATCH=$(print $line | tr -s " " | cut -d\  -f3-6)

				# This sed prints the line which shows the cron job with the
				# above PID beginning,  and also the line before it, which
				# shows the command that was run.

				sed -n -e "/^> .* $MATCH /{x;1!p;g;p;D;}" -e h $TMPFILE
				print "$line\n"
			done
			
			# We may have the dreaded "exec failed" lines too. Do a similar
			# trick for those. First get all the "exec failed" lines, and
			# the preceeding line for each

			sed -n -e "/^exec/{x;1!p;g;p;D;}" -e h $TMPFILE | \
			while read line
			do
				# If this is an "exec failed" line, we only print it if the
				# other stuff has already been printed

				if [[ "$line" == "exec"* ]]
				then
					print "$line\n"
				else
					MATCH=$(print $line | tr -s " " | cut -d\  -f3-6)
					sed -n -e "/^> .* $MATCH /{x;1!p;g;p;D;}" -e h $TMPFILE
					print "$line"
				fi

			done
			#print

			unset LOOP_ERR
		fi

	else
		# Exit with a hard error if there's no cron log

		[[ -n $RUN_DIAG ]] \
			&& print "no (readable) cron log file [${F_PATH}]"

		ERRORS=1
	fi

done

[[ -n $ERRORS ]] \
	&& EXIT=2

exit $EXIT

