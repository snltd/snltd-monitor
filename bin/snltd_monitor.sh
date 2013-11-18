#!/bin/ksh

#=============================================================================
#
# snltd_monitor.sh
# ----------------
#
# Bespoke monitoring software for zoned Solaris environments.
#
# This script doesn't do any checks itself, but calls other "helper" scripts
# which do the work and report back.
#
#-----------------------------------------------------------------------------
#
# PHILIOSOPHY AND BASIC GUIDELINES
#
# This script runs "classes" of checks. Each class has its own directory, and
# hold scripts called "check_something".sh. The check scripts each perform a
# single small test, and exit with a particular value. If a variable
# RUN_DIAG is set, then they also write diagnostic information to standard
# out. This script captures that output to a file, then looks at the
# script's exit code:
#
#    0  : no problems found
#    1  : warning - non-fatal errors found
#    2  : error - potentially fatal problem found
#    3  : not applicable - perhaps "service" is not installed on this server?
#    4  : no information - for some reason, the check failed to produce a
#         definite result
#    10 : no problems found, but don't send an all-clear message
#   254 : Script tried, and failed, to find library file
#
# If this script is running verbosely, and the check script exited non-zero,
# this script will display the captured information. If the MAILTO variable
# is set, then this script will attempt to email said information to the
# addresses held in MAILTO. It can also mail out on a zero return code, if
# the previous invocation of the same check script returned one or two.
#
# Some failure conditions are worth trying to fix. Automate your repair
# procedure and put it in a repair_ script. This will be run if
# snltd_monitor is in "repair" mode, and once it completes, after a little
# pause for things to catch up, the check_ script will be run again.
#
#-----------------------------------------------------------------------------
#
# R Fisher 12/2008
#
# Please record changes below.
#
# v1.0  Initial Release. RDF 12/02/09
#
# v1.1  Changed from single to multiple cache directories. Tidied up
#       variable names. Handles new check script exit code 10. Changed
#       formatting of mail subject line. RDF 18/02/09
#
# v1.2  Fixed flushing of new directory structure. RDF 23/02/09
#
# v1.3  Has the ability to no run certain checks, if the OMIT_SCRIPTS
#       variable is set in the machine config file. Slightly streamlined.
#       RDF 25/02/09
#
# v1.4  Is now able to handle repeated failures of a check script, when
#       those failures are for different reasons. For instance,
#       check_svcs.sh finds that fmd has stopped. Then, when it runs again,
#       it finds inetd has also stopped. BOTH failures must be reported.
#       Previously, they weren't. This forces quite a lot of changes. See
#       comments for details. RDF 26/02/09
#
# v1.5  Now sends HTML email via mail(1) rather than plain text through
#       mailx(1). This makes a lot more sense when you're sending output of
#       stuff like prstat and vmstat. Changed format of mailouts. RDF
#       4/03/09
#
# v1.6  Exits 100 +  the number of failed checks if failed checks > 0.
#       Logs failed checks.
#
# v1.7  First RBAC awareness. RDF 24/03/09
#
# v1.8  Uses lock file to prevent multiple runs. Has ability to issue its
#       own warnings, using same mechanism it uses to send warnings from
#       check scripts. Times out prtdiag if it takes too long. RDF 16/06/09
#
# v1.9  Removed the PICL stuff, because nothing uses it. Now smartly handles
#       prtdiag exiting non-zero, which it does when it finds a fault. RDF
#       21/07/09
#
# v1.10 Changed timeout_job() function to explicitly kill all an errant
#       process's children. Added "consecutive fail" count, so that errors
#       are only reported after a certain number of identical faults. This
#       is managed by the REP_ variables in the config files. Report on
#       deliberately omitted scripts in verbose mode, bit of source tidying
#       to fit Sun's shell scripting guidelines. RDF 01/12/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

MY_VER=1.10
	# Version of script. Please remember to update this!

# As we execute a lot of sub-scripts, we need to export certain variables.
# RUNPRT is for formatting when we run verbosely

typeset -x LIBRARY TMPFILE PATH DIR_PERM DIR_STATE RUN_DIAG ZONE_LIST \
	CONFIG_FILE DIR_CONFIG RUN_WRAP DIR_BIN DIR_EXIT DIR_DIAG HOSTNAME
typeset -R25 RUNPRT
typeset -i ERRORS WARNINGS

PATH=/usr/bin:/usr/sbin
	# Always set your PATH

TMPFILE=/tmp/${0##*/}.$$
	# This whole thing is designed to be as fast and lightweight as
	# possible. As such, we sometimes have to make use of temporary files.
	# This TMPFILE can be used by any child script

GLOBAL_EXIT=0
	# Used to keep a running total of the failed checks. We exit with this
	# number

VARBASE="/var/snltd/monitor"
	# The directory we keep our data in

DIR_TEMP="${VARBASE}/temp"
	# This directory holds state information, exit codes etc. and can be
	# flushed.  This *MUST* be the same as the DIR_TEMP variable in the
	# snltd_monitor_daemon.sh script

DIR_STATE="${DIR_TEMP}/state"
	# The check scripts can keep state information here, and use it for
	# whatever they like.

DIR_DIAG="${DIR_TEMP}/diag"
	# standard out from check scripts goes here

DIR_LAST_ERR_DIAG="${DIR_DIAG}/last_error"
	# We store diagnostic error info here. These files are compared to new
	# errors, which is how we decide whether or not to mail out those new
	# errors

DIR_FAIL_CNT="${DIR_DIAG}/fail_count"
	# Here we store the number of consecutive times a check has failed

DIR_EXIT="${DIR_TEMP}/exit"
	# Exit codes of check scripts are stored here

DIR_PERM="${VARBASE}/perm"
	# Like DIR_STATE, but this never gets flushed

DIR_LOG="${VARBASE}/logs"
	# Log directory

DIR_QUIET="${DIR_DIAG}/quiet"
	# Quiet files

ERRLOG=${DIR_LOG}/check_fails-$(date "+%Y-%m-%d").log
	# Here, we log checks with exit non-zero

LAST_RUN="${DIR_LOG}/last_run"
	# This stores the timestamp of the last successful run

LOCKFILE="${VARBASE}/snltd_monitor.lock"
	# Lock file, to stop multiple instances

uname -nip | read HOSTNAME ISA_TYPE ARCH
	# Saves us running multiple times. uname doesn't print things in the
	# order you specify the options

MAILTO="slackboy@gmail.com"
#MAILTO="sysadmin@ngfl.gov.uk"
	# Mailto list. Space separated

RUN_TIME_THRESHOLD=180
	# The time, in seconds, in which we expect all tests to complete. If
	# this time is exceeded, an error is sent

T_MAX=150
	# Maximum time in which timeout_job() managed functions must complete.

VERBOSE=true
	# This is now the default mode when run from a terminal

ERRORS=0
WARNINGS=0
	# Counters

#-----------------------------------------------------------------------------
# FUNCTIONS

list_checks()
{
	# Get a list of all the things we can currently check and repair

	typeset -L30 chk

	print "\nAvailable checks and repairs: "

	find $DIR_CHECK/* -type d -prune 2>/dev/null | while read class
	do
		cat<<-EOHEAD

		${class##*/}
--------------------------------------------------------------------------------
		EOHEAD

		find $class -type f -a -name check_\*.sh | sort -u | \
		while read check
		do
			fname=${check##*/}
			tdir=${check%/*}

			if [[ $tdir == $class ]]
			then
				chk=$fname
			else
				ddir=${tdir##*/}
				chk="$fname (${ddir##*-})"
			fi

			print -n "  $chk"

			[[ -f ${DIR_REPAIR}/${class#$DIR_CHECK}/repair_${fname#*_} ]] \
				&& print -n "+ repair_${fname#*_}"

			print
		done

	done

	print
}

log()
{
    # Shorthand wrapper to logger, so we are guaranteed a consistent message
    # format. We write through syslog if we're running through cron, through
    # stderr if not

    # $1 is the message
    # $2 is the syslog level. If not supplied, defaults to info

    typeset -u PREFIX

    PREFIX=${2:-info}

    is_cron \
        && logger -p ${LOGDEV}.${2:-info} "${0##*/}: $1" \
        || print -u2 "${PREFIX}: $1"
}

log_and_send_err()
{
	# Log an error message, and also send it via email. This is used for
	# serious errors within this main script.

	# $1 is the syslog severity
	# $2 is the message to log/email
	# $3 is an optional exit code

	typeset EX=${3:-unknown}

	mail_report "MAIN SCRIPT $1" ${0##*/} $EX "$2"
	log "$2" $EX
}

die()
{
	# Print an error message and exit

	print -u2 "ERROR: $1"

	is_cron \
		&& log_and_send_err "FATAL ERROR" ${0##*/} ${2:-unknown}

	clean_up
	exit ${2:-1}
}

qualify_path()
{
	# Make a path fully qualified, if it isn't already. Can't go in the
	# functions file, because we need it to FIND the functions file!
	# $1 is the path to qualify

	if [[ $1 != /* ]]
	then
		print $(cd "$(pwd)/$1"; pwd;)
	else
		print $1
	fi

}

handle_return()
{
	# This function's job is to decide whether or not we send an e-mail,
	# and, if we are going to, what kind of e-mail it will be.
	# mail_report() does the business of e-mailing.

	# $1 is the test we just ran
	# $2 is its return code
	# $3 is the file holding the diagnostic output
	# $4 is the last exit file

	# We want to send an mail if:
	#   EITHER the exit code is different from the last exit code
	#   OR the exit code is the same as the last exit code, but the
	#      diagnostic information is different.
	#   AND there is no REP_ value, or the REP_ value has been equalled

	# We're only interested in exit codes 0, 1, and 2. Nothing else ever
	# triggers a warning. This function should never be called with any other
	# value, but, if it has been, exit

	(( $2 > 2 )) && return

	# Make things more legible, and keep variables local

	typeset chk_scr this_exit this_diag last_exit_file last_diag \
		rep_varname rep_trigger mail_extra \
		fail_c_file fail_c_count be_quiet force_notify quiet_file

	chk_scr=$1		# Not the full name of the check script. Just the part
					# between the check_ and the .sh
	this_exit=$2
	this_diag=$3
	last_exit_file=$4

	[[ -n $DIAG ]] && print_diag=true

	# If we don't have a recorded status, let's assume success. That way
	# we'll be sure to send a message if there was an error this time.

	[[ -f $last_exit_file ]] \
		&& last_exit=$(<$last_exit_file) \
		|| last_exit=0

	# Here follows code related to the fail count. This lets us only report
	# if there have been 'n' consecutive fails.  First, see if there's a
	# repeat value for this check and, if there is, store it in rep_trigger

    rep_varname="REP_${chk_scr%.*}"
    eval rep_trigger=$"$rep_varname"
	last_diag="${DIR_LAST_ERR_DIAG}/${this_diag##*/}"
	quiet_file=${DIR_QUIET}/$chk_scr

	if [[ -n $rep_trigger ]] && (( $this_exit > 0 ))
	then
		# fail_c_file is the fail count file for this script. It holds the
		# value we compare against rep_trigger. Work out where it is, and
		# get the value from it. If it's not there, assume a value of zero

		fail_c_file="${DIR_FAIL_CNT}/${chk_scr%.*}"

		[[ -f $fail_c_file ]] \
			&& fail_c_count=$(<$fail_c_file) \
			|| fail_c_count=0

		# If the value of rep_trigger is equalled, we want to send a mail,
		# consecutive fails don't normally trigger a mailout, so we set the
		# force_notify variable, and reset the count by removing the fail
		# count file. If not, increment the count, and set the be_quiet
		# variable, which will be important later.

		if (( $fail_c_count == $rep_trigger ))
		then
			force_notify=1
			mail_extra="Test failed on $rep_trigger consecutive occasions.
			"
			[[ -f $fail_c_file ]] && rm $fail_c_file
		else
			print $((fail_c_count + 1)) >$fail_c_file
			be_quiet=1
		fi

	fi

	# Now we can do some work. We look at the exit code of the check, and
	# act accordingly. First up, exit code zero, which means the test was
	# passed.

	if (( $this_exit == 0 ))
	then

		# We only send a message if the last exit code was >0. i.e. if a
		# fault has been cleared, and then only if there's no quiet_file for
		# this script

		if (( $last_exit == 0 ))
		then
			[[ -n $VERBOSE ]] && print "ok"
		else
			[[ -n $VERBOSE ]] && print "ok [cleared]"

			[[ ! -f $quiet_file ]] \
				&& mail_report "all clear" $chk_scr $this_exit

			# Clear the consecutive fail count, if we care about it

			[[ -n $REP ]] && rm -f $fail_c_file
		fi

		unset print_diag

	#- Exit code 1. This is a WARNING --------------------------------------

	elif (( $this_exit == 1 ))
	then

		# We send a message if the last exit code was not 1, or if it was 1
		# but the diagnostic output has changed.

		if [[ $last_exit != 1 || ! -f $last_diag || -n $force_notify ]] \
			|| ! cmp -s $last_diag $this_diag
		then
			[[ -n $VERBOSE ]] && print "WARNING"
			mail_err="WARNING"
		else
			[[ -n $VERBOSE ]] && print "WARNING [known problem]"
		fi

	#- Exit code 2. This is an ERROR ---------------------------------------

	else

		if [[ $last_exit != 2 || ! -f $last_diag || -n $force_notify ]] \
			|| ! cmp -s $last_diag $this_diag
		then
			[[ -n $VERBOSE ]] && print "ERROR"
			mail_err="ERROR"
		else
			[[ -n $VERBOSE ]] && print "ERROR [known problem]"
		fi

	fi

	# Print diagnostic info, if need-be

	[[ -n $print_diag ]] \
		&& print_diag_info $this_diag "check_$chk_scr" $this_exit

	# Send mail, if need be, and store the diag info. The be_quiet variable
	# can suppress the mailing. If mailing is suppressed, write a file in
	# the DIR_QUIET directory.

	if [[ -n $mail_err ]]
	then

		if [[ -z $be_quiet ]]
		then
			mail_report $mail_err $chk_scr $this_exit $this_diag \
			"$mail_extra"
			[[ -f $quiet_file ]] && rm $quiet_file
		else
			>$quiet_file
		fi

		cp $this_diag $last_diag
		unset mail_err
	fi

	# Write the status to the file for next time

	print $this_exit >$last_exit_file
}

mail_report()
{
	# This function mails out a fault report or all-clear. It only does this
	# if the MAILTO variable is set.

	# $1 is the status to send
	# $2 is the script we're reporting on
	# $3 is the exit code from the script
	# $4 is the file with the diagnostic information for errors from check
	#    scripts. For errors from this script, $4 is a text string.
	# $5 is an additional string

	# For clarity:

	typeset var status chk_scr exit_code diag_file subj

	status=$1
	chk_scr=$2
	exit_code=$3
	diag_file=$4
	mail_extra=$5

	if [[ -n $MAILTO ]]
	then

		subj="MONITOR : $HOSTNAME : $status from chk_$chk_scr"

		# Special case for errors from this script

		if [[ $chk_scr == ${0##*/} ]]
		then
			mail $MAILTO <<-EOMAIL
			Subject: MONITOR: $HOSTNAME : ERROR from ${0##*/}
			MIME-Version: 1.0
			Content-Type: text/html
			Content-Disposition: inline
			<html>
			<body>
			<pre>
			       host: $HOSTNAME
			     script: $chk_scr
			  exit code: $exit_code
			       time: $(date).

			Main script exited $exit_code with error:

			  $diag_file
			</pre>
			</body>
			</html>
			EOMAIL

		# All clears

		elif [[ $exit_code == 0 ]]
		then
			mail $MAILTO <<-EOMAIL
			Subject: $subj
			MIME-Version: 1.0
			Content-Type: text/html
			Content-Disposition: inline
			<html>
			<body>
			<pre>
			       host: $HOSTNAME
			     script: check_$chk_scr
			  exit code: 0 [All clear]
			       time: $(date).

			</pre>
			</body>
			</html>
			EOMAIL

		# All other errors

		else
			mail $MAILTO <<-EOMAIL
			Subject: $subj
			MIME-Version: 1.0
			Content-Type: text/html
			Content-Disposition: inline
			<html>
			<body>
			<pre>
			       host: $HOSTNAME
			     script: check_$chk_scr
			  exit code: $exit_code
			       time: $(date).

			$mail_extra
			Diagnostic information follows
			[${diag_file}]

			$(print_diag_info $diag_file $chk_scr $exit_code MAIL)

			</pre>
			</body>
			</html>
			EOMAIL
		fi

	fi
}

print_diag_info()
{
	# This function displays diagnostic info. This is used both in e-mails
	# and as the script's verbose output.

	# $1 is the file holding the output of the diag script
	# $2 is the filename of the check script
	# $3 is the exit code of the check script
	# $4 is an optional parameter. If it is included, then the output is
	#    modified to be embedded in an email

	typeset -R$SCR_W prt="x"

	line_thin=$(print "$prt" | sed 's/./-/g')
	line_thick=$(print "$prt" | sed 's/./=/g')

	print -- "\n$line_thick"

	if [[ -z $4 ]]
	then
		tput bold 2>/dev/null
		print "${2##*/} exited $3"
		tput sgr0 2>/dev/null
		print "diagnostic info from $1 follows"
		print -- "${line_thin}\n"
	else
		print
	fi

	[[ -s $1 ]] \
		&& cat $1 \
		|| print "  ** no diagnostic information found **"

	if [[ -z $4 ]]
	then
		print -- "\n$line_thin"
		date
	fi

	print -- "\n${line_thick}\n"
}

clean_up()
{
	# Clear up some temp files and log the end time

	rm -f $TMPFILE $DIAG_CACHE $LOCKFILE
}


timeout_job()
{
    # Run a job for a maximum specific length of time. If the job does not
    # complete in $T_MAX seconds, it is terminated

    # $1 is the job to run -- quote it!
    # $2 is an optional timeout, in seconds

    $1 2>/dev/null &

    typeset BGPID=$!
    typeset count=${2:-$T_MAX}
	typeset RET_CODE

    while (( $count > 0 ))
    do
        # If there are no backgrounded jobs, exit

        if [[ -z $(jobs -p) ]]
		then
			wait $BGPID
			RET_CODE=$?
			break
		fi

        count=$(($count - 1))
        sleep 1
    done

    if [[ -n $(jobs) ]]
    then
        kill $(ptree $BGPID | sed -n "/$BGPID/,\$s/^ *\([0-9]*\).*$/\1/p")
        print "TIMED OUT"
        RET_CODE=255
    fi

	return $RET_CODE
}

monitor_usage()
{
	# Pretty self explanatory I think. Print usage information and exit

	cat <<-EOUSAGE

	usage:
	  ${0##*/} [-m address] [-fvsrd] type ... type

	  ${0##*/} -l

	  ${0##*/} -V

	where:
	   -v, --verbose         run in verbose mode, listing each test and its
	                         result. (This is the default.)
	   -s, --slient          run in silent mode. The exit code is the number
	                         of failed checks
	   -d, --diag            report diagnostic information for each failed
	                         test
	   -f, --flush           flush the state directory, so all errors are
	                         reported
	   -r, --repair          if a test fails and a corresponding repair
	                         script exists, run that script, then re-test
	   -m, --mail            send warnings by email to given addresses.
	                         Comma separated list. By default, mail is not
	                         sent when the script is run interactively
	   -l, --list            list the available checks, diagnoses and
	                         repairs, then exit
	   -V, --version         print version and exit

	For a list of available types, run "${0##*/} -l"

	EOUSAGE
	clean_up
	exit 2
}

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# Clean up if we're "ctrl-c"ed

trap 'clean_up; exit' 2 9 15

BASE=$(qualify_path "${0%/*}/..")
	# The root of the monitor installation

# We have a library of common functions which is available to this script
# and to all the check_ and diag_ scripts which it spawns.

export LIBRARY="${BASE}/lib/functions.ksh"

[[ -f $LIBRARY ]] || die "ERROR:can't find library [$LIBRARY]" 1

. $LIBRARY

START_TIME=$(get_epoch_time)

# We have our functions. Now, where do we expect to find our scripts?

DIR_CHECK="${BASE}/checks"
	# Where to find check scripts

DIR_REPAIR="${BASE}/repairs"
	# Where to find repair scripts

DIR_CONFIG="${BASE}/etc"
	# Where to find config files

RUN_WRAP="pfexec ${BASE}/bin/mon_exec_wrapper.sh"

[[ $RUN_WRAP == *"/home/"* ]] \
	&& RUN_WRAP="pfexec /usr/local/snltd_monitor/bin/mon_exec_wrapper.sh"
	# Full path to the mon_exec_wrapper.sh script, used to run certain root
	# commands. Prefixed with pfexec, because it can only be run through the
	# "snltd Monitor" profile.

DIR_BIN=${BASE}/bin/$ISA_TYPE
	# Where to find support binaries (dig, mysql client etc.). Add this to
	# the PATH

PATH=${PATH}:$DIR_BIN

# Load a global config file, if we have one

GLOBAL_CONFIG_FILE="${DIR_CONFIG}/config.global"

[[ -f $GLOBAL_CONFIG_FILE  ]] && . $GLOBAL_CONFIG_FILE

# Work out where the config file for this server might be, and, if we have
# one, load it

CONFIG_FILE="${DIR_CONFIG}/config.$HOSTNAME"
	# machine-specific config file

[[ -f $CONFIG_FILE ]] && . $CONFIG_FILE

# Make sure we have check scripts

[[ -d $DIR_CHECK ]] \
	|| die "no check script directory [$DIR_CHECK]" 2

# What options have been supplied?

while getopts \
"d(diag)f(flush)l(list)m:(mail)r(repair)s(silent)v(verbose)V(version)" \
option
do
	case $option in

		d)	DIAG=true
			;;

		f)	FLUSH=true
			;;

		l)	list_checks $*
			exit 0
			;;

		m)	MAILTO=$OPTARG
			;;

		r)	REPAIR=true
			;;

		s)	unset VERBOSE
			;;

		v)	VERBOSE=true
			;;

		V)	print $MY_VER
			exit 1
			;;

		*)	monitor_usage
			clean_up
			exit 2

	esac

done

shift $(($OPTIND -1 ))

# Shut up if we're running from cron or SMF. (i.e. if we don't have a proper
# terminal.) While we're at it, disable e-mailing if we think we're being
# run interactively. (The user can turn it back on with -m.)

if is_cron
then
	exec >/dev/null
	exec 2>&-
	SCR_W=80
		# assume 80 character "screen" width, for formatting
else
	unset MAILTO
	SCR_W=$(tput cols 2>/dev/null)
		# The width of the terminal, for formatting purposes.
fi

# Is the script already running? This stops instances piling up if there's a
# problem which prevents normal termination

if [[ -f $LOCKFILE ]]
then
	OLDPID=$(<$LOCKFILE)

	print -u2 "ERROR: Lock file exists at ${LOCKFILE}. [PID ${OLDPID}.]"

	is_cron && \
		log_and_send_err "err" "Monitor already running as PID ${OLDPID}." 5

	exit 5
else
	print $$ >$LOCKFILE
fi

# Do we need to flush the state directory?

[[ -n $FLUSH && -n $DIR_TEMP ]] && rm -fr $DIR_TEMP/*

# Do we have the state and permanent directories?

for dir in $DIR_STATE $DIR_DIAG $DIR_EXIT $DIR_PERM $DIR_LAST_ERR_DIAG \
	$DIR_LOG $DIR_FAIL_CNT $DIR_QUIET
do

	[[ -d $dir ]] \
		|| mkdir -p $dir 2>/dev/null

	[[ -w $dir ]] \
		|| die "can't write to directory. [$dir]" 3

done

# Do we have an argument?

[[ $# == 0 ]] && monitor_usage

# If we've been told to run "all" checks, expand that keyword. All could
# possibly be mixed in with other class names. People do things like that.
# "All" also tells the script to ignore the "OMIT_SCRIPTS" variable in the
# config file. It does this by setting the NOSKIP variable

CLASSES=$@

for arg
do

	if [[ $arg == "all" ]]
	then
		CLASSES="$(find $DIR_CHECK/* -type d -prune | sed 's/^.*\///')"
		NOSKIP=true
		break
	fi

done

# Can we mail out? If we can't, unset the MAILTO variable. The script will
# still work, but it won't be able to send mail

if [[ -n $MAILTO ]]
then

	if can_has mail && [[ -f /usr/lib/sendmail ]]
	then
		:
	else
		print "WARNING: can't send mail."
		unset MAILTO
	fi

fi

# If we're running verbosely, or mailing out, we need to export the RUN_DIAG
# variable. The check scripts will write diagnostic information if they see
# that.

RUN_DIAG=true

# Get a list of RUNNING zones. If this box doesn't have zones, pretend it
# does

if can_has zonename
then
	ZONE_LIST=$(zoneadm list)
else
	ZONE_LIST="global"
fi

# This is the main loop where we do the work. There might be some obscure
# and seemingly long-winded substitions and parameter expansions, but I'm
# going to try to do as much as possible internally. As I said before, it's
# all about speed.

for class in $CLASSES
do

	if [[ ! -d ${DIR_CHECK}/$class ]]
	then
		print "WARNING: class '$class' does not exist"
		continue
	fi

	# Special cases for different classes.

	if [[ $class == "hardware" ]] && is_global
	then

		# Hardware checks need information from prtdiag. This can take a
		# while to get on the T2000s, so we'll get it once, here, and have
		# the child scripts use the cached information. We can only get this
		# information if we're in a global zone

		typeset -x DIAG_CACHE ARCH
		DIAG_CACHE="/tmp/diag_cache"

        # I've found that prtdiag can hang forever on T2000s. We give it a
        # minute to complete. If it doesn't we error and continue. Note that
        # prtdiag will exit non-zero if it finds a fault. I don't want to
        # start writing proper event handling in this script, so we just
        # write the exit code for a hardware check script to access.

        if [[ $(uname -p) == "SUNW,Sun-Fire-T200" ]]
        then
            timeout_job "prtdiag -v" >$DIAG_CACHE
            DIAG_CODE=$?
        else
            prtdiag -v >$DIAG_CACHE
            DIAG_CODE=$?
        fi

        print $DIAG_CODE >${DIR_EXIT}/main_prtdiag.exit
	fi

	# Now we're ready to look for, and run, scripts. This is a bit hard to
	# follow, with all the variable substitution, but it works, and it's
	# fast.

	for script in $(ls ${DIR_CHECK}/${class}/check*.sh 2>/dev/null)
	do
		rm -f $TMPFILE
		sbase=${script##*/}	# the basename of the script
		RUNPRT=${sbase}

		# If this script is in the "omit" list, don't go any further

		if [[ -n $OMIT_SCRIPTS && -z $NOSKIP && $OMIT_SCRIPTS == *"$sbase"* ]]
		then
			[[ -n $VERBOSE ]] && print "${RUNPRT}: omitted"
			continue
		fi

		sname=${sbase#check_}
		repair_script="${DIR_REPAIR}/${class}/repair_$sname"
		exit_file="${DIR_EXIT}/${sname%.*}.exit" # where we keep $?
		diag_file="${DIR_DIAG}/${sname%.*}.diag" # where we keep diag output

		# If we're doing hardware checks, have a look for a platform
		# specific version of this script

		[[ $class == "hardware" && \
		-f "${DIR_CHECK}/${class}/${ARCH}/$sbase" ]] \
			&& script="${DIR_CHECK}/${class}/${ARCH}/$sbase"

		[[ -n $VERBOSE ]] && print -n "${RUNPRT}: "

		# Where is the check script output going? We need to record it if
		# we're running verbosely, or if we intend to mail out. Bin it
		# otherwise.

		[[ -n "${DIAG}$MAILTO" ]] \
			&& SCR_OUT=$diag_file \
			|| SCR_OUT=/dev/null

		#- RUN THE SCRIPT ----------------------------------------------------

		# It's possible to run scripts through timeout_job() so no hanging
		# script will bring down the whole monitor. But, I've found that
		# adds a second to each test (jobs(1) still shows the backgrounded
		# job as active on the first test, it *always* has to sleep at least
		# once.) I've not had any problems with check scripts timing out,
		# so, for now, the timeout_job() wrapper isn't used.

		$script >$SCR_OUT

		SCR_EXIT=$?

		#---------------------------------------------------------------------

		# Now look at what the script's exit code was, and act accordingly.

		case $SCR_EXIT in

			0)	# The test was passed, but we may need to send an all-clear,
				# so set the ACTION variable.
				ACTION=1
				;;

			1)	# The test has issued a warning.
				ACTION=1
				(( WARNINGS += 1 ))
				;;

			2)	# Run the repair script, if we have one, and if we've been
				# asked to

				[[ -n $DIR_REPAIR && -f $repair_script ]] \
					&& $repair_script

				ACTION=1
				(( ERRORS += 1 ))
				;;

			3)  # The test can't be run, for a perfectly acceptable reason.
				# For instance, we're asked to examine a log file we don't
				# have.

				[[ -n $VERBOSE ]] && print "not applicable"
				print 3 >$exit_file
				;;

			4)	# The test didn't get any useful information.

				[[ -n $VERBOSE ]] && print "no information"
				print 4 >$exit_file
				;;

			10)	# The test was passed, but we won't want to send an
				# all-clear

				[[ -n $VERBOSE ]] && print "ok"
				print 0 >$exit_file
				;;

			255) # The test timed out

				[[ -n $VERBOSE ]] && print "timed out"
				print 255 >$exit_file
				;;


			*)	# Wha happened?

				[[ -n $VERBOSE ]] \
					&& print "unknown error: [code $SCR_EXIT]"

		esac

		# Do we need to send a mail? handle_return() will work it out, print
		# the status of the check, store the exit code

		if [[ -n $ACTION ]]
		then
			handle_return $sname $SCR_EXIT $SCR_OUT $exit_file
			unset ACTION
		fi

	done

done

# Did we pick up any errors or warnings? If so, exit 100 + the number

(( $ERRORS > 0 || $WARNINGS > 0 )) \
	&& GLOBAL_EXIT=$((100 + $ERRORS + $WARNINGS ))

# Get the time since the epoch, and write it down. This is the last
# successful run time, which is used to make sure we're still running.

END_TIME=$(get_epoch_time)
print $END_TIME >$LAST_RUN

# Did the checks take a particularly long time? If they did, print or send a
# warning, and exit 6

RUN_TIME=$(( $END_TIME - $START_TIME))

if (( $RUN_TIME > $RUN_TIME_THRESHOLD ))
then
	GLOBAL_EXIT=6

	if is_cron
	then
		log_and_send_err "err" "Tests took $RUN_TIME seconds to complete.
Warning threshold is $RUN_TIME_THRESHOLD." $GLOBAL_EXIT
	else
		print -u2 "WARNING: Tests took $RUN_TIME seconds to complete."
	fi

fi

clean_up

exit $GLOBAL_EXIT
