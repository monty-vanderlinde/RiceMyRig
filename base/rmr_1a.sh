#!/bin/sh

# Rice My Rig (rmr) posix shell script
# Author:		Monty Vanderlinde
# Last Updated:	06 July 2020

# Future todo:
# Create variables for swap size, root size, static ip, gateway, dns server, etc
# Separate swap and/or boot partitions?
# Setup home directory and useradd to work with multiple distros
# Can try raided efi, but need mdadm metadata v1.0 as well as both esp and raid flags


# Greeting and prerequisites warning
printf "%s\n" \
	"Welcome to the Rice My Rig script!" \
	"Firstly, there are couple of prerequisites that this script expects:" \
	"1) This script is being run from a live image or full install of Arch Linux" \
	"2) The computer has been successfully connected to the internet" \
	"3) The computer has enough battery to complete this script" \
	"4) All encryption/raid/lvm has already been set up" \
	"5) All drives should already at least have a partition table (parted -s /device/path mklabel \"msdos\")(use \"gpt\" if drives are over 2 TiB)" \
	"6) LUKS encrypted drives should only use LUKS1 headers (cryptsetup --type luks1 luksFormat /device/path)" \
	"7) The script currently only works on x86_64 (64-bit) systems"

printf "Press enter to start installation\n"
stty -echo
read answer
stty echo

printf "Beginning Installation\n"

# Set the keyboard layout
loadkeys us

# Verify booted with UEFI
[ ! -e "/sys/firmware/efi/efivars" ] &&
	printf "Not booted in EFI mode. Quitting\n" && exit 1

# Update the system clock
timedatectl set-ntp true

# Partition the disk

# /efi /root
# separate swapfile
parted -s -a optimal -- /dev/sda \
	mklabel gpt \
	mkpart EFIPART fat32 1MiB 513MiB \
	mkpart ROOT ext4 513MiB 37377MiB \
	set 1 esp on \
	align-check optimal 1 || printf "Not properly aligned\n" exit 1

# /home
#parted -s -a optimal -- /dev/sdb \
#	mklabel gpt \
#	mkpart HOME ext4 0% 100% \
#	set 1 raid on \
#	align-check optimal 1 || printf "Not properly aligned\n" exit 1
#
#parted -s -a optimal -- /dev/sdc \
#	mklabel gpt \
#	mkpart HOME ext4 0% 100% \
#	set 1 raid on \
#	align-check optimal 1 || printf "Not properly aligned\n" exit 1

# Setup RAID 1
#mdadm --create --verbose --name="home" --level=1 --metadata=1.2 --raid-devices=2 /dev/md0 /dev/sdb1 /dev/sdc1

# Setup LUKS1
cryptsetup -v --type luks1 --cipher serpent-xts-plain64 --key-size 512 --hash sha512 --verify-passphrase --iter-time 5000 luksFormat /dev/sda2
#cryptsetup -v --type luks1 --cipher serpent-xts-plain64 --key-size 512 --hash sha512 --verify-passphrase --iter-time 5000 luksFormat /dev/md0

# Mount the new LUKS volumes
cryptsetup open --type luks /dev/sda2 root
#cryptsetup open --type luks /dev/md0 home

# Format the partitions
mkfs.vfat -F 32 -n BOOT /dev/sda1
mkfs.ext4 -L ROOT /dev/mapper/root
#mkfs.ext4 -m 0 -L HOME /dev/mapper/home

# Mount the file systems
mount /dev/mapper/root /mnt
mkdir /mnt/efi #/mnt/home
mount /dev/sda1 /mnt/efi
#mount /dev/mapper/home /mnt/home

# Setup swap
dd if=/dev/zero of=/mnt/swapfile bs=1MiB count=16384 status=progress
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

# Edit the mirrorlist
reflector --country 'United States' --country 'Canada' --latest 5 --age 24 --sort rate --save /etc/pacman.d/mirrorlist

# Install essential packages - yes to all prompts
pacstrap /mnt base linux linux-firmware neovim man-db man-pages git mdadm cryptsetup reflector sudo intel-ucode dash parted pacman-contrib

# Generate the fstab
genfstab -U /mnt >> /mnt/etc/fstab

# https://askubuntu.com/questions/551195/scripting-chroot-how-to
# Test this out first
cat << EOF | arch-chroot /mnt -

rmmod pcspkr
printf "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

loadkeys us
printf "keycode 1 = Caps_Lock\nkeycode 58 = Escape" > /usr/share/kbd/keymaps/personal.map
loadkeys /usr/share/kbd/keymaps/personal.map
printf "KEYMAP=us\nKEYMAP=/usr/share/kbd/keymaps/personal.map" > /etc/vconsole.conf

ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime

timedatectl set-ntp true
timedatectl set-local-rtc 0
hwclock --systohc

cp /etc/locale.gen /etc/locale.gen.bak
sed -e 's/#en_US\.UTF-8 UTF-8/en_US\.UTF-8 UTF-8/' /etc/locale.gen.bak > /etc/locale.gen
locale-gen

printf "LANG=en_US.UTF-8" > /etc/locale.conf

printf "jarvis" > /etc/hostname

mandb

printf "%s\n" "::1             localhost" "127.0.0.1       localhost" "192.168.0.253   homelocal jarvis" "140.186.168.156 home" > /etc/hosts

cp /etc/crypttab /etc/crypttab.bak
printf "home\tUUID=$(lsblk -l -o NAME,UUID | grep md0 | awk '{print $2}')\tnone\tluks,timeout=60" >> /etc/crypttab

cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
sed -e 's/^HOOKS=.*/HOOKS=\(base udev autodetect keyboard keymap modconf block mdadm_udev encrypt filesystems resume fsck\)/g' /etc/mkinitcpio.conf.bak > /etc/mkinitcpio.conf
mkinitcpio -P

# May need to replace GRUB_CMDLINE_LINUX with GRUB_CMDLINE_LINUX_DEFAULT
pacman -S grub efibootmgr
cp /etc/default/grub /etc/default/grub.bak
printf "%s\n" "GRUB_DEFAULT=saved" \
	"GRUB_TIMEOUT=5" \
	"GRUB_SAVEDEFAULT=true" \
	"GRUB_DISTRIBUTOR=\"Arch\"" \
	"GRUB_CMDLINE_LINUX=\"cryptdevice=/dev/sda2:root root=/dev/mapper/root resume=/dev/mapper/root resume_offset=$(filefrag -v /swapfile | sed -n '4p' - | awk '{print $4}' - | sed -e 's/\.\.//' -)\"" \
	"GRUB_PRELOAD_MODULES=\"part_gpt part_msdos\"" \
	"GRUB_ENABLE_CRYPTODISK=y"
	"GRUB_TIMEOUT_STYLE=menu"
	"GRUB_TERMINAL=console"
	"GRUB_GFXMODE=auto"
	"GRUB_GFXPAYLOAD_LINUX=keep"
	"GRUB_DISABLE_RECOVERY=true" > /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=ArchLinux
grub-mkconfig -o /boot/grub/grub.cfg

mdadm --detail --scan >> /etc/mdadm.conf

mkdir /etc/pacman.d/hooks
printf "%s\n" "[Trigger]" \
	"Operation = Upgrade" \
	"Type = Package" \
	"Target = pacman-mirrorlist" \
	"" \
	"[Action]" \
	"Description = Updating pacman-mirrorlist with reflector and removing pacnew" \
	"When = PostTransaction" \
	"Depends = reflector" \
	"Exec = /bin/sh -c \"reflector --country 'United States' --country 'Canada' --latest 5 --age 24 --sort rate --save /etc/pacman.d/mirrorlist\"" > /etc/pacman.d/hooks/mirrorupgrade.hook

groupadd monty
useradd -m -g monty -G wheel -s /bin/bash monty
passwd monty

cp /etc/sudoers /etc/sudoers.bak
sed -e 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers.bak > /etc/sudoers

ln -sf /bin/dash /bin/sh

# may not work perfectly
eth_interface="$(dmesg | grep -i 'renamed from eth0' - | awk '{print $5}' - | sed -e 's/://' -)"
printf "nameserver 192.168.0.1" >> /etc/resolv.conf
printf "%s\n" "[Unit]" \
	"Description = Turn on internet access" \
	"" \
	"[Service]" \
	"Type = oneshot" \
	"ExecStart = /usr/bin/sh -c 'ip addr add 192.168.0.253/24 broadcast + dev $eth_interface'" \
	"ExecStart = /usr/bin/sh -c 'ip link set $eth_interface up'" \
	"ExecStart = /usr/bin/sh -c 'ip route add default via 192.168.0.1 dev $eth_interface'" \
	"ExecStop = /usr/bin/sh -c 'ip addr del 192.168.0.253/24 broadcast + dev $eth_interface'" \
	"ExecStop = /usr/bin/sh -c 'ip link set $eth_interface down'" \
	"ExecStop = /usr/bin/sh -c 'ip route del default via 192.168.0.1 dev $eth_interface'" \
	"RemainAfterExit = yes" \
	"" \
	"[Install]" \
	"WantedBy = multi-user.target" > /etc/systemd/system/network.service
systemctl enable network.service
systemctl start network.service

# add alias for sudo="Sudo -E"

# DO NOT SET ROOT PASSWORD


#NON BASE INSTALL START

#pacman -S zathura zathura-pdf-mupdf ffmpeg youtube-dl mpv ranger w3m xorg-server mediainfo

# Git clone important rc files and move to correct locations

# Git clone and compile suckless suite

# Personalization

# exa?

# libaom-av1 ?

#NON BASE INSTALL START


# Exit

EOF

# Reboot
