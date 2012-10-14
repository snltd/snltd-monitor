#=============================================================================
#
# check_messages.sh
# -----------------
#
# Look for new messages, today, written to messages. Zone-aware
#
# R Fisher 02/2009
#
# v1.0  Initial Release
#
# v2.0  Rewritten to use new log_checker() function. RDF 26/02/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

DATE_MATCH=$(date "+%b %e")
	# Syslog lines begin with a date in this format

SEV_MATCH="emerg\]|alert\]|crit\]|err\]|warning\]" 
	# Another regex. We only care about log files with these lines

LOGFILE="var/adm/messages"

EXIT=10

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

for zone in $ZONE_LIST
do
	F_PATH="$(get_zone_root_dir $zone)/$LOGFILE"

	if [[ -f $F_PATH ]]
	then
		BLOCK=$(log_checker $F_PATH "$DATE_MATCH" "$SEV_MATCH" | \
		egrep -v "Received DS snmp data out of sequence")

		if [[ -n $BLOCK ]]
		then

			# We flag a warning if the only lines contain "warning".
			# Otherwise, it's an error

			egrep -sv "warning]" $BLOCK \
				&& ERRORS=1 \
				|| WARNINGS=1
		
			if [[ -n $RUN_DIAG ]]
			then
				print "in zone '$zone':\n"
				cat $BLOCK
			fi
	
		fi
	
	else

		[[ -n $RUN_DIAG ]] && \
			print "zone '$zone' does not have a messages file."

		ERRORS=1
	fi

done

if [[ -n $ERRORS ]]
then
	EXIT=2
elif [[ -n $WARNINGS ]]
then
	EXIT=1
fi

exit $EXIT

