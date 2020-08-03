#!/bin/sh

dev1="" # i.e. /dev/sda

# Provide $1 as exit message
error_exit () {
	printf "%s\n" "$1" 1>&2
	exit 1
}

[ "$dev1" ] ||
	error_exit "The device variable has not been set in wipe_1.sh"

wipe_full_disk="false"
wipe_mib=1024

[ ! "$wipe_full_disk" = "true" ] && [ ! "$wipe_full_disk" = "false" ] &&
	printf "Error: wipe_full_disk variable is neither \"true\" nor \"false\"" &&
	exit 1

[ "$wipe_full_disk" = "true" ] &&
	printf "%s\n" \
	"This script is currently configured to wipe the entirety of ${dev1}" \
	"This can be changed to the beginnings of the disks by setting the wipe_full_disk variable to \"false\" and wipe_mib to a number instead" ||
	printf "%s\n" \
	"This script is currently configured to wipe the first ${wipe_mib} MiB of ${dev1}" \
	"This can be changed to the full disks by setting the wipe_full_disk variable to \"true\" instead" ||

printf "\nPress enter to begin the wiping process, or ctl-D to quit\n"
stty -echo
read -r answer || exit 0
stty echo

printf "\nInitializing the disks\n"

[ "$wipe_full_disk" = "true" ] &&
	printf "\nWriting zeros over the entirety of the disk\n" &&
	dd if=/dev/zero of="$dev1" status=progress

[ "$wipe_full_disk" = "false" ] &&
	printf "\nWriting 1GiB of zeros to the start of the disk\n" &&
	dd if=/dev/zero of="$dev1" bs=1MiB count="$wipe_mib" status=progress

printf "\nInitializing gpt table on %s\n" "$dev1"
parted -s -a optimal -- "$dev1" mklabel gpt

printf "\nWipe completed. Please restart your machine before running rmr script.\n"
