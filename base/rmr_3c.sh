#!/bin/sh

# Rice My Rig (rmr) posix shell script
# Author:		Monty Vanderlinde
# Last Updated:	01 August 2020

# Future todo:
# Create variables for swap size, root size, dns server, etc
# Separate swap and/or boot partitions?
# Can try raided efi, but may cause problems
#     - https://wiki.archlinux.org/index.php/EFI_system_partition#ESP_on_software_RAID1
#     - partitions need mdadm metadata v1.0 as well as both esp and raid flags
#     - hopefully the efi controller will see the flags and not write data

# Changes keymap hook over for public version
# Remove details from public version


# Start Variables

dev1=""                         # i.e. /dev/sda
dev2=""                         # i.e. /dev/sdb
dev3=""                         # i.e. /dev/sdc
root_encr=""                    # i.e. /dev/mapper/root or /dev/dm-0
home_raid=""                    # i.e. /dev/md/home or /dev/md0
home_encr=""                    # i.e. /dev/mapper/home or /dev/dm-1
mac_spoof=""                    # i.e. 12:34:56:ab:cd:ef
public_ip=""                    # i.e. xxx.xxx.xxx.xxx (where xxx is a number 0<= xxx <=255)
static_ip=""                    # i.e. 192.168.xxx.xxx or 10.0.xxx.xxx (where xxx is a number 0<= xxx <=255)
gateway_ip=""                   # i.e. xxx.xxx.xxx.xxx or 192.168.0.1 (where xxx is a number 0<= xxx <=255)
hostname=""                     # i.e. home-desktop, school-laptop, HAL9000, etc.
username=""                     # i.e. dave, carol, vegeta, etc.
groupname=""                    # i.e. admins, devel, alex, or leave blank to default to the username

# Only ram_mib is used, but ram_gib makes calculations easy
# Can find the memory availible with 'free -m' for mib or 'free -g' for gib
ram_gib=                        # i.e. 8, 16, 32, etc.  Not used, but helps with calculation of ram_mib
ram_mib="$(( ram_gib * 1024 ))" # change 1024 to 512 to reduce swapfile size by half, etc.

# Finding the ethernet network interface
# May not work perfectly
eth_interface="$(dmesg | grep -i 'renamed from eth0' - | awk '{print $5}' - | sed -e 's/://' -)"

# Return variables for block_info()
# Do not need to change these
phys_block_size=0
phys_blocks=0

# End Variables


# Start Functions

# Provide $1 as exit message
error_exit () {
	printf "%s\n" "$1" 1>&2
	exit 1
}

# Provide $1 as "sda", "dm-0", etc.
block_info () {
	phys_block_size="$(cat /sys/block/"$1"/queue/physical_block_size)"
	logic_block_size="$(cat /sys/block/"$1"/queue/logical_block_size)"
	logic_blocks="$(cat /sys/block/"$1"/size)"
	phys_byte_size="$(( logic_block_size * logic_blocks ))"
	phys_blocks="$(( phys_byte_size / phys_block_size ))"
}

# Reads a yes or no response from the user
# Returns 0 if yes and 1 if no
# Provide $1 as a list to eval, and $2 as the prompt
final_check () {
	while [ "true" ]
	do
		# Print prompt
		printf "\n%s\n" "$2"
		printf "Press enter when ready\n"

		stty -echo
		read -r answer || exit 1
		stty echo

		# Print file/list and pipe to less
		eval "$1" | less

		# Query answer
		printf "Please enter your answer (y/n or r to repeat) > "
		read -r answer
		case "$answer" in
			y*|Y*) return 0 ;;
			n*|N*) return 1 ;;
			r*|R*) printf "Repeating last file or list\n" ;;
			*)     printf "Not a valid answer.\nRepeating last file or list\n" ;;
		esac
	done
}

# End Functions


# Greeting and prerequisites warning
printf "%s\n" \
	"Welcome to the Rice My Rig script!" \
	"Firstly, there are couple of prerequisites that this script expects:" \
	"1) This script is being run from a live image or full install of Arch Linux" \
	"2) The computer has been successfully connected to the internet" \
	"3) The computer has enough battery to complete this script" \
	"4) The script currently expects a x86_64 (64-bit) system" \
	"5) All installation drives have been unmounted" \
	"6) Verify that the detected ethernet device (${eth_interface}) is ok" \
	"7) Make sure that wipe.sh script was run and computer was rebooted!"

printf "\nPress enter to start the installation\n"
stty -echo
read -r answer || exit 0
stty echo

printf "Beginning Installation\n"

printf "\nSetting the keyboard layout\n"
loadkeys us || error_exit "Failed to load keys"

printf "\nVerifying system is booted with UEFI\n"
[ ! -e "/sys/firmware/efi/efivars" ] && error_exit "Not booted in EFI mode. Quitting."

printf "\nUpdating the system clock\n"
timedatectl set-ntp true || error_exit "Failed to update system clock"

printf "\nPartitioning the disks\n"

printf "\nPartitioning %s with /efi and / partitions\n" "$dev1"
parted -s -a optimal -- "$dev1" \
	mkpart EFIPART fat32 1MiB 513MiB \
	mkpart ROOT ext4 513MiB 100% \
	set 1 esp on \
	align-check optimal 1 || error_exit "Not properly aligned or other error on $dev1"

printf "\nPartitioning %s with /home in RAID 1 (part 1)\n" "$dev2"
parted -s -a optimal -- "$dev2" \
	mkpart HOME ext4 0% 100% \
	set 1 raid on \
	align-check optimal 1 || error_exit "Not properly aligned or other error on $dev2"

printf "\nPartitioning %s with /home in RAID 1 (part 2)\n" "$dev3"
parted -s -a optimal -- "$dev3" \
	mkpart HOME ext4 0% 100% \
	set 1 raid on \
	align-check optimal 1 || error_exit "Not properly aligned or other error on $dev3"

printf "\nSetting up /home in RAID 1 on %s and %s\n" "${dev2}1" "${dev3}1"
mdadm --create --verbose --homehost="$hostname" --name="${home_raid##*/}" --level=1 --metadata=1.2 --raid-devices=2 "$home_raid" "${dev2}1" "${dev3}1" ||
	error_exit "Failed to create mdadm array on ${dev2}1 and ${dev3}1"

# Find way to run these in parallel
printf "\nWiping the data on all disks\n"
cryptsetup open --type plain -v --cipher serpent-xts-plain64 --key-size 512 --key-file /dev/urandom "${dev1}1" to_wipe_1
cryptsetup open --type plain -v --cipher serpent-xts-plain64 --key-size 512 --key-file /dev/urandom "${dev1}2" to_wipe_2
cryptsetup open --type plain -v --cipher serpent-xts-plain64 --key-size 512 --key-file /dev/urandom "$home_raid" to_wipe_3
block_info "dm-0"
printf "\nWiping %s\n" "${dev1}1"
dd if=/dev/zero of=/dev/mapper/to_wipe_1 bs="$phys_block_size" count="$phys_blocks" status=progress || error_exit "Failed to wipe data on ${dev1}1"
block_info "dm-1"
printf "\nWiping %s\n" "${dev1}2"
dd if=/dev/zero of=/dev/mapper/to_wipe_2 bs="$phys_block_size" count="$phys_blocks" status=progress || error_exit "Failed to wipe data on ${dev1}2"
block_info "dm-2"
printf "\nWiping %s\n" "$home_encr"
dd if=/dev/zero of=/dev/mapper/to_wipe_3 bs="$phys_block_size" count="$phys_blocks" status=progress || error_exit "Failed to wipe data on $home_encr"
cryptsetup close to_wipe_1
cryptsetup close to_wipe_2
cryptsetup close to_wipe_3

printf "\nSetting up LUKS1 encryption\n"

while [ "true" ]
do
	printf "\nSetting up root encryption; enter password below\n"
	cryptsetup -v --type luks1 --cipher serpent-xts-plain64 --key-size 512 --hash sha512 --verify-passphrase --iter-time 5000 luksFormat "${dev1}2" &&
		break
	printf "Something seems to have gone wrong\n"
	printf "Would you like to try entering the password again (y/n)? > "
	read -r answer
	case "$answer" in
		y*|Y*) ;; # Loop again
		*) error_exit "Failed to create luks container on ${dev1}2" ;;
	esac
done
while [ "true" ]
do
	printf "\nSetting up home encryption; enter password below\n"
	cryptsetup -v --type luks1 --cipher serpent-xts-plain64 --key-size 512 --hash sha512 --verify-passphrase --iter-time 5000 luksFormat "$home_raid" &&
		break
	printf "Something seems to have gone wrong\n"
	printf "Would you like to try entering the password again (y/n)? > "
	read -r answer
	case "$answer" in
		y*|Y*) ;; # Loop again
		*) error_exit "Failed to create luks container on ${dev1}2" ;;
	esac
done

printf "\nOpening the newly created LUKS volumes\n"
printf "\nOpening root on %s; enter password below\n" "$root_encr"
cryptsetup open --type luks "${dev1}2" "${root_encr##*/}" || error_exit "Failed to open $root_encr"
printf "\nOpening home on %s; enter password below\n" "$home_encr"
cryptsetup open --type luks "$home_raid" "${home_encr##*/}" || error_exit "Failed to open $home_encr"

printf "\nFormatting the partitions\n"
printf "\nFormatting %s with fat32 and naming BOOT\n" "${dev1}1"
mkfs.vfat -F 32 -n BOOT "${dev1}1" || error_exit "Failed mkfs.vfat on ${dev1}1"
printf "\nFormatting %s with ext4, naming ROOT, and leaving 2 percent reserved blocks\n" "$root_enrc"
mkfs.ext4 -m 2 -L ROOT "$root_encr" || error_exit "Failed mkfs.ext4 on $root_encr"
printf "\nFormatting %s with ext4, naming HOME, and leaving 0 percent reserved blocks\n" "$home_enrc"
mkfs.ext4 -m 0 -L HOME "$home_encr" || error_exit "Failed mkfs.ext4 on $home_encr"

printf "\nMounting the file systems\n"
mount "$root_encr" /mnt || error_exit "Failed to mount $root_encr"
mkdir -p /mnt/efi /mnt/home || error_exit "Mkdir failed for either efi or home directory"
mount "${dev1}1" /mnt/efi || error_exit "Failed to mount ${dev1}1"
mount "$home_encr" /mnt/home || error_exit "Failed to mount $home_encr"

printf "\nSetting up the %s MiB swapfile on /swapfile\n" "$ram_mib"
dd if=/dev/zero of=/mnt/swapfile bs=1MiB count="$ram_mib" status=progress || error_exit "Failed to make swapfile"
chmod 600 /mnt/swapfile || error_exit "Failed to set swapfile permissions"
mkswap /mnt/swapfile || error_exit "Mkswap failed on swapfile"
swapon /mnt/swapfile || error_exit "Failed to turn swap on"

printf "\nEditing the mirrorlist with reflector for the United States and Canada\n"
reflector --country 'United States' --country 'Canada' --latest 5 --age 24 --sort rate --save /etc/pacman.d/mirrorlist ||
	error_exit "Failed to update mirrors with reflector"

printf "\nInstalling essential packages with pacstrap\n"
pacstrap /mnt base base-devel linux linux-firmware neovim man-db man-pages git shellcheck mdadm cryptsetup reflector intel-ucode dash parted pacman-contrib grub efibootmgr ||
	error_exit "Failed to download packages with pacstrap"

printf "\nGenerating /etc/fstab with genfstab\n"
genfstab -U /mnt >> /mnt/etc/fstab || error_exit "Failed to generate fstab"

printf "\nRemoving and blacklisting that annoying error beep!\n"
arch-chroot /mnt rmmod pcspkr || error_exit "Failed rmmod for pcspkr"
printf "blacklist pcspkr\n" > /mnt/etc/modprobe.d/nobeep.conf || error_exit "Failed to blacklist pcspkr"

printf "\nLoading the sg module by default at boot time\n"
printf "%s\n" "# Load sg at boot time" "sg" > /etc/modules-load.d/sg.conf

printf "\nLoading the us keyboard and switching the escape and caps-lock keys around (for vi)\n"
arch-chroot /mnt loadkeys us || error_exit "Failed to loadkeys for us"
printf "keycode 1 = Caps_Lock\nkeycode 58 = Escape\n" > /mnt/usr/share/kbd/keymaps/personal.map || error_exit "Failed to define personal keymap"
arch-chroot /mnt loadkeys /usr/share/kbd/keymaps/personal.map || error_exit "Failed to loadkeys for personal keymap"
printf "KEYMAP=us\nKEYMAP=/usr/share/kbd/keymaps/personal.map\n" > /mnt/etc/vconsole.conf || error_exit "Failed to set vconsole keymaps"

printf "\nSetting the timezone to American/Chicago\n"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime || error_exit "Failed to link zoneinfo to localtime"

printf "\nSetting the clock\n"
arch-chroot /mnt timedatectl set-ntp true || error_exit "Failed to update clock"
arch-chroot /mnt timedatectl set-local-rtc 0 || error_exit "Failed to setup localtime clock"
arch-chroot /mnt hwclock --systohc || error_exit "Failed to update hardware clock"

printf "\nGenerating the locale\n"
cp /mnt/etc/locale.gen /mnt/etc/locale.gen.bak || error_exit "Failed to backup locale.gen"
sed -e 's/#en_US\.UTF-8 UTF-8/en_US\.UTF-8 UTF-8/' /mnt/etc/locale.gen.bak > /mnt/etc/locale.gen || error_exit "Failed to generate locale.gen file"
arch-chroot /mnt locale-gen || error_exit "Failed to update locale-gen"

printf "\nSetting the language to en_US.UTF-8\n"
printf "LANG=en_US.UTF-8\n" > /mnt/etc/locale.conf || error_exit "Failed to define locale.conf"

printf "\nSetting the hostname to $hostname\n"
printf "%s\n" "$hostname" > /mnt/etc/hostname || error_exit "Failed to set hostname"

printf "\nUpdating mandb\n"
arch-chroot /mnt mandb || error_exit "Failed to update mandb"

printf "\nSetting up hosts file and defining static ip address\n"
printf "%-16s%s\n" \
	"::1" "localhost" \
	"127.0.0.1" "localhost" \
	"$static_ip" "homelocal $hostname" \
	"$public_ip" "home" > /mnt/etc/hosts || error_exit "Failed to define hosts"

printf "\nSetting up crypttab to open home containter\n"
cp /mnt/etc/crypttab /mnt/etc/crypttab.bak || error_exit "Failed to backup crypttab"
printf "home\tUUID=%s\tnone\tluks,timeout=180\n" "$(lsblk -lp -o NAME,UUID | grep "$(readlink -f "$home_raid")" | awk '{print $2}')" >> /mnt/etc/crypttab ||
	error_exit "Failed to define crypttab"

printf "\nSetting up hooks and updating initcpio\n"
cp /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.bak || error_exit "Failed to backup mkinitcpio"
sed -e 's/^HOOKS=.*/HOOKS=\(base udev autodetect keyboard modconf block mdadm_udev encrypt filesystems resume fsck\)/g' /mnt/etc/mkinitcpio.conf.bak > /mnt/etc/mkinitcpio.conf ||
	error_exit "Failed to set mkinitcpio hooks"
arch-chroot /mnt mkinitcpio -P || error_exit "Failed to update mkinitcpio"

printf "\nConfiguring grub\n"
cp /mnt/etc/default/grub /mnt/etc/default/grub.bak || error_exit "Failed to backup grub configuration"
printf "%s\n" \
	"GRUB_DEFAULT=saved" \
	"GRUB_TIMEOUT=5" \
	"GRUB_SAVEDEFAULT=true" \
	"GRUB_DISTRIBUTOR=\"Arch\"" \
	"GRUB_CMDLINE_LINUX=\"cryptdevice=${dev1}2:${root_encr##*/} root=$root_encr resume=$root_encr resume_offset=$(filefrag -v /mnt/swapfile | sed -n '4p' - | awk '{print $4}' - | sed -e 's/\.\.//' -)\"" \
	"GRUB_PRELOAD_MODULES=\"part_gpt part_msdos\"" \
	"GRUB_ENABLE_CRYPTODISK=y" \
	"GRUB_TIMEOUT_STYLE=menu" \
	"GRUB_TERMINAL=console" \
	"GRUB_GFXMODE=auto" \
	"GRUB_GFXPAYLOAD_LINUX=keep" \
	"GRUB_DISABLE_RECOVERY=true" > /mnt/etc/default/grub || error_exit "Failed to define grub configuration"
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=ArchLinux || error_exit "Failed to install grub"
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || error_exit "Failed grub-mkconfig"

printf "\nWriting /etc/mdadm.conf\n"
mdadm --detail --scan >> /mnt/etc/mdadm.conf || error_exit "Failed to define madam.conf"


printf "\nWriting pacman hook to run reflector on update\n"
mkdir -p /mnt/etc/pacman.d/hooks || error_exit "Mkdir failed for /etc/pacman.d/hooks"
printf "%s\n" \
	"[Trigger]" \
	"Operation = Upgrade" \
	"Type = Package" \
	"Target = pacman-mirrorlist" \
	"" \
	"[Action]" \
	"Description = Updating pacman-mirrorlist with reflector and removing pacnew" \
	"When = PostTransaction" \
	"Depends = reflector" \
	"Exec = /bin/sh -c \"reflector --country 'United States' --country 'Canada' --latest 5 --age 24 --sort rate --save /etc/pacman.d/mirrorlist\"" > /mnt/etc/pacman.d/hooks/mirrorupgrade.hook ||
		error_exit "Failed to define pacman reflector hook"

printf "\nAdding new user %s to the new group %s and also the wheel group\n" "$username" "${groupname:-$username}"
arch-chroot /mnt groupadd "${groupname:-$username}" || error_exit "Failed to add group ${groupname:-$username}"
arch-chroot /mnt useradd -m -g "${groupname:-$username}" -G wheel -s /bin/bash "$username" || error_exit "Failed to add user $username"
arch-chroot /mnt passwd "$username" || error_exit "Failed to update ${username}'s password"

printf "\nUpdating the sudoers file to include the new user\n"
cp /mnt/etc/sudoers /mnt/etc/sudoers.bak || error_exit "Failed to backup sudoers file"
sed -e 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /mnt/etc/sudoers.bak > /mnt/etc/sudoers || error_exit "Failed to define sudoers file"

printf "\nLinking dash to sh\n"
arch-chroot /mnt ln -sf /bin/dash /bin/sh || error_exit "Failed to link dash to sh"

printf "\nSetting up networking, including the dns server and network.service for systemd\n"
printf "nameserver %s\n" "$gateway_ip" >> /mnt/etc/resolv.conf || error_exit "Failed to define nameserver"
printf "%s\n" \
	"[Unit]" \
	"Description = Turn on internet access" \
	"" \
	"[Service]" \
	"Type = oneshot" \
	"ExecStart = /usr/bin/sh -c 'ip addr add $static_ip/24 broadcast + dev $eth_interface'" \
	"ExecStart = /usr/bin/sh -c 'ip link set $eth_interface address $mac_spoof'" \
	"ExecStart = /usr/bin/sh -c 'ip link set $eth_interface up'" \
	"ExecStart = /usr/bin/sh -c 'ip route add default via $gateway_ip dev $eth_interface'" \
	"ExecStop = /usr/bin/sh -c 'ip route del default via $gateway_ip dev $eth_interface'" \
	"ExecStop = /usr/bin/sh -c 'ip link set $eth_interface down'" \
	"ExecStop = /usr/bin/sh -c 'ip addr del $static_ip/24 broadcast + dev $eth_interface'" \
	"RemainAfterExit = yes" \
	"" \
	"[Install]" \
	"WantedBy = multi-user.target" > /mnt/etc/systemd/system/network.service || error_exit "Failed to define systemd network service"
arch-chroot /mnt systemctl enable network.service || error_exit "Failed to enable systemd network service"

printf "\nSetting secure permissions for the new user's home directory\n"
chmod 700 /home/"$username"

printf "\nFinal verification of file integrity\n"
printf "%s\n" "Read the question and press enter when you are ready to see the file or list" \
	"Press q to exit out of the file list, and then answer the question with \"yes\", \"no\", or \"repeat\" (y/Y/yes/Yes,YES all work)" \
	"Press enter when you are ready to begin (there are 20 items to check)"

stty -echo
read -r answer || exit 1
stty echo

files_to_fix=""

final_check "lsblk -o NAME,FSTYPE,LABEL,FSAVAIL,FSUSE%,MOUNTPOINT $dev1 $dev2 $dev3" "Does the final disk layout look alright?" ||
	files_to_fix="$files_to_fix disk-layout"
final_check "swapon" "Does the swapfile look alright?" ||
	files_to_fix="$files_to_fix /mnt/swapfile"
final_check "cat /mnt/etc/pacman.d/mirrorlist" "Does the mirrorlist file look alright?" ||
	files_to_fix="$files_to_fix /mnt/etc/pacman.d/mirrorlist"
final_check "cat /mnt/etc/fstab" "Does the fstab file look alright?" ||
	files_to_fix="$files_to_fix /mnt/etc/fstab"
final_check "cat /mnt/etc/modprobe.d/nobeep.conf" "Does the nobeep.conf file look alright?" ||
	files_to_fix="$files_to_fix /mnt/etc/modprobe.d/nobeep.conf"
final_check "cat /mnt/usr/share/kbd/keymaps/personal.map" "Does the personal.map file look alright?" ||
	files_to_fix="$files_to_fix /mnt/usr/share/kbd/keymaps/personal.map"
final_check "cat /mnt/etc/vconsole.conf" "Does the vconsole.conf file look alright?" ||
	files_to_fix="$files_to_fix /mnt/etc/vconsole.conf"
final_check "cat /mnt/etc/locale.gen" "Does the locale.gen file look alright?" &&
	rm /mnt/etc/locale.gen.bak ||
	files_to_fix="$files_to_fix /mnt/etc/locale.gen"
final_check "cat /mnt/etc/locale.conf" "Does the locale.conf file look alright?" ||
	files_to_fix="$files_to_fix /mnt/etc/locale.conf"
final_check "cat /mnt/etc/hostname" "Does the hostname file look alright?" ||
	files_to_fix="$files_to_fix /mnt/etc/hostname"
final_check "cat /mnt/etc/hosts" "Does the hosts file look alright?" ||
	files_to_fix="$files_to_fix /mnt/etc/hosts"
final_check "cat /mnt/etc/crypttab" "Does the crypttab file look alright?" &&
	rm /mnt/etc/crypttab.bak ||
	files_to_fix="$files_to_fix /mnt/etc/crypttab"
final_check "cat /mnt/etc/mkinitcpio.conf" "Does the mkinitcpio.conf file look alright?" &&
	rm /mnt/etc/mkinitcpio.conf.bak ||
	files_to_fix="$files_to_fix /mnt/etc/mkinitcpio.conf"
final_check "cat /mnt/etc/default/grub" "Does the grub file look alright?" &&
	rm /mnt/etc/default/grub.bak ||
	files_to_fix="$files_to_fix /mnt/etc/default/grub"
final_check "cat /mnt/etc/mdadm.conf" "Does the mdadm.conf file look alright?" ||
	files_to_fix="$files_to_fix /mnt/etc/mdadm.conf"
final_check "cat /mnt/etc/pacman.d/hooks/mirrorupgrade.hook" "Does the mirrorupgrade.hook file look alright?" ||
	files_to_fix="$files_to_fix /mnt/etc/pacman.d/hooks/mirrorupgrade.hook"
final_check "arch-chroot /mnt groups $username" "Is the new $username user spelled correctly and in the correct groups?" ||
	files_to_fix="$files_to_fix ${username}-user"
final_check "cat /mnt/etc/sudoers" "Does the sudoers file look alright?" &&
	rm /mnt/etc/sudoers.bak ||
	files_to_fix="$files_to_fix /mnt/etc/sudoers"
final_check "cat /mnt/etc/resolv.conf" "Does the reslov.conf file look alright?" ||
	files_to_fix="$files_to_fix /mnt/etc/resolv.conf"
final_check "cat /mnt/etc/systemd/system/network.service" "Does the network.service file look alright?" ||
	files_to_fix="$files_to_fix /mnt/etc/systemd/system/network.service"

# Check if $files_to_fix is empty
[ "$files_to_fix" ] &&
	printf "\nInstallation completed, but some files still need to be fixed before rebooting:\n%s\n" "$files_to_fix" ||
	printf "\nInstallation Successfully Completed!\nPlease reboot into your new system.\n"

# Done
