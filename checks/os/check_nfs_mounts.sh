#!/bin/ksh

#=============================================================================
#
# check_nfs_mounts.sh
# -------------------
#
# Do we have all the NFS filesystems that should be mounted?
#
# R Fisher 01/2009
#
# v1.0 Initial Release
#
# v1.1 Now ignores filesystems commented out of vfstab. RDF 21/04/09
#
#=============================================================================

. $LIBRARY

#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

for zone in $ZONE_LIST
do
	ZROOT=$(get_zone_root_dir $zone)

	/bin/awk '{ if ($1 ~ /^[a-z].*:/)  print $1,$3 }' ${ZROOT}/etc/vfstab | \
	while read fs mpt
	do

		# Look to see if we can see any files in the directory. We have to
		# do this via zlogin, because if you try to list the directory from
		# the global zone, you get an error.

		if [[ -z $(zone_run "ls $mpt" $zone) ]]
		then
			EXIT=2
			print -n "in zone '$zone':\n  "

			# Does df think the filesystem is mounted? We have to do this
			# from the zone

			if [[ -n $RUN_DIAG ]] \
			then

				if ! zone_run "/bin/df -k $mpt" $zone >/dev/null 2>&1
				then
					print "'$mpt' is not mounted [$fs]\n"
				else
					print \
					"OS thinks '$mpt' is mounted, but no files are visible"
				fi

			fi

			print
		fi

	done

done

exit $EXIT
