#!/bin/ksh

#=============================================================================
#
# snltd_monitor_daemon.sh
# -----------------------
#
# This script is run by SMF. It triggers the snltd_monitor.sh at regular
# intervals. It's just a simple wrapper. It does no monitoring or reporting
# itself.
#
# Before running snltd_monitor.sh, this script checks that script is not
# already running. If it is, no action is taken, but the script remembers.
# If three starts in a row fail, then we assume snltd_monitor.sh is hung,
# and kill it.
#
# It's very lightweight. The only external it calls is 'cat', and it
# only does that if you ask for usage information.
#
# The script has a kind of "pseudo-daemon" functionality, whereby if you
# supply the -D flag, the main loop of the script is backgrounded. This is a
# bit of a cheat, bit of a hack, but shell doesn't have fork() and setsid(),
# and my C's not very good.
#
# Flags are:
#   -D : run as a daemon
#   -r : passed through to the monitor script, which informs it to try to
#        repair anything it thinks it can
#	-n : don't flush the monitor's state data. If this isn't given, then the
#        contents of /var/snltd/monitor are removed. The upshot of this is
#        that any errors found on first-run will be reported.
#   -v : be verbose -- explains what's happening. Useful for debugging and
#        testing when you run without -D
#   -V : print version number and exit
#	-h : print usage information and exit
#
# R Fisher 01/2009
#
# Please record changes below.
#
# v1.0  Initial release
#
# v1.1  BIG changes. Removed -T, -O, -S, -M and all notions of default
#       classes. Now has hardcoded "default" classes, with intervals, but
#       those intervals can be overridden, and other classes added, from a
#       configuration file etc/config.hostname. Now has a smarter (i.e.
#       "working") way of keeping LAP to a sensible value. Slicker ticker().
#       RDF 18/02/09
#
# v1.2  Smarter way of flushing state directory. Now tells snltd_monitor.sh
#       to do it, but only on the first invocation. RDF 22/02/09
#
# v1.3  When a machine has just booted, almost all the checks fail (web
#       servers not running, NTP not synced etc. etc.), so now, we don't run
#       snltd_monitor.sh until we've been up for the time defined by them
#       MIN_UPTIME variable, in seconds. RDF 14/09/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

MY_VER="1.3"
	# Version of this script. Please update when modified!

PATH=/usr/bin

# A bit of typesetting

typeset -i TICK LAP i interval BLOCKED RETRIES

MON_SCR="bin/snltd_monitor.sh"
	# Path to the monitor scripts, relative to the DIR_BASE we work out
	# later. That is the top of the snltd_monitor installation

MON_OPTS="-s"
	# Arguments to pass through to the snltd_monitor.sh script

RETRIES=3
	# Amount of consecutive times which we are happy to ignore that $MON_SCR
	# is already running. After this number is hit, we kill the script and
	# run it again.

LOGDEV="local7"
	# Syslog facility to which we write

FLUSH=true
	# Whether or not to tell snltd_monitor.sh to flush the temporary state
	# directory on first run

MIN_UPTIME=300
	# Only run checks when the server has been up for this many seconds. If
	# this variable is not set, checks will always be run. Variable is unset
	# once the MIN_UPTIME has been exceeded.

#- DEFAULT INTERVALS ---------------------------------------------------------
#
#	Intervals in seconds between checks. Can be overriden from config files.
#	This is a bit clunky and nasty. For every class of check scripts (that
#	is, every directory under checks/), you need to define a variable either
#	here or in the machine-specific config file in etc/ of the form
#	INT_class where class is the class, and directory, name. Define
#	"default" classes here. We always want to run hardware and os tests, for
#	instance, but we only have a 3510 attached to cs-fs-01, so INT_3510
#	should only be defined in cs-fs-01's config file

INT_hardware=600
INT_os=300
INT_dashboard=1200
	# Update the dashboard every 20 minutes

TICK=60
	# Time, in seconds, the main ticker() loop sleeps for. After this
	# interval it wakes up and sees if anything should be run. This should
	# be the largest possible common divisor of all the INT_ variables

LAP=0
	# "total" elapsed time. I reset this every time we run all checks
	# simultaneously, because I'm not entirely sure I trust ksh with very
	# high numbers

#-----------------------------------------------------------------------------
# FUNCTIONS

die()
{
	print -u2 "ERROR: $1"
	exit ${2:-1}
}

log()
{
	# Write to syslog if we're running from SMF or cron, to stderr if not

	# $1 is the string to write
	# $2 is the severity

	[[ $(ps -otty= -p$$)  == "?"* ]] &&
		logger -p ${LOGDEV}.${2:-info} "${0##*/}: $1" \
		|| print -u2 "$1"

}

qualify_path()
{
	# Make a path fully qualified, if it isn't already. Can't go in the
	# functions file, because we need it to FIND the functions file!  $1 is
	# the path to qualify

	if [[ $1 != /* ]]
	then
		print $(cd "$(pwd)/$1"; pwd;)
	else
		print $1
	fi

}

ticker()
{
	# This is the main loop of the program. It's in a function so it can be
	# backgrounded in "daemon" mode.

	# Sleep for TICK seconds, look at each test type and see if it needs to
	# be run. (We do this by looking at the remainder from dividing the
	# elapsed time by the test type's interval.). Build up a string of test
	# types to be used as arguments to the snltd_monitor.sh script. If that
	# string is non-zero, run the tests.

	# Note that ALL tests get run when this script is first run. That's a
	# conscious design decision.

	while :
	do

		# Check the machine has been up long enough to make it worth running
		# the checks.

		if [[ -n $MIN_UPTIME ]]
		then
			UPTIME=$(nawk \
				'BEGIN {
					srand();
					print srand() - ARGV[2]
			}' $(kstat -p unix:0:system_misc:boot_time))

			# Used to write to log here, but it was generating too much
			# noise

			[[ $UPTIME -ge $MIN_UPTIME ]] \
				&& unset MIN_UPTIME \
				|| continue

		fi

		unset MON_ARGS

		# If elapsed time is zero, we know to run everything. If it's not,
		# we have to work out what to run

		if [[ $LAP == 0 ]]
		then
			MON_ARGS=${CHECK_CLASS_LIST[@]}
		else
			i=0

			for class in ${CHECK_CLASS_LIST[@]}
			do
				interval=${CHECK_INT_LIST[$i]}
				((i = $i + 1))

				(( ($LAP % $interval) == 0 )) && MON_ARGS="$MON_ARGS $class"
			done

			# If we're running everything, reset LAP to zero and jump back
			# to the start of the loop. This might seem stupid, and it might
			# well be, but it keeps LAP down to a fairly low number, and I
			# have reservations about ksh and very high ones.

			if [[ " ${CHECK_CLASS_LIST[@]}" == $MON_ARGS ]]
			then
				LAP=0
				continue
			fi

		fi

        #- here's where we run the monitor script ----------------------------

		if [[ -n $MON_ARGS ]]
		then
			# Do we want tell the monitor to flush the state directory

			if [[ -n $FLUSH ]]
			then
				MON_F_OPTS="-f"
				unset FLUSH
			else
				unset MON_F_OPTS
			fi


			# Is the monitor script already running? If it is, we don't want
			# to run it again.

			if is_running "/bin/ksh $MON_SCR"
			then

				# If the monitor's running, we'll ignore it $RETRIES times,
				# and just not trigger it again. After that, we assume a
				# problem and try to kill it.

				if [[ $BLOCKED -lt $RETRIES ]]
				then
					((BLOCKED += 1))
					log "$MON_SCR already running. Blocked count is $BLOCKED"
				else
					# We'll try to kill the monitor nicely. If it doesn't
					# die, we'll -9 it.

					log "killing $MON_SCR [-15]"
					pkill -z global $MON_SCR notice
					sleep 1

					if is_running "/bin/ksh $MON_SCR"
					then
						log "killing $MON_SCR [-9]"
						pkill -9 -z global $MON_SCR notice
						sleep 1

						# If the process is still running at this point,
						# exit.

						if is_running "/bin/ksh $MON_SCR"
						then
							log "unable to kill $MON_SCR" err
							exit 3
						fi

					fi

				fi

			else
				$MON_SCR $MON_OPTS $MON_F_OPTS $MON_ARGS

				[[ -n $VERBOSE ]] && print \
					"running $MON_SCR $MON_OPTS $MON_F_OPTS $MON_ARGS at $LAP"
			fi

		fi

        #---------------------------------------------------------------------

		sleep $TICK
		((LAP += $TICK))

	done
}

usage()
{
	cat<<-EOUSAGE

	usage:
	  ${0##*/} [-Drn]

	  ${0##*/} -V

	where:
	   -D, --daemon         run as a daemon
	   -n, --noflush        don't flush the monitor's state data
	   -r, --repair         tell monitor script to try to repair faults
	   -v, --verbose        be verbose
	   -V, --version        print the version and exit

	EOUSAGE

	exit 2
}

is_running()
{
	# Function to see if a given string is in the process table, in the
	# current zone

	pgrep -z $(zonename) "$1" >/dev/null
}

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# Fully qualify our path to find out were we are in the filesystem

DIR_BASE=$(qualify_path "${0%/*}/..")

# Get the full path to the monitor script and the check script directory

MON_SCR="${DIR_BASE}/$MON_SCR"
DIR_CHK="${DIR_BASE}/checks"
DIR_CONF="${DIR_BASE}/etc"

# Do we have the monitor script and the check dir?

[[ -f $MON_SCR ]] || die "can't find monitor script. [${MON_SCR}]"

[[ -x $MON_SCR ]] || die "can't run monitor script. [${MON_SCR}]"

[[ -d $DIR_CHK ]] || die "can't find check script directory. [${DIR_CHK}]"

# Get our command line options

while getopts \
"D(daemon)r(repair)n(noflush)V(version)v(verbose)h(help)" 2>/dev/null \
option
do

    case $option in

		D)	DAEMON=true
			;;

		n)	unset FLUSH
			;;

		r)	MON_OPTS="$MON_OPTS -r"
			;;

		v)	VERBOSE=true
			;;

		V)	print $MY_VER
			exit 0
			;;

		*)	usage

	esac

done

# Then throw them away

shift $(($OPTIND -1))

# Read the machine-specific config file, if there is one

CF_FILE="${DIR_CONF}/config.$(uname -n)"

if [[ -f $CF_FILE ]]
then
	. $CF_FILE

	[[ -n $VERBOSE ]] && print "Reading config from $CF_FILE"
fi

# Get a list of all the available classes,then see which of those classes we
# have intervals for, and build up a list of the classes we are going to be
# running

i=0

ls $DIR_CHK | while read class
do
	int="INT_$class"
	eval VALID_INT=$"$int"

	# ksh88 doesn't have associative arrays, so we'll build up two arrays,
	# one of the class name and one of the interval that class is run at

	if [[ -n $VALID_INT ]]
	then
		# First, make sure the interval is a multiple of $TICK

		[[ $(($VALID_INT % $TICK)) == 0 ]] \
			|| die "clock tick [${TICK}] is not a factor of ${VALID_INT}."

		CHECK_CLASS_LIST[$i]=$class
		CHECK_INT_LIST[$i]=$VALID_INT
		((i = $i + 1))

		# If we've been asked to be verbose, say what we're going to do.
		# This is primarily for my benefit while I'm testing it.

		[[ -n $VERBOSE ]] \
			&& print "$class checks run every $VALID_INT second(s)"

	else
		[[ -n $VERBOSE ]] \
			&& print "  [$class checks are not run]"
	fi

done

# Make sure there is at least one class to run

[[ ${#CHECK_CLASS_LIST[@]} -gt 0 ]] \
	|| die "no tests to run."

# Now we can run the main loop. If we were given the -D flag, we background
# the function

if [[ -n $DAEMON ]]
then
	ticker &
else
	ticker
fi

# If we've made it this far, exit with success

exit 0

# That's it.
