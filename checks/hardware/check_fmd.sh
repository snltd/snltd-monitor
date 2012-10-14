#=============================================================================
#
# check_fmd.sh
# ------------
#
# Pass on anything the fault manager has to report. Most likely (hopefully)
# the other scripts will catch and detail anything this catches, but better
# to have problems reported twice than not at all.
#
# Subject to change, because I'm not that good at fmd.
#
# Requires the following in /etc/security/exec_attr:
#
# snltd Monitor:solaris:cmd:::/usr/sbin/fmadm:euid=0
#
#
# R Fisher 01/2009
#
# v1.0 Initial Release
#
# v1.1 Uses pfexec to run fmadm.
#
# v1.2 Removed heredocs, as they were causing oddness. A /tmp/shxxxx.x file
#      was being left behind by the main monitor. I couldn't get to the
#      bottom of WHY, but at least it's fixed. RDF 05/04/09.
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# FUNCTIONS

analyze_fmdump()
{
	# $1 is the file with the fmadm UUIDs we wish to analyze
	# $2 is set if the errors are cleared

	print -n "The following errors have been recorded"

	[[ -n $2 ]] \
		&& print " and cleared"

	print "by the fault management system."

	[[ -n $2 ]] \
		&& print "\n\nPlease investigate these faults."

	while read uuid
	do
		fmdump -v -u $uuid
	done <$1
}

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

can_has fmadm \
	|| exit 3

# First, check for corrected faults. Issue warnings on these 

rm -f $TMPFILE

pfexec fmadm faulty -avs | egrep -v ^"TIME|---" | cut -c 17-52 >$TMPFILE

if [[ -s $TMPFILE ]]
then
	EXIT=1

	[[ -n $RUN_DIAG ]] \
		&& analyze_fmdump $TMPFILE true
		
fi

# now look for things still in the fault log

pfexec fmadm faulty -vs | egrep -v ^"TIME|---" | cut -c 17-52 >$TMPFILE

if [[ -s $TMPFILE ]]
then
	EXIT=2

	[[ -n $RUN_DIAG ]] \
		&& analyze_fmdump $TMPFILE

fi

exit $EXIT

