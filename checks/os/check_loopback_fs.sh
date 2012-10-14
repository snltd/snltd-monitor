#=============================================================================
#
# check_loopback.sh
# -----------------
#
# We've had problems with loopback mounted /usr/local filesystems suddenly
# appearing empty from the local zone.
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
# v1.1 Found out we don't have to use zlogin, amended accordingly. RDF
#      07/05/09
#
# v1.2 Check for hidden files also. RDF 03/04/10
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# For each zone, get a list of loopback mounted filesystems, examine the
# mountpoint to make sure the fs is mounted. We've had directories "lost"
# this way in the past

for zone in $ZONE_LIST
do
	# We don't want global -- it can't have lofs filesystems

	[[ $zone == "global" ]] && continue

	# For each LOCAL zone...
	
	# Check the zone is up. It it's down, the tests will fail

	zoneadm list | egrep -s ^${zone}$ || \
		continue

	# Get a list of all the loopback filesystems from zonecfg, and check
	# each one has something in it. You can do with with ls from the global
	# zone.

	Z_ROOT=$(get_zone_root_dir $zone)

	# EMPTY_DIRS is a list of empty directories in this zone

	unset EMPTY_DIRS

	zonecfg -z $zone info fs type=lofs | sed -n '/dir:/s/^.*dir: //p' | \
	while read dir
	do

		# Pipe ls into head just in case the directory is very big. Screen
		# out . and ..

		[[ -z $(ls -a ${Z_ROOT}/$dir | egrep -v "^\.*$" | head -1) ]] \
			&& EMPTY_DIRS="$EMPTY_DIRS $dir"

	done

	# Did we get any empty directories?

	if [[ -n $EMPTY_DIRS ]]
	then
		EXIT=2
		
		# Diagnostic block. We'll tell the user where the failed filesystems
		# should be mounted from, for easier diagnosis.

		if [[ -n $RUN_DIAG ]]
		then
			print "in zone '$zone' the following filesystems are empty:\n"

			for edir in $EMPTY_DIRS
			do
				print "  $edir (mounted from $(zonecfg -z $zone info fs \
				dir=$edir | sed -n \ '/special:/s/^.*special: //p'))"
			done
		fi

	fi

done

exit $EXIT
