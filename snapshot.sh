#!/usr/bin/bash

# User defined variables.
# Subvolume paths to snapshot.
volPaths=("/" "/home")
# Directory where snapshots will be created and deleted.
snapDir="/snapshots"
# Age when snapshot will be deleted.
expireDays=7
# User to be notified when there is a problem.
notifyUser="sudoer"
# Command output and errors will be silenced when set to 0 (/dev/null) and 1 (/dev/stdout) will print to terminal.
redirTarget=0
redirTargets=("/dev/null" "/dev/stdout")

# Report a problem to notifyUser through gnome notifications.
function problem {
	# Show a notification with the first argument as the body.
	sudo -u "$notifyUser" DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$notifyUserId/bus notify-send "Btrfs Snapshot Script" "$1"
	problemOccurred=0
}

# Ensure variables are set properly.
function check {
	[[ -z "$notifyUser" ]] && return
	notifyUserId=`id -u "$notifyUser"` || return
	[[ -d "$snapDir" ]] || { problem "snapDir is not a real directory: '$snapDir'"; return; }
	[[ $expireDays =~ ^[[:digit:]]+$ ]] || { problem "expireDays is not a positive integer: '$expireDays'"; return; }
	for path in "${volPaths[@]}"; do
		btrfs subvolume show $path &> "${redirTargets[$redirTarget]}" || { problem "volPaths contains a false subvolume path: '$path'"; return; }
	done
}

# Delete snapshots older than expireDays.
function delete {
	# Get all snapshot names to inspect their creation time.
	readarray -t snapNames < <(btrfs subvolume list -o "$snapDir" | grep -oP "path ${snapDir:1}/?\K.*$")
	# Calculate seconds between epoch and expireDays ago.
	expireSeconds=`date +%s --date="$expireDays days ago"`
	for snapName in "${snapNames[@]}"; do
		# Get the snapshot's creation time.
		snapCreation=$(btrfs subvolume show "$snapDir"/"$snapName" | grep -oP "Creation time:\s*\K\d.*$")
		# Verify snapCreation is populated.
		[[ -z "$snapCreation" ]] && { problem "snapCreation is empty for snapName: '$snapName'"; return; }
		# Calculate seconds between epoch and snapCreation time.
		snapSeconds=`date +%s --date "$snapCreation"`
		# If the snapshot is expireDays old, delete it.
		if [[ $snapSeconds -lt $expireSeconds ]]; then
			# Report a problem if the snapshot fails to delete.
			btrfs subvolume delete "$snapDir"/"$snapName" &> "${redirTargets[$redirTarget]}" || { problem "Could not delete snapshot: '$snapName'"; return; }
		fi
	done
}

# Create snapshots of all subvolumes in volPaths.
function create {
	snapTime=$(date +"%F_%H-%M-%S")
	for volPath in "${volPaths[@]}"; do
		# Get the subvolume's name and verify that the subvolume exists.
		volName=$(btrfs subvolume show "$volPath" | grep -oP "Name:\s*\K.*$")
		# Verify volName is populated.
		[[ -z "$volName" ]] && { problem "volName is empty for volPath: '$volPath'"; return; }
		# Create snapshot. If snapshot fails, report a problem.
		btrfs subvolume snapshot "$volPath" "$snapDir"/auto_"$volName"_"$snapTime" &> "${redirTargets[$redirTarget]}" || { problem "Could not create snapshot for volName: '$volName'"; return; }
	done
}

# Check for proper input and execute functions if there are no problems.
check
if [[ -z $problemOccurred ]]; then
	delete
	[[ -z $problemOccurred ]] && create
fi
