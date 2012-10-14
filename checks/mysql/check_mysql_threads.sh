#=============================================================================
#
# check_mysql_threads.sh
# ----------------------
#
# Checks the number of threads MySQL has running.
#
# Requires a special "snltd_monitor" account on the target database servers,
# and a list of those servers in the host-specific config-file.
#
# Requirements

# mysql> create database snltd_monitor;
# mysql> grant select on snltd_monitor.* to 'snltd_monitor'@'%' 
#        identified by 'l3-Wd.xx9';
# mysql> create table check_table ( pkey int, value varchar(10) );
# mysql> insert into check_table values(0, "connected");
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

CONN_FILE="${DIR_CONFIG}/mysql_connect"
    # Where to find the MySQL connection details

THREADS_MIN=1
THREADS_MAX=100

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# The list of zones to study can be defined in the server config file.
# If one isn't given, we exit

[[ -n $MYSQL_CONN_HOSTS ]] \
	|| exit 3

# We need a MySQL binary

can_has mysql \
	|| exit 3

[[ -f $CONN_FILE ]] \
    || exit 4

for host in $MYSQL_CONN_HOSTS
do
	unset THREADS

	# The following check returns the number of running threads. We can't
	# use the PROCESSLIST table, because we have to support MySQL-4.1.
	# Thankfully 3 has finally gone, because *EVERYTHING* is different on
	# that.

	THREADS=$(mysql \
		--defaults-file=$CONN_FILE \
		--host $host \
		--silent \
		--skip-column-names \
		snltd_monitor \
		-e \
	"SHOW STATUS LIKE 'Threads_Running'" 2>/dev/null)

	THREADS=${THREADS#*	}
		# That's a tab ^

	# If we couldn't connect, THREADS will be unset

	if [[ -z $THREADS && -n $RUN_DIAG ]]
	then
		print "Could not connect to host '${host}'."
		ERRORS=1
	elif [[ -n $RUN_DIAG ]]
	then

		if (( $THREADS < $THREADS_MIN || $THREADS > $THREADS_MAX ))
		then
			WARNINGS=1

			[[ -n $RUN_DIAG ]] \
				&& cat<<-EODIAG

for MySQL host '$host'

  Expected to find between $THREADS_MIN and $THREADS_MAX threads on MySQL
  server. Found $THREADS

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
else
	EXIT=0
fi

exit $EXIT

