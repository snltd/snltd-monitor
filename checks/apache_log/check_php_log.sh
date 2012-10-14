#=============================================================================
#
# check_php_log.sh 
# ---------------- 
#
# Look for errors in the PHP log
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

DIR_APACHE="/usr/local/apache"
	# Local site convention is to keep Apache in /usr/local/apache. If we
	# examine a zone and it doesn't have that directory, we skip it

DATE_MATCH="^\[$(date "+%d-%b-%Y") "
	# The PHP error log date format

SEV_MATCH="Fatal|Warning"

LOG_PATH="var/apache/logs/php_error.log"
	# Path, relative to root, of the PHP error log

WARN_SIZE="50000"
	# Size of PHP error log, in bytes, above which we issue an error

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

is_global \
    || exit 3

ZONES=${APACHE_ZONES:=$(get_apache_zones $ZONE_LIST)}

# Unlike Apache logs, there's only going to be one PHP error log per zone.
# At the most. So, we'll loop through the zones.

for zone in $ZONES
do
	# Look to see if there's a log file

	F_PATH="$(get_zone_root_dir $zone)/$LOG_PATH"
	
	if [[ -s $F_PATH ]]
	then

		# If the file massive?

		LSIZE=$(check_file_size $F_PATH $WARN_SIZE)

		if [[ -n $LSIZE ]]
		then
			WARNINGS=1
			
			[[ -n $RUN_DIAG ]] \
				&& cat<<-EOOUT
				in zone '$zone':
				  
				              file size: ${LSIZE}b
				 size warning threshold: ${WARN_SIZE}b
				        local zone path: /${LOG_PATH}
				       global zone path: $F_PATH

				EOOUT
		fi

		# Parse today's block from the log file
	
		BLOCK=$(log_checker $F_PATH "$DATE_MATCH" "$SEV_MATCH")

		if [[ -n $BLOCK ]]
		then
			
			egrep -sv Warning $BLOCK \
				&& ERRORS=1 \
				|| WARNINGS=1

			if [[ -n $RUN_DIAG ]]
			then
				print "in zone '$zone':"
				cat $BLOCK
				print
			fi

		fi
		
	else

		# There isn't. Should there be?. This check works for all apache and
		# PHP versions. Only 2.1 has httpd -t -D DUMP_MODULES
	
		if pgrep -z $zone -o httpd >/dev/null \
			&& pldd $(pgrep -z $zone -o httpd) 2>/dev/null | egrep -s libphp
		then
			ERRORS=1
			
			[[ -n $RUN_DIAG ]] \
				&& cat<<-EODIAG
				in zone '$zone':
				 
				  No PHP log file found.

				Expected paths:
				    local zone: /${LOG_PATH}
				   global zone: $F_PATH

				EODIAG
		fi

	fi

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

exit $EXIT
