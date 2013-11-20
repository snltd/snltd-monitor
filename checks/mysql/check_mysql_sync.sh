#!/bin/ksh

#=============================================================================
#
# check_mysql_sync.sh
# -------------------
#
# Looks at the master and slave statuses.
#
# Requires a special "snltd_monitor" account on the target database servers,
# and a list of those servers in the host-specific config-file.
#
# mysql> grant super,replication client on *.* to 'snltd_monitor'@'cs-db-%'
#        identified by 'l3-Wd.xx9';
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Slightly tidied. RDF 10/03/09
#
#=============================================================================

. $LIBRARY

#-----------------------------------------------------------------------------
# VARIABLES

TMPFILE_1="${TMPFILE}${RANDOM}_1"
TMPFILE_2="${TMPFILE}${RANDOM}_2"

THRESHOLD=${MYSQL_SYNC_DIFF:-5000}
	# The difference in log positions we consider "safe"

CONN_FILE="${DIR_CONFIG}/mysql_connect"
    # Where to find the MySQL connection details

#-----------------------------------------------------------------------------
# FUNCTIONS

run_query()
{
	# Run a MySQL query
	# $1 is the host to run the query on
	# $2 is the query to run

	mysql \
		--defaults-file=$CONN_FILE \
		--host $1 \
		--silent \
		--skip-column-names \
		snltd_monitor \
		-e \
	"$2" 2>/dev/null
}

get_key()
{
	# $1 is the file
	# $2 is the key

	sed -n "/ $2/s/^.*$2: //p" $1
}

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# The list of zones to study can be defined in the server config file.
# If one isn't given, we exit

[[ -n $MYSQL_SYNC_LIST ]] || exit 3

# We need a MySQL binary

can_has mysql || exit 3

[[ -f $CONN_FILE ]] || exit 4

# Parse the sync list

for cluster in $(print $MYSQL_SYNC_LIST | tr : " ")
do
	unset LOOP_DIAG

	lb_name=${cluster%%@*}
	nodes=${cluster##*@}
	node_1=${nodes%%,*}
	node_2=${nodes##*,}

	# Get the master and slave status of each node

	run_query $node_1 "SHOW MASTER STATUS" | read mlf1 mlp1
	run_query $node_1 "SHOW SLAVE STATUS\G" >$TMPFILE_1
	run_query $node_2 "SHOW MASTER STATUS" | read mlf2 mlp2
	run_query $node_2 "SHOW SLAVE STATUS\G" >$TMPFILE_2

	sir1=$(get_key $TMPFILE_1 "Slave_IO_Running")
	sir2=$(get_key $TMPFILE_2 "Slave_IO_Running")
	ssr1=$(get_key $TMPFILE_1 "Slave_SQL_Running")
	ssr2=$(get_key $TMPFILE_2 "Slave_SQL_Running")
	slf1=$(get_key $TMPFILE_1 " Master_Log_File")
	slf2=$(get_key $TMPFILE_2 " Master_Log_File")
	slp1=$(get_key $TMPFILE_1 "Read_Master_Log_Pos")
	slp2=$(get_key $TMPFILE_2 "Read_Master_Log_Pos")

	# Only try to work out the log differences if we got readings. Otherwise
	# you get an ugly arithmentic error

	if [[ -n $mlp1 && -n $mlp2 && -n $slp1 && -n $slp2 ]]
	then
		diff1=$(($mlp1 - $slp2))
		diff2=$(($mlp2 - $slp1))
	else
		diff1="unknown"
		diff2="unknown"
	fi

	# Only try to work out the log differences if we got readings. Otherwise
	# Does MySQL think the slaves are both running? If not, that's
	# DEFINITELY an error

	if [[ "${sir1}${sir2}${ssr1}${ssr2}" != "YesYesYesYes" ]]
	then
		ERRORS=1
		LOOP_DIAG=1
	else

	# We still need to compare the log files and log positions, though
	# there's little point doing that if the slave test above failed

		if [[ $mlf1 != $slf2 ]] || [[ $mlf2 != $slf1 ]]
		then
			# The log files don't compare. That's bad.
			ERRORS=1
			LOOP_DIAG=2
		elif [[ $diff1 -gt $THRESHOLD || $diff2 -gt $THRESHOLD ]]
		then
			# The log file positions differ by more than the THRESHOLD.
			# That's a warning

			WARNINGS=1
			LOOP_DIAG=3
		fi

	fi

	if [[ -n $RUN_DIAG && -n $LOOP_DIAG ]]
	then

		# Fill in some descriptive text for the positions

		cat<<-EOOUT

		On MySQL cluster '$lb_name':

		   slave IO running on ${node_1}: ${sir1:-unknown}
		   slave IO running on ${node_2}: ${sir2:-unknown}

		  slave SQL running on ${node_1}: ${ssr1:-unknown}
		  slave SQL running on ${node_2}: ${ssr2:-unknown}

		    master log file on ${node_1}: ${mlf1:-unknown}
		     slave log file on ${node_2}: ${slf2:-unknown}

		     slave log file on ${node_1}: ${slf1:-unknown}
		    master log file on ${node_2}: ${mlf2:-unknown}

		     master log pos on ${node_1}: ${mlp1:-unknown}
		      slave log pos on ${node_2}: ${slp2:-unknown} [$diff1 difference]

		      slave log pos on ${node_1}: ${slp1:-unknown}
		     master log pos on ${node_2}: ${mlp2:-unknown} [$diff2 difference]

		  acceptable difference in log positions is ${THRESHOLD}.

		           loop diag is $LOOP_DIAG

		EOOUT
	fi

done

rm $TMPFILE_1 $TMPFILE_2

if [[ -n $ERRORS ]]
then
	EXIT=2
elif [[ -n $WARNINGS ]]
then
	EXIT=1
else
	EXIT=0
fi

exit $EXIT
