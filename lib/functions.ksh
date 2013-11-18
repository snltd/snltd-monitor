#=============================================================================
#
# functions.ksh
# -------------
#
# Functions used by the snltd_monitor.sh script and its check_ functions.
#
# R Fisher 02/2009
#
# Record changes below
#
# v1.0  Initial release.

# v1.1  To minimize sourcing of files, this file is now loaded once, by
#       snltd_monitor.sh, and its functions are made available to the check
#       scripts by exporting them. So, when you add a new function, add it
#       to the typeset line at the end of the script. Functions must be
#       defined before being exported. RDF 10/03/09
#
# v1.2  Rolled back the v1.1 change, because Solaris 11 uses ksh93,
#       which doesn't allow you to export functions. So now each check
#       script which needs a method from this file has to load it in.
#       RDF 17/11/13.
#
#=============================================================================

function can_has
{
	# simple wrapper to whence, because I got tired of typing >/dev/null
	# $1 is the file to check

	whence $1 >/dev/null \
		&& return 0 \
		|| return 1
}

function is_global
{
	# Are we running in the global zone? True if we are, false if we're
	# note. True also if we're on Solaris 9 or something else that doesn't
	# know about zones. Now caches the value in the IS_GLOBAL variable

	RET=0

	if [[ -n $IS_GLOBAL ]]
	then
		RET=$IS_GLOBAL
	else
		can_has zonename && [[ $(zonename) != global ]] && RET=1
		IS_GLOBAL=$RET
	fi

	return $RET
}

function is_root
{
	# Are we running as root?

	[[ $(id) == "uid=0(root)"* ]] && RET=0 || RET=1

	return $RET
}


function syslog_severity
{
	# Return the severity of a syslog message as a number
	# $1 is the level as a string

	case $1 in

		"emerg")	RET=8
					;;

		"alert")	RET=7
					;;

		"crit")		RET=6
					;;

		"err")		RET=5
					;;

		"warning")	RET=4
					;;

		"notice")	RET=3
					;;

		"info")		RET=2
					;;

		"debug")	RET=1
					;;

		*)			RET=0

	esac

	print $RET
}

function zone_run
{
    # Run a command in global, or a local, zone
    # $1 is the command -- QUOTE IT IF IT HAS SPACES!
    # $2 is the zone

    # If we've been given a zone name, run the command in that zone. If not,
    # run it here. We have to use pfexec because the monitor runs as a
	# non-root user who has been granted the "Zone Management" profile.

    if [[ $2 == "global" ]]
    then
        eval $1
    else
        pfexec zlogin $2 $1
    fi

}

function get_zone_root_dir
{
	# Get a zone's root directory.
	# $1 is the zone to get the root of

	if [[ $1 == "global" ]]
	then
		print /
	else
		print "$(zonecfg -z $1 info zonepath | cut -d\  -f2)/root"
	fi
}

function is_cron
{
    # Are we being run from cron? True if we are, false if we're not. Value
    # is cached in IS_CRON variable. This works by examining the tty the
    # process is running on. Cron doesn't allocate one, the shells have a
    # pts/n, on Solaris at least

    RET=0

    if [[ -n $IS_CRON ]]
    then
        RET=$IS_CRON
    else
        [[ $(ps -otty= -p$$)  == "?"* ]] || RET=1
        IS_CRON=$RET
    fi

    return $RET

}

function get_apache_zones
{
	# Get a list of zones which probably have Apache running in them
	# Args are a list of candidate zones

	for zone
	do

		[[ -d "$(get_zone_root_dir $zone)/usr/local/apache" ]] \
			&& z_ret="$z_ret $zone "

	done

	print $z_ret
}

function check_file_size
{
	# If a file is over a certain size, print that size. If it's not, don't
	# print anything.

	# $1 is the file
	# $2 is the threshold size, in bytes

	if [[ -f $1 ]]
	then
		s_size=$(ls -le $1 | awk '{ print $5 }')

 		[[ $s_size -gt $2 ]] && print $s_size

	else
		s_ret="MISSING"
	fi

	print $s_ret
}

function log_checker
{
	# This function is a generic log checker. It gets new, relevant lines
	# from a given log file, and writes them to a temporary file. It returns
	# by printing the name of that file. If no new lines are found, it
	# returns a null string.

	# $1 is the log file
	# $2 is the "date match", a regex which matches today's entries in log
	#    file
	# $3 is the "severity match", a regex which matches severity strings in
	#    the log file
	# $4 is an optional filter

	# Depends on global variables:
	#   DIR_STATE
	#   TMPFILE

	typeset var last_block log_file

	log_file=$1
	date_match="$2"
	sev_match="$3"

	if [[ -n "$4" ]]
	then
		filter=$4
	else
		filter="^$"
	fi

	last_block="${DIR_STATE}/last_block.$(print $log_file | tr -d /)"

	# If we have a last_block file that was updated more recently than the
	# log file, we can assume the log file hasn't changed, and our work here
	# is done.

	[[ -f $last_block && $last_block -nt $log_file ]] \
		&& return

	# Either the log file has changed, or we have no memory of examining it.
	# Either way, we want to look at it.

	egrep "$date_match" $log_file | egrep -v "$filter" \
		| egrep "$sev_match" >$TMPFILE

	# We may have no lines in the temp file. That means we've got nothing
	# more to worry about.

	[[ -s $TMPFILE ]] \
		|| return

	# Do we have a last_block? If we don't, then we're pretty much done. We
	# just have to copy the TMPFILE to the last_block location, and tell the
	# main script where it is.

	if [[ -f $last_block ]]
	then
		# Is the last_block the same as the TMPFILE? If it is, we're done

		cmp -s $TMPFILE $last_block \
			&& return

		# We have new, relevant lines. We need to write them to a file, and
		# tell the main script where to find that file

		# We only want the lines in the TMPFILE which aren't in the
		# last_block. We need a new temp file for this.

		TMP2="${TMPFILE}_$RANDOM"

		comm -23 $TMPFILE $last_block >$TMP2

		mv $TMP2 $last_block
	else
		mv $TMPFILE $last_block
	fi

	# If we've made it to here, we should have a non-empty last_block file.
	# Make sure we do, and print its location for the benefit of the main
	# script.

	[[ -s $last_block ]] \
		&& print $last_block

}

function curl_diag
{
	# Feed it a curl exit code, and it will print the error to which that
	# code relates
	# $1 is the code

	$CURL --manual | sed "/EXIT CODES/,/AUTHORS/!d;/^ *$1 /,/^$/!d;/^$/d"
}

function get_epoch_time
{
	# Print the number of seconds since the epoch

	nawk 'BEGIN { print srand(); }'
}
