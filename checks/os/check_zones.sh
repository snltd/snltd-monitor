#=============================================================================
#
# check_zones.sh
# --------------
#
# Look to see if the state of each zone has changed since last invocation.
# Just compare zoneadm list -cv now with last time
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Smarter rewrite. RDF 13/04/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

typeset -R25 zone

STATE_FILE="${DIR_STATE}/zone_state"
EXIT=0
NEWLIST="${TMPFILE}.1"
OLDLIST="${TMPFILE}.2"

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

can_has zonename \
	|| exit 3

# We store the zone names and their states (running/installed/whatever) in
# a file, which we diff against the current corresponding list.

zoneadm list -cp | cut -d: -f2,3 | sort >$TMPFILE

if [[ -s $STATE_FILE ]]
then

	# Compare the zoneadm output with the last run

	cmp -s $TMPFILE $STATE_FILE \
		|| EXIT=1

	# Diag block. Just diff the state file and the temp file and massage the
	# output a little.

	if [[ $EXIT == 1 && -n $RUN_DIAG ]]
	then
		# First, look to see if any zones are missing or new.

		cut -d: -f1 $TMPFILE >$NEWLIST
		cut -d: -f1 $STATE_FILE >$OLDLIST

		# Look for zones which no longer exist. Exit with an error if there
		# are any

		comm -23 $OLDLIST $NEWLIST | while read zone
		do
			print "${zone}: removed since last check"
			EXIT=2
		done

		# Look for new zones. These only trigger a warning, and we're
		# already flagged for one of those. (Unless we're exiting ERROR, in
		# which case we don't want to overrule that.)

		comm -13 $OLDLIST $NEWLIST | while read zone
		do
			print "${zone}: created since last check"
		done

		# We've finished with NEWLIST and OLDLIST now

		rm -f $NEWLIST $OLDLIST

		# Diff the two lists, and print out the old and new states. Run the
		# lot through a reverse sort

		diff $STATE_FILE $TMPFILE | egrep "^[><]" | \
		while read pointer zs
		do
			zone=${zs%:*}

			[[ $pointer == "<" ]] \
				&& print "$zone : previously '${zs#*:}'" \
				|| print "$zone : now        '${zs#*:}'"

		done | sort -r

	fi

fi

mv $TMPFILE $STATE_FILE
exit $EXIT

