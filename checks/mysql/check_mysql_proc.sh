#=============================================================================
#
# check_mysql_proc.sh
# -------------------
#
# Checks for MySQL processes.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.2 Original check for "mysqld" caught mysqldump too. Now a bit cleverer.
#
# v1.3 Ditto, but I think I got it right this time. RDF 02/03/09.
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

# The list of zones to study can be defined in the server config file.
# If one isn't given, we look at all zones.

MYSQL_ZONES=${MYSQL_ZONES:=$ZONE_LIST}

MYSQL_DATA_DIR=${MYSQL_DATA_DIR:=data/mysql}
	# Local site convention is to keep MySQL data in /data/mysql. If we
	# examine a zone and it doesn't have that directory, we skip it

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

is_global || exit 3

for zone in $MYSQL_ZONES
do

	# Only look at zones with a MYSQL_DATA_DIR

	unset FOUND_D FOUND_SAFE_D

	if [[ -d $(get_zone_root_dir $zone)/$MYSQL_DATA_DIR ]]
	then

		# There should be two mysqld processes running. Need the -f to
		# identify the mysqld, because we have to specify part of the path
		# to make it unique

		pgrep -z $zone ^mysqld$ >/dev/null 2>/dev/null \
			&& FOUND_D=1

		pgrep -z $zone ^mysqld_safe$ >/dev/null 2>/dev/null \
			&& FOUND_SAFE_D=1

		if [[ -n $FOUND_D && -n $FOUND_SAFE_D ]]
		then
			FOUND=true
		else
			# Any missing processes in zones with a MYSQL_DATA_DIR means we
			# flag an error

			ERROR=true

			if [[ -n $RUN_DIAG ]]
			then

				[[ -n $FOUND_D ]] \
					&& PRT_D="found" \
					|| PRT_D="missing"

				[[ -n $FOUND_SAFE_D ]] \
					&& PRT_SAFE_D="found" \
					|| PRT_SAFE_D="missing"

				cat<<-EOOUT
				In zone '$zone':

				Missing processes:

				        data directory : $MYSQL_DATA_DIR
				       'mysqld' process: $PRT_D
				  'mysqld_safe' process: $PRT_SAFE_D

				Output of

				  'pgrep -fl -z $zone mysqld'

				follows. This should show a mysqld and a mysqld_safe process.

				  ------- BEGIN MYSQLD OUTPUT ------

				$(pgrep -fl -z $zone mysqld)

				  ------- END MYSQLD OUTPUT --------

				EOOUT

			fi

		fi

	fi

done

if [[ -n $ERROR ]]
then
	EXIT=2
elif [[ -n $FOUND ]]
then
	EXIT=0
else
	EXIT=3
fi

exit $EXIT

