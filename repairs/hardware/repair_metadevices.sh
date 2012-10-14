#!/bin/ksh

#=============================================================================
#
# repair_metadevices.sh
# ---------------------
#
# Have a go at fixing broken mirrors. Just a call to metarepair -e really
#
# v1.0 Initial Relase
#
#=============================================================================

[[ -s $LIBRARY ]] && . $LIBRARY || exit 254

#-----------------------------------------------------------------------------
# VARIABLES

ERR=0

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# only root can run metarepair

is_root || exit 1

metastat -p | grep " c" | cut -d\  -f1 | while read md
do
	dev=$(metastat $md | sed -n "/Maintenance/s/^.*\(c[0-9][^ ]*\).*$/\1/p")

	if [[ -n $dev ]]
	then
		fs_md=$(metastat -p | sed -n "/-m.* $md /s/ .*$//p")
		print "repairing $fs_md [$dev]"
		metareplace -e $fs_md $dev || ERR=$((ERR + 1))
	fi

	sleep 1

done
echo "exiting $ERR"

exit $ERR
