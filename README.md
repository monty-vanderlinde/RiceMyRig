# RiceMyRig

This is my personalized Arch Linux installation repository.
There are three main directories which hold different scripts and files used during the installtion process.

## Base

The base directory includes several versions of an rmr.sh script which installs the base system.
This is designed to be run from a live Arch Linux environment on the system to which we will be installing.
The scripts differ depending on the chosen base layout below, and are designed to work with hard drives (i.e. /dev/sdX devices), though this can be easily customized.
There are few prerequisites that this script expects:

1. This script is being run from a live image Arch Linux
2. The computer has been successfully connected to the internet
3. The computer has enough battery life to complete this script
4. The expected architecture is x86\_64 (64-bit)

## Personalize

The personalize directory includes scripts to setup a fully functioning desktop environment.
These should run once booted into the new base system.

## Dotfiles

The dotfiles directory includes a whole host of files for personalizing the layout of the system.
Contrary to the name, these include dotfiles, rc files, config files, and many more.

## Base Layouts <sup>[1](#notes)</sup>

These system layouts are designed with security and redundancy in mind.
I prefer to use swapfiles, as they allow the base system and swap to be encrypted together, it is easier to resize on the fly, and recovering from hibernation is much simpler.

### One Drive:

1a)
```
+-------------------+------------------------------+------------------------------+
|gpt                |                              |                              |
|   EFI Partition   |   Encrypted Root Partition   |   Encrypted Home Partition   |
|                   |                              |                              |
|   /ef1            |   root (/) and /swapf1le     |   /home                      |
|                   |                              |                              |
|                   |   /dev/mapper/root           |   /dev/mapper/home           |
|                   |------------------------------|------------------------------|
|   /dev/sda1       |   /dev/sda2                  |   /dev/sda3                  |
+-------------------+------------------------------+------------------------------+
```

### Two Drives:

2a)
```
+-------------------+-------------------------------------+-------------------------------------+ +-------------------+-------------------------------------+-------------------------------------+
|gpt                |                                     |                                     | |gpt                |                                     |                                     |
|   EFI Partition   |   Raid 1 Encrypted Root Partition   |   Raid 1 Encrypted Home Partition   | |   EFI Partition   |   Raid 1 Encrypted Root Partition   |   Raid 1 Encrypted Home Partition   |
|                   |                                     |                                     | |                   |                                     |                                     |
|   /ef1            |   root (/) and /swapf1le            |   /home                             | |   /ef1            |   root (/) and /swapf1le            |   /home                             |
|                   |                                     |                                     | |                   |                                     |                                     |
|                   |   /dev/mapper/root                  |   /dev/mapper/home                  | |   copy of         |   /dev/mapper/root                  |   /dev/mapper/home                  |
|                   |-------------------------------------|-------------------------------------| |   /dev/sda1       |-------------------------------------|-------------------------------------|
|                   |   /dev/md0 (1 of 2)                 |   /dev/md1 (1 of 2)                 | |   synced daily?   |   /dev/md0 (2 of 2)                 |   /dev/md1 (2 of 2)                 |
|                   |-------------------------------------|-------------------------------------| |                   |-------------------------------------|-------------------------------------|
|   /dev/sda1       |   /dev/sda2                         |   /dev/sda3                         | |   /dev/sdb1       |   /dev/sdb2                         |   /dev/sdb3                         |
+-------------------+-------------------------------------+-------------------------------------+ +-------------------+-------------------------------------+-------------------------------------+
```

2b)<sup>[2](#notes)</sup>
```
+--------------------------+-------------------------------------+-------------------------------------+ +--------------------------+-------------------------------------+-------------------------------------+
|gpt                       |                                     |                                     | |gpt                       |                                     |                                     |
|   Raid 1 EFI Partition   |   Raid 1 Encrypted Root Partition   |   Raid 1 Encrypted Home Partition   | |   Raid 1 EFI Partition   |   Raid 1 Encrypted Root Partition   |   Raid 1 Encrypted Home Partition   |
|                          |                                     |                                     | |                          |                                     |                                     |
|   /ef1                   |   root (/) and /swapf1le            |   /home                             | |   /ef1                   |   root (/) and /swapf1le            |   /home                             |
|                          |                                     |                                     | |                          |                                     |                                     |
|   metadata=1.0           |   /dev/mapper/root                  |   /dev/mapper/home                  | |   metadata=1.0           |   /dev/mapper/root                  |   /dev/mapper/home                  |
|                          |-------------------------------------|-------------------------------------| |                          |-------------------------------------|-------------------------------------|
|   /dev/md0 (1 of 2)      |   /dev/md1 (1 of 2)                 |   /dev/md2 (1 of 2)                 | |   /dev/md0 (2 of 2)      |   /dev/md1 (2 of 2)                 |   /dev/md2 (2 of 2)                 |
|--------------------------|-------------------------------------|-------------------------------------| |--------------------------|-------------------------------------|-------------------------------------|
|   /dev/sda1              |   /dev/sda2                         |   /dev/sda3                         | |   /dev/sdb1              |   /dev/sdb2                         |   /dev/sdb3                         |
+--------------------------+-------------------------------------+-------------------------------------+ +--------------------------+-------------------------------------+-------------------------------------+
```

### Three plus Drives:

3a)
```
+-------------------+-------------------------------------+-------------------------------------+ +-------------------+-------------------------------------+-------------------------------------+ ...
|gpt                |                                     |                                     | |gpt                |                                     |                                     | ...
|   EFI Partition   |   Raid X Encrypted Root Partition   |   Raid X Encrypted Home Partition   | |   EFI Partition   |   Raid X Encrypted Root Partition   |   Raid X Encrypted Home Partition   | ...
|                   |                                     |                                     | |                   |                                     |                                     | ...
|   /ef1            |   root (/) and /swapf1le            |   /home                             | |   /ef1            |   root (/) and /swapf1le            |   /home                             | ...
|                   |                                     |                                     | |                   |                                     |                                     | ...
|                   |   /dev/mapper/root                  |   /dev/mapper/home                  | |   copy of         |   /dev/mapper/root                  |   /dev/mapper/home                  | ...
|                   |-------------------------------------|-------------------------------------| |   /dev/sda1       |-------------------------------------|-------------------------------------| ...
|                   |   /dev/md0 (1 of n)                 |   /dev/md1 (1 of n)                 | |   synced daily?   |   /dev/md0 (2 of n)                 |   /dev/md1 (2 of n)                 | ...
|                   |-------------------------------------|-------------------------------------| |                   |-------------------------------------|-------------------------------------| ...
|   /dev/sda1       |   /dev/sda2                         |   /dev/sda3                         | |   /dev/sdb1       |   /dev/sdb2                         |   /dev/sdb3                         | ...
+-------------------+-------------------------------------+-------------------------------------+ +-------------------+-------------------------------------+-------------------------------------+ ...
```

3b)<sup>[2](#notes)</sup>
```
+--------------------------+-------------------------------------+-------------------------------------+ +--------------------------+-------------------------------------+-------------------------------------+ ...
|gpt                       |                                     |                                     | |gpt                       |                                     |                                     | ...
|   Raid X EFI Partition   |   Raid X Encrypted Root Partition   |   Raid X Encrypted Home Partition   | |   Raid X EFI Partition   |   Raid X Encrypted Root Partition   |   Raid X Encrypted Home Partition   | ...
|                          |                                     |                                     | |                          |                                     |                                     | ...
|   /ef1                   |   root (/) and /swapf1le            |   /home                             | |   /ef1                   |   root (/) and /swapf1le            |   /home                             | ...
|                          |                                     |                                     | |                          |                                     |                                     | ...
|   metadata=1.0           |   /dev/mapper/root                  |   /dev/mapper/home                  | |   metadata=1.0           |   /dev/mapper/root                  |   /dev/mapper/home                  | ...
|                          |-------------------------------------|-------------------------------------| |                          |-------------------------------------|-------------------------------------| ...
|   /dev/md0 (1 of n)      |   /dev/md1 (1 of n)                 |   /dev/md2 (1 of n)                 | |   /dev/md0 (2 of n)      |   /dev/md1 (2 of n)                 |   /dev/md2 (2 of n)                 | ...
|--------------------------|-------------------------------------|-------------------------------------| |--------------------------|-------------------------------------|-------------------------------------| ...
|   /dev/sda1              |   /dev/sda2                         |   /dev/sda3                         | |   /dev/sdb1              |   /dev/sdb2                         |   /dev/sdb3                         | ...
+--------------------------+-------------------------------------+-------------------------------------+ +--------------------------+-------------------------------------+-------------------------------------+ ...
```

3c)<sup>[3](#notes)</sup>
```
+--------------------------+------------------------------+ +-------------------------------------+ +-------------------------------------+ ...
|gpt                       |                              | |gpt                                  | |gpt                                  | ...
|   EFI Partition          |   Encrypted Root Partition   | |   Raid X Encrypted Home Partition   | |   Raid X Encrypted Home Partition   | ...
|                          |                              | |                                     | |                                     | ...
|   /ef1                   |   root (/) and /swapf1le     | |   /home                             | |   /home                             | ...
|                          |                              | |                                     | |                                     | ...
|                          |                              | |   /dev/mapper/home                  | |   /dev/mapper/home                  | ...
|                          |                              | |   ----------------------------------| |   ----------------------------------| ...
|                          |   /dev/mapper/root           | |   /dev/md0 (1 of n)                 | |   /dev/md0 (2 of n)                 | ...
|                          |------------------------------| |-------------------------------------| |-------------------------------------| ...
|   /dev/sda1              |   /dev/sda2                  | |   /dev/sdb1                         | |   /dev/sdc1                         | ...
+--------------------------+------------------------------+ +-------------------------------------+ +-------------------------------------+ ...
```

## Notes

1. Due to the default style generated by GitHub for markdown, all "fi" substrings in the code blocks below have been replaced with "f1".
This is because the default css includes font-variant-ligatures, which makes "ff", "fi", and "fl" a single character length.
I am not sure why this exists when code blocks are supposed to be monospace, but it is probably just an oversight.
2. 2b and 3b layouts have not been tested yet.
Depending on how UEFI firmware works on your system, there is always a possibility of data corruption on the EFI System Partition.
See these linked articles on the [Arch Wiki](https://wiki.archlinux.org/index.php/EFI_system_partition#ESP_on_software_RAID1).
3. Currently, only these layouts have been tested and debugged on real hardware.
However, as alpha testing continues, this will change.
