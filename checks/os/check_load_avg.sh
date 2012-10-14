#=============================================================================
#
# check_load_avg.sh
# -----------------
#
# Look at the load average on the box and warn if it's greater than the
# number of cores. Issue an error if it's more than double the core count. I
# know load average is next to useless, but people expect this kind of
# thing.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Increase threshold if we're doing a zpool scrub. RDF
#
# v1.2 Add LOAD_S_LMT and LOAD_H_LMT variables to override defaults. RDF
#      21/07/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

CORES=$(psrinfo | wc -l)

# See below for the reason we x 100

SOFT=$((100 * ${LOAD_S_LMT:-CORES}))
HARD=$((200 * ${LOAD_H_LMT:-CORES}))
EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# Double the warning threshold if the zpools are being scrubbed. The load on
# cs-fs-01 goes right up when the scrub happens, but it's at a completely
# dead time for us, so it doesn't matter.

if zpool status | egrep -s "scrub in progress"
then
	((SOFT = $SOFT * 2))
	((HARD = $HARD * 2))
fi

# ksh88 can't do floating point arithmetic, so get the 1 minute load
# average, and remove the decimal point. Then compare it to 100 times the
# CPU count

LOAD=$(uptime | sed 's/^.*: \([^,]*\).*$/\1/;s/\.//')

if [[ $LOAD -gt $HARD ]]
then
	EXIT=2
elif [[ $LOAD -gt $SOFT ]]
then
	EXIT=1
fi

# Diag block, if we need it

if [[ -n $RUN_DIAG && $EXIT -gt 0 ]]
then

	# Just run prstat, collating zone information, and showing the top 10
	# CPU users on the whole box. It's piped into cat because that gets rid
	# of some clear sceen type stuff prstat does, which screws up the output
	# if you're running interactively

	prstat -Zn10 -s cpu 1 1 | cat
fi

exit $EXIT

