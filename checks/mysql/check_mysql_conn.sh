#=============================================================================
#
# check_mysql_conn.sh
# -------------------
#
# Checks MySQL can be contacted.
#
# Requires a special "snltd_monitor" account on the target database servers,
# and a list of those servers in the host-specific config-file.
#
# Requirements

# mysql> create database snltd_monitor;
# mysql> grant select on snltd_monitor.* to 'snltd_monitor'@'%'
#        identified by 'l3-Wd.xx9';
# mysql> use snltd_monitor;
# mysql> create table check_table ( pkey int, value varchar(10) );
# mysql> insert into check_table values(0, "connected");
#
# For cs-dev-01z-mysql50, grant the select to 'snltd_monitor'@'cs-dev-01%'
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

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# The list of zones to study can be defined in the server config file.
# If one isn't given, we exit

[[ -n $MYSQL_CONN_HOSTS ]] || exit 3

# We need a MySQL binary

can_has mysql || exit 3

# And a config file

[[ -f $CONN_FILE ]]G|| exit 4

for host in $MYSQL_CONN_HOSTS
do
	# The following check should return "connected"

	SQL_RET=$(mysql \
		--defaults-file=$CONN_FILE \
		--host $host \
		--silent \
		--skip-column-names \
		snltd_monitor \
		-e \
		"SELECT value FROM check_table WHERE pkey=0" 2>&1)

	# If we connect, there's nothing to do. If we get an access denied
	# message, we're going to flag a warning later. If we plain can't
	# connect, or get any other error, we flag an error.

	if [[ $SQL_RET == "connected" ]]
	then
		:
	elif [[ $SQL_RET == "ERROR 1045 "* ]]
	then
		WARNING=1

		[[ -n $RUN_DIAG ]] \
			&& print "response from host '${host}'\n\n${SQL_RET}\n"

	else
		ERROR=1

		[[ -n $RUN_DIAG ]] \
			&& print "response from host '${host}'\n\n${SQL_RET}\n"

	fi

done

if [[ -n $ERROR ]]
then
	EXIT=2
elif [[ -n $WARNING ]]
then
	EXIT=1
else
	EXIT=0
fi

exit $EXIT

