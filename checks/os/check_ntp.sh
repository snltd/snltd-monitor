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

#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# This is an easy one. Just do an "ntp assoc" and make sure we have two
# reachables.  Error if not.

if [[ $(ntpq -c assoc 2>/dev/null | grep -w reachable | wc -l) -lt 2 ]]
then
	EXIT=2

	[[ -n $RUN_DIAG ]] \
		&& ntpq -c assoc 2>&1
fi

exit $EXIT
