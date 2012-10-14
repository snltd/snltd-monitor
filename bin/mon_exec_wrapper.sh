#!/bin/ksh

#=============================================================================
#
# mon_exec_wrapper.sh
# -------------------
#
# Wrapper to allow the "monitor" user to run programs like sccli(1m) and
# scadm(1m) as root. They aren't privilege aware, and do some kind of
# rudementary "am I root?" check which I can't work out how to get around
# purely with RBAC.
#
# Only use this wrapper for programs which CANNOT be run through RBAC. This
# is a brutal and clumsy substitute. Hopefully Sun will make the programs we
# call here privilege-aware, and this can be done away with altogether.
#
# Requires the "monitor" user exists, and that he has the following
# authorizations:
#
# /etc/user_attr
# monitor::::type=normal;profiles=snltd Monitor
#
# /etc/security/exec_attr
# snltd Monitor:solaris:cmd:::/full_path/mon_exec_wrapper.sh.sh:uid=0;gid=0
#
# /etc/security/exec_attr
# snltd Monitor:::Profile for snltd Monitor script:
#
# To add a new command, put its full path in the VARIABLES section, with a
# descriptive name. Then add a case with just the executable name, and an
# EXEC= assignment, pointing to the variable name. If you want to allow the
# calling script to pass args, append $*.
#
# If -t is supplied, then we just look to see if the command passed exists
# on the box and is executable. Exit 0 if it does, 1 it it does not.
#
# In normal operation, exists 2 if the specified command is not allowed to
# be run. If a program is run, exit code is the exit code of that program.
#
# R Fisher 03/09
#
# v1.0 Initial release
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

# Full paths to commands we will run as root.

SCADM="/usr/platform/$(uname -i)/sbin/scadm"
	# required by check_sc.sh

SCCLI="/usr/sbin/sccli"
	# required by nearly all the 3510 checks

FCINFO="/usr/sbin/fcinfo"
	# required by the check_multipath.sh script

BPDBJOBS="/usr/openv/netbackup/bin/admincmd/bpdbjobs"
	# required by check_nb_logs.sh

BPTPCINFO="/opt/openv/netbackup/bin/bptpcinfo"
	# required by check_jukebox.sh

BPTESTBPCD="/usr/openv/netbackup/bin/admincmd/bptestbpcd"
	# required by check_nb_clients.sh

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# We only allow VERY specific commands to be run

[[ $# == 0 ]] \
	&& { print "usage: ${0##*/} [-t] <cmd> [args]"; exit 2; }

while getopts "t" option
do

    case $option in

		"t")	TEST_ONLY=1
				;;
	
	esac

done

shift $(($OPTIND -1 ))

CMD=$1

shift

case $CMD in
	
	"bpdbjobs")
		EXEC="$BPDBJOBS $@"
		;;

	"bptestbpcd")
		EXEC="$BPTESTBPCD $@"
		;;

	"bptpcinfo")
		EXEC="$BPTPCINFO $@"
		;;

	"fcinfo")
		EXEC="$FCINFO $@"
		;;

	"scadm")
		EXEC="$SCADM $@"
		;;
	
	"sccli")
		# We never run sccli with arguments
		EXEC="$SCCLI"
		;;

esac

if [[ -n $EXEC ]]
then

	if [[ -n $TEST_ONLY ]]
	then

		[[ -x ${EXEC%% *} ]] \
			&& EXIT=0 \
			|| EXIT=1

	else
		$EXEC
		EXIT=$?
	fi

else
	EXIT=2
fi

exit $EXIT
