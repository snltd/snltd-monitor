#!/bin/ksh

#=============================================================================
#
# check_data_send.sh
# ==================
#
# This isn't really a check at all. It pushes check data (exit codes and
# diagnostics) to the "dashboard" zone, which is able to present that
# information as a web page.  It's named and located as a check so it slots
# into the existing way of running things.
#
# Requires (Open)SSH binary which understands ConnectTimeout. Requires
# monitor user's id_dsa.pub is in the remote user's authorized_keys.
#
# R Fisher 03/2009
#
# v1.0 Initial Release
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

SSH="${DIR_BIN}/ssh"

DASH_DIR="/var/snltd/monitor/$HOSTNAME"
	# Remote directory in which to write files

EXIT=0

#-----------------------------------------------------------------------------
# FUNCTIONS

function copy_data
{
	# Copy all exit statuses and any non-empty diagnostic errors to the
	# remote user at the remote host. Set a two second connection timeout.
	# It puts everything in one directory, but that's okay. Unlike SSH, we
	# can use any old scp, thanks to the -S option.

	scp \
		-rp \
		-q \
		-S $SSH \
		-o "BatchMode=yes" \
		-o "StrictHostKeyChecking=no" \
		-o "ConnectTimeout=2" \
		$DIR_EXIT $(find $DIR_DIAG -type f -a -size +0) \
	${DASH_USER}:$DASH_DIR >/dev/null 2>&1
}

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

[[ -z $DASH_CONNECTOR ]] && exit 3

if [[ -x $SSH ]]
then

	# Try to copy the data to the remote server

	if ! copy_data
	then

		# If it's failed, it could be because there's no target directory.
		# Try to make that, and if we succeed, try again

		if $SSH \
				-q \
				-o "BatchMode=yes" \
				-o "StrictHostKeyChecking=no" \
				-o "ConnectTimeout=2" \
			$DASH_USER "mkdir -p $DASH_DIR" >/dev/null
		then

			if ! copy_data
			then

				[[ -n $RUN_DIAG ]] && print \
					"Unable to copy files to ${DASH_USER}:$DASH_DIR. Exit $?"

				EXIT=2
			fi

		else

			[[ -n $RUN_DIAG ]] && print \
				"Unable to create target directory as ${DASH_USER}. Exit $?"

			EXIT=2
		fi
	fi

else
	EXIT=2
	[[ -n $RUN_DIAG ]] && print "No SSH binary [${SSH}]"
fi

exit $EXIT
