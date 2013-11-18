#!/bin/ksh

#=============================================================================
#
# check_disk_errs.sh
# ------------------
#
# See how many disks are visible to the system. Issue a warning if that
# number has increased (just to show we're paying attention!) and an error
# if the number has dropped.
#
# Then, look at iostat -E for disks. Flag a warning if we have soft errors >
# $S_LIMIT. Flag an error if we have hard errors
#
# R Fisher 01/2009
#
# v1.0 Initial Release
#
# v1.1 More verbose reporting on changed disk numbers. RDF 14/04/09
#
# v1.2 Suppress format error on KVM virtual disks. RDF 14/11/13
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

S_LIMIT=${S_ERR_LMT:-20}
	# The number of soft errors over which we flag a warning

DISK_STATE="${DIR_STATE}/disk_list"
EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# Get a list of the disk drives on the system

print | pfexec format 2>/dev/null \
	| sed -n '/[0-9]\./s/^.*[0-9]\. \([^ ]*\) .*$/\1/p' | sort \
	>$TMPFILE 2>/dev/null

if [[ -f $DISK_STATE ]]
then

    # Cat these into wc so we don't get leading whitespace that makes
    # the output look ugly.

	ODC=$(cat $DISK_STATE | wc -l)
	NDC=$(cat $TMPFILE | wc -l)

	ODC=${ODC##* }
	NDC=${NDC##* }

	# Have we lost a disk?

	if [[ $ODC -gt $NDC ]]
	then
		EXIT=2

		if [[ -n $RUN_DIAG ]]
		then
			print \
			"Disk count has decreased from $ODC to $NDC.\n\nOld disk list:\n"
			cat $DISK_STATE
			print "\nNew disk list:\n"
			cat $TMPFILE
		fi

	# Or have we gained one?

	elif [[ $ODC -lt $NDC ]]
	then
		EXIT=1

		if [[ -n $RUN_DIAG ]]
		then
			print \
			"Disk count has increased from $ODC to $NDC.\n\nOld disk list:\n"
			cat $DISK_STATE
			print "\nNew disk list:\n"
			cat $TMPFILE
		fi
	fi

fi

# Now we look at the disks on the system

iostat -En | awk ' /Errors/ { print $1, $7, $10 }' | while read dev soft hard
do

	# Is this a physical disk which is in the disk list? We check both disk
	# lists in case the number has changed. They're so small that it's no
	# extra effort. Skip this device if it's not a disk

	[[ -f $DISK_STATE && -f $TMPFILE ]] \
	&& egrep -s "^$dev$" $DISK_STATE $TMPFILE || continue

	if [[ $hard -gt 0 ]]
	then
		EXIT=2
	# Don't decrease the exit status if it's already been set to 2

	elif [[ $soft -gt $S_LIMIT ]] && [[ $EXIT -lt 2 ]]
	then
		EXIT=1
	fi

done

# Replace the old disk list with the new one

mv $TMPFILE $DISK_STATE

exit $EXIT
