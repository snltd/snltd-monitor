#=============================================================================
#
# check_multipath.sh
# ------------------
#
# Check the multipathing to the 3510
#
# Check multipath status. If both paths are up, we should see four remote
# ports. 
#
# Exit 0 if all four ports are found. Exit 2 if any are missing.
#
# Run as root, or as a normal user with the file_dac_read and sys_devices
# privileges.
#
#   usermod -P monitor
#   usermod -K defaultpriv=Basic,file_dac_read,sys_devices monitor
#
# R Fisher 02/2009
#
# v1.0 Initial Release
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

REQUIRED_PORTS=4
PERM_FILE="${DIR_PERM}/has_multipath"
FCINFO="$RUN_WRAP fcinfo"

EXIT=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

${FCINFO% *} -t fcinfo \
	|| exit 3

# If the file server mysteriously lost both ports, this script might think
# it's not supposed to have any HBAs, and not report an error. To get round
# this, whenever we see an HBA, we create a file in the DIR_PERM. Once
# that's there (the monitor can't remove it), this script will always assume
# there should be HBAs, and error if none are found.

if [[ $($FCINFO hba-port ) == "No Adapters Found." ]]
then
	
	# There aren't any HBAs. Do we think there should be?

	if [[ -f $PERM_FILE ]]
	then
		EXIT=1

		[[ -n $RUN_DIAG ]] \
			&& print "  No HBAs found."

	else
		# Doesn't look like we expect to find any adapters.

		EXIT=3
	fi

else

	# touch the PERM_FILE. We have HBAs now, so we should always expect to
	# have them in future.

	>$PERM_FILE

	# Get the WWNs of all the local HBA ports, and look how many remote ports
	# each one can see.

	# It would be easier (and probably enough) just to count the state: onlines
	# from fcinfo, but I want to make sure the ports can both see two remote
	# ports too.

	$FCINFO hba-port | sed -n '/^HBA/s/.* //p' | while read port
	do

		# If the port is online -- count it, and see how many remote ports it
		# can see

		$FCINFO hba-port $port | egrep -s online \
			&& REMOTE_PORTS=$(($REMOTE_PORTS + \
			$($FCINFO remote-port -p $port | egrep -c "Remote Port WWN:")  ))

	done

	# Issue an error if there are less ports than we expect. Issue a warning
	# if there are more. (No, I don't know how that could happen either.)

	if [[ $REMOTE_PORTS -lt $REQUIRED_PORTS ]]
	then
		EXIT=2
	elif [[ $REMOTE_PORTS -gt $REQUIRED_PORTS ]]
	then
		EXIT=1
	else
		EXIT=0
	fi

	[[ $EXIT -gt 0 && -n $RUN_DIAG ]] \
		&& print \
		"  Found $REMOTE_PORTS remote ports. Expected $REQUIRED_PORTS"

fi

exit $EXIT
