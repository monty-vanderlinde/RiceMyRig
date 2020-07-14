#!/bin/sh

# Rice My Rig (rmr) posix shell script
# Author:		Monty Vanderlinde
# Last Updated:	06 July 2020

# Future todo:
# Create variables for swap size, root size, static ip, gateway, dns server, etc
# Separate swap and/or boot partitions?
# Setup home directory and useradd to work with multiple distros
# Can try raided efi, but need mdadm metadata v1.0 as well as both esp and raid flags

dev1="/dev/sda"
dev2="/dev/sdb"
dev3="/dev/sdc"
root_encr="/dev/mapper/root"
home_raid="/dev/md/home"
home_encr="/dev/mapper/home"
public_ip=""
static_ip="192.168.0.253"
gateway_ip="192.168.0.1"
hostname="jarvis"

# Set default username and groupname
# Leaving groupname blank will default to the same as the username
username="monty"
groupname=""

# Only ram_mib is used, but ram_gib make calculations easy
# Can find the memory availible with 'free -m' for mib or 'free -g' for gib
# Modifiy 1024 if you require a larger or smaller percentage of swap compared to ram
ram_gib=16
ram_mib="$(( ram_gib * 1024 ))"

# may not work perfectly
eth_interface="$(dmesg | grep -i 'renamed from eth0' - | awk '{print $5}' - | sed -e 's/://' -)"

error_exit () {
	printf "%s\n" "$1" 1>&2
	exit 1
}


# Greeting and prerequisites warning
printf "%s\n" \
	"Welcome to the Rice My Rig script!" \
	"Firstly, there are couple of prerequisites that this script expects:" \
	"1) This script is being run from a live image or full install of Arch Linux" \
	"2) The computer has been successfully connected to the internet" \
	"3) The computer has enough battery to complete this script" \
	"4) The script currently expects a x86_64 (64-bit) system" \
	"5) Verify that the detected ethernet device (${eth_interface}) is ok"

printf "Press enter to start installation\n"
stty -echo
read answer || exit 0
stty echo

printf "Beginning Installation\n"

# Set the keyboard layout
loadkeys us || error_exit "Failed to load keys"

# Verify booted with UEFI
[ ! -e "/sys/firmware/efi/efivars" ] && error_exit "Not booted in EFI mode. Quitting."

# Update the system clock
timedatectl set-ntp true || error_exit "Failed to update system clock"

# Partition the disk

# /efi /root
# separate swapfile
parted -s -a optimal -- "$dev1" \
	mklabel gpt \
	mkpart EFIPART fat32 1MiB 513MiB \
	mkpart ROOT ext4 513MiB 100% \
	set 1 esp on \
	align-check optimal 1 || error_exit "Not properly aligned or other error on $dev1"

# /home
parted -s -a optimal -- "$dev2" \
	mklabel gpt \
	mkpart HOME ext4 0% 100% \
	set 1 raid on \
	align-check optimal 1 || error_exit "Not properly aligned or other error on $dev2"

parted -s -a optimal -- "$dev3" \
	mklabel gpt \
	mkpart HOME ext4 0% 100% \
	set 1 raid on \
	align-check optimal 1 || error_exit "Not properly aligned or other error on $dev3"

# Setup RAID 1
mdadm --create --verbose --name="${home_raid##*/}" --level=1 --metadata=1.2 --raid-devices=2 "$home_raid" "${dev2}1" "${dev3}1" ||
	error_exit "Failed to create mdadm array on ${dev2}1 and ${dev3}1"

# Setup LUKS1
cryptsetup -v --type luks1 --cipher serpent-xts-plain64 --key-size 512 --hash sha512 --verify-passphrase --iter-time 5000 luksFormat "${dev1}2" ||
	error_exit "Failed to create luks container on ${dev1}2"
cryptsetup -v --type luks1 --cipher serpent-xts-plain64 --key-size 512 --hash sha512 --verify-passphrase --iter-time 5000 luksFormat "$home_raid" ||
	error_exit "Failed to create luks container on $home_raid"

# Mount the new LUKS volumes
cryptsetup open --type luks "${dev1}2" "${root_encr##*/}" || error_exit "Failed to open $root_encr"
cryptsetup open --type luks "$home_raid" "${home_encr##*/}" || error_exit "Failed to open $home_encr"

# Format the partitions
mkfs.vfat -F 32 -n BOOT "${dev1}1" || error_exit "Failed mkfs.vfat on ${dev1}1"
mkfs.ext4 -L ROOT "$root_encr" || error_exit "Failed mkfs.ext4 on $root_encr"
mkfs.ext4 -m 0 -L HOME "$home_encr" || error_exit "Failed mkfs.ext4 on $home_encr"

# Mount the file systems, except for /efi
mount "$root_encr" /mnt
mkdir /mnt/efi /mnt/home
mount "${dev1}1" /mnt/efi
mount "$home_encr" /mnt/home

# Setup swap
dd if=/dev/zero of=/mnt/swapfile bs=1MiB count="$ram_mib" status=progress
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

# Edit the mirrorlist
reflector --country 'United States' --country 'Canada' --latest 5 --age 24 --sort rate --save /etc/pacman.d/mirrorlist

# Install essential packages - yes to all prompts
pacstrap /mnt base linux linux-firmware neovim man-db man-pages git mdadm cryptsetup reflector sudo intel-ucode dash parted pacman-contrib grub efibootmgr

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Remove that annoying beeping!
arch-chroot /mnt rmmod pcspkr
printf "blacklist pcspkr" > /mnt/etc/modprobe.d/nobeep.conf

# Load us keyboard and swap escape and caps-lock keys
arch-chroot /mnt loadkeys us
printf "keycode 1 = Caps_Lock\nkeycode 58 = Escape" > /mnt/usr/share/kbd/keymaps/personal.map
arch-chroot /mnt loadkeys /usr/share/kbd/keymaps/personal.map
printf "KEYMAP=us\nKEYMAP=/usr/share/kbd/keymaps/personal.map" > /mnt/etc/vconsole.conf

# Set the timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime

# Set the clock
arch-chroot /mnt timedatectl set-ntp true
arch-chroot /mnt timedatectl set-local-rtc 0
arch-chroot /mnt hwclock --systohc

# Generate the locale
mv /mnt/etc/locale.gen /mnt/etc/locale.gen.bak
sed -e 's/#en_US\.UTF-8 UTF-8/en_US\.UTF-8 UTF-8/' /mnt/etc/locale.gen.bak > /mnt/etc/locale.gen
arch-chroot /mnt locale-gen

# Set the language
printf "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

# Set the hostname
printf "$hostname" > /mnt/etc/hostname

# Update mandb
arch-chroot /mnt mandb

# Setup hosts file and define static ip address
printf "%-16s%s\n" \
	"::1" "localhost" \
	"127.0.0.1" "localhost" \
	"$static_ip" "homelocal $hostname" \
	"$public_ip" "home" > /mnt/etc/hosts

# Setup crypttab to open home containter
cp /etc/crypttab /etc/crypttab.bak
printf "home\tUUID=$(lsblk -lp -o NAME,UUID | grep "$home_raid" | awk '{print $2}')\tnone\tluks,timeout=60" >> /mnt/etc/crypttab

# Setup hooks for mkinitcpio
mv /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.bak
sed -e 's/^HOOKS=.*/HOOKS=\(base udev autodetect keyboard keymap modconf block mdadm_udev encrypt filesystems resume fsck\)/g' /mnt/etc/mkinitcpio.conf.bak > /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

# Configure grub
mv /mnt/etc/default/grub /mnt/etc/default/grub.bak
printf "%s\n" \
	"GRUB_DEFAULT=saved" \
	"GRUB_TIMEOUT=5" \
	"GRUB_SAVEDEFAULT=true" \
	"GRUB_DISTRIBUTOR=\"Arch\"" \
	"GRUB_CMDLINE_LINUX=\"cryptdevice=${dev1}2:${root_encr##*/} root=$root_encr resume=$root_encr resume_offset=$(filefrag -v /swapfile | sed -n '4p' - | awk '{print $4}' - | sed -e 's/\.\.//' -)\"" \
	"GRUB_PRELOAD_MODULES=\"part_gpt part_msdos\"" \
	"GRUB_ENABLE_CRYPTODISK=y"
	"GRUB_TIMEOUT_STYLE=menu"
	"GRUB_TERMINAL=console"
	"GRUB_GFXMODE=auto"
	"GRUB_GFXPAYLOAD_LINUX=keep"
	"GRUB_DISABLE_RECOVERY=true" > /mnt/etc/default/grub
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=ArchLinux
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

mdadm --detail --scan >> /mnt/etc/mdadm.conf

mkdir /mnt/etc/pacman.d/hooks
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
	"Exec = /bin/sh -c \"reflector --country 'United States' --country 'Canada' --latest 5 --age 24 --sort rate --save /etc/pacman.d/mirrorlist\"" > /etc/pacman.d/hooks/mirrorupgrade.hook

arch-chroot /mnt groupadd "${groupname:-$username}"
arch-chroot /mnt useradd -m -g "${groupname:-$username}" -G wheel -s /bin/bash "$username"
arch-chroot /mnt passwd "$username"

mv /mnt/etc/sudoers /mnt/etc/sudoers.bak
sed -e 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /mnt/etc/sudoers.bak > /mnt/etc/sudoers

arch-chroot /mnt ln -sf /bin/dash /bin/sh

printf "nameserver $gateway_ip" >> /mnt/etc/resolv.conf
printf "%s\n" \
	"[Unit]" \
	"Description = Turn on internet access" \
	"" \
	"[Service]" \
	"Type = oneshot" \
	"ExecStart = /usr/bin/sh -c 'ip addr add $static_ip/24 broadcast + dev $eth_interface'" \
	"ExecStart = /usr/bin/sh -c 'ip link set $eth_interface up'" \
	"ExecStart = /usr/bin/sh -c 'ip route add default via $gateway_ip dev $eth_interface'" \
	"ExecStop = /usr/bin/sh -c 'ip addr del $static_ip/24 broadcast + dev $eth_interface'" \
	"ExecStop = /usr/bin/sh -c 'ip link set $eth_interface down'" \
	"ExecStop = /usr/bin/sh -c 'ip route del default via $gateway_ip dev $eth_interface'" \
	"RemainAfterExit = yes" \
	"" \
	"[Install]" \
	"WantedBy = multi-user.target" > /mnt/etc/systemd/system/network.service
arch-chroot /mnt systemctl enable network.service

# add alias for sudo="Sudo -E"
# add alias for bc="bc -l"

# DO NOT SET ROOT PASSWORD


#NON BASE INSTALL START

#pacman -S zathura zathura-pdf-mupdf ffmpeg youtube-dl mpv ranger w3m xorg-server mediainfo

# Git clone important rc files and move to correct locations

# Git clone and compile suckless suite

# Personalization

# exa?

# libaom-av1 ?

#NON BASE INSTALL START


# Done
