#=============================================================================
#
# check_dns_proc.sh
# -----------------
#
# Checks for BIND processes.
#
# R Fisher 03/2009
#
# v1.0 Initial Release
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

# The list of zones to study can be defined in the server config file.
# If one isn't given, we look at all zones.

DNS_ZONES=${DNS_ZONES:=$ZONE_LIST}

DNS_DATA_DIR="/var/named"
	# Local site convention is to keep BIND data in /var/named. If we
	# examine a zone and it doesn't have that directory, we skip it

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

is_global \
	|| exit 3

for zone in $DNS_ZONES
do

	# Only look at zones with a DNS_DATA_DIR

	if [[ -d $(get_zone_root_dir $zone)/$DNS_DATA_DIR ]]
	then
		FOUND=1

		# There should be a named process running. 

		if ! pgrep -z $zone ^named$ >/dev/null 2>/dev/null 
		then
			# Any missing processes in zones with a DNS_DATA_DIR means we
			# flag an error

			ERROR=true

			[[ -n $RUN_DIAG ]] \
				&& cat<<-EOOUT
				In zone '$zone':

				Found BIND data directory $DNS_DATA_DIR, but did not find a
				'named' process. Output of 
				
				  pgrep -fl -z $zone named

				follows. 

				  ------- BEGIN OUTPUT ------

				    $(pgrep -fl -z $zone named)

				  ------- END OUTPUT --------

				EOOUT

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

