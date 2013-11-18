#!/bin/ksh

#=============================================================================
#
# check_ntp.sh
# ------------
#
# Can we see our NTP servers?
#
# R Fisher 01/2009
#
# v1.0 Initial Release
#
#=============================================================================

. $LIBRARY

#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# This is an easy one. Just do an "ntp assoc" and make sure we have at
# least two peers.  Error if not.

if [[ $(/usr/sbin/ntpq -c as 2>/dev/null | grep -wc sys_peer) -lt 2 ]]
then
	EXIT=2

	[[ -n $RUN_DIAG ]] && /usr/sbin/ntpq -c as 2>&1
fi

exit $EXIT
