#=============================================================================
#
# check_sc.sh
# -----------
#
# Try to work out whether or not the system controller is working. Exit 1 if
# it can't be pinged, 2 if we can't get a suitable looking IP address.
#
# R Fisher 01/2009
#
# v1.0 Initial Release RDF
#
# v1.1 Uses wrapper to run scadm, so can be run by "monitor" user rather
#      than root. RDF 23/03/09.
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

SCADM="$RUN_WRAP scadm"

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# We'll assume the SC is working if it can tell us its IP address, and that
# IP address is pingable

if $RUN_WRAP -t scadm 
then
	SC_IP=$($SCADM show netsc_ipaddr 2>/dev/null | cut -d\" -f2)
	
	if [[ x$SC_IP == x10.10.8.* ]]
	then

		ping $SC_IP 5 >/dev/null 2>&1 \
			&& EXIT=0 \
			|| EXIT=1

	else
		EXIT=2
	fi

	# Diagnostic information here

	if [[ -n $RUN_DIAG ]]
	then

		if (( $EXIT == 1 ))
		then
			print "cannot ping SC's IP address [$SC_IP]"
		elif (( $EXIT == 2 ))
		then
			print \
			"Unexpected, or no IP address. [expected 10.10.8.*, got ${SC_IP}]"
			print "\nQuerying SC:\n"
			$SCADM show
		fi

	fi

	# End of diagnostics

else
	EXIT=4
fi

exit $EXIT
