#!/bin/ksh

#=============================================================================
#
# check_apache_log.sh
# -------------------
#
# Look for stuff in Apache error logs.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v2.0  Rewritten to be a bit smarter.
#
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

DATE_MATCH="^\[$(date "+%a %h %d" )"
	# Error log lines begin like this

SEV_MATCH="[warn\]|\[error\]"

LAST_CHECK="${DIR_STATE}/apache_log_check"

DIR_LOG="var/apache/logs"
	# The base of the apache log directory. We have any number of
	# subdirectories under this.

WARN_SIZE="50000"
	# We warn about log files bigger than this

FILTER_MATCH="File does not exist"
	# Ignore these log file lines. We get thousands.

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

is_global || exit 3

# We used to do a big global find to hunt out log files, but I've decided to
# re-do it by looking at the apache process in each Apache zone. This makes
# for smarter error handling.

# Previously we found error logs older than a marker file. We still use that
# marker file, just in a different way.

[[ -f $LAST_CHECK ]] && EXTRA_FIND="-a -newer $LAST_CHECK"

# For each zone, we look for an apache log directory, then look for all
# "*error*" files in it that are newer than the marker.

for zone in $APACHE_ZONES
do
	ZROOT=$(get_zone_root_dir $zone)
	DIR_Z_LOG="${ZROOT}/$DIR_LOG"

	# If there's no apache log dir, we look to see if there's an Apache
	# process. If there is, that's an error, because the log files are going
	# somewhere non-standard. If there isn't, assume no Apache.

	if [[ ! -d $DIR_Z_LOG ]]
	then

		if pgrep -z $zone -o httpd >/dev/null 2>&1
		then
			ERRORS=1

			[[ -n $RUN_DIAG ]] && \
			cat <<-EOERR
			in zone '$zone':
			  Apache is running, but no standard Apache log directory was
			  found.

			   Expected local zone path: /$DIR_LOG
			  Expected global zone path: $DIR_Z_LOG

			EOERR

		fi

		continue

	fi

	FOUND=1

	# Look for logs with "error" in their name which are less than 24 hours
	# old. We rotate logs every day, and we never want to look at ones from
	# before yesterday.

	find $DIR_Z_LOG -type f -a -mtime -1 -a -name \*error\* $EXTRA_FIND | \
	while read lfile
	do

		# Has the log file changed since last time we ran?

		if [[ ! -f $LAST_CHECK ]] || [[ $lfile -nt $LAST_CHECK ]]
		then

			# Is the log file excessively large?

			LSIZE=$(check_file_size $lfile $WARN_SIZE)
			LZPATH=$(print $lfile | sed "s|$ZROOT||")

			if [[ -n $LSIZE ]]
			then
				WARNINGS=1
				LOOP_ERR=1

				[[ -n $RUN_DIAG ]] \
					&& cat<<-EOOUT
					Oversized log file in zone '$zone':
					       file size: ${LSIZE}b
					  size threshold: ${WARN_SIZE}b
					     global path: $lfile
					      local path: $LZPATH

				EOOUT
			fi

			# Now look at the error logs. Get today's entries. Filter out
			# "File does not exist" lines. There will be hundreds.

			BLOCK=$(log_checker $lfile "$DATE_MATCH" "$SEV_MATCH" \
			"$FILTER_MATCH")

			if [[ -n $BLOCK ]]
			then

				egrep -sv '[warn]' $BLOCK \
					&& ERRORS=1 \
					|| WARNINGS=1

				if [[ -n $RUN_DIAG ]]
				then
					print "in zone '$zone'\nlogfile:$LZPATH"
					cat $BLOCK
					print
				fi

			fi

		fi

	done

done

if [[ -n $ERRORS ]]
then
	EXIT=2
elif [[ -n $WARNINGS ]]
then
	EXIT=1
elif [[ -z $FOUND ]]
then
	EXIT=3
else
	EXIT=10
fi

touch $LAST_CHECK

exit $EXIT
