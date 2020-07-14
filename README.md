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
4. The expected architecture is x86_64 (64-bit)

## Personalize

The personalize directory includes scripts to setup a fully functioning desktop environment.
These should run once booted into the new base system.

## Dotfiles

The dotfiles directory includes a whole host of files for personalizing the layout of the system.
Contrary to the name, these include dotfiles, rc files, config files, and many more.

## Base Layouts

These system layouts are designed with security and redundancy in mind.
I prefer to use swapfiles, as they allow the base system and swap to be encrypted together, it is easier to resize on the fly, and recovering from hibernation is much simpler.

### One Drive:

1a)
```
+-------------------+------------------------------+------------------------------+
|gpt                |                              |                              |
|   EFI Partition   |   Encrypted Root Partition   |   Encrypted Home Partition   |
|                   |                              |                              |
|   /efi            |   root (/) and /swapfile     |   /home                      |
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
|   /efi            |   root (/) and /swapfile            |   /home                             | |   /efi            |   root (/) and /swapfile            |   /home                             |
|                   |                                     |                                     | |                   |                                     |                                     |
|                   |   /dev/mapper/root                  |   /dev/mapper/home                  | |   copy of         |   /dev/mapper/root                  |   /dev/mapper/home                  |
|                   |-------------------------------------|-------------------------------------| |   /dev/sda1       |-------------------------------------|-------------------------------------|
|                   |   /dev/md0 (1 of 2)                 |   /dev/md1 (1 of 2)                 | |   synced daily?   |   /dev/md0 (2 of 2)                 |   /dev/md1 (2 of 2)                 |
|                   |-------------------------------------|-------------------------------------| |                   |-------------------------------------|-------------------------------------|
|   /dev/sda1       |   /dev/sda2                         |   /dev/sda3                         | |   /dev/sdb1       |   /dev/sdb2                         |   /dev/sdb3                         |
+-------------------+-------------------------------------+-------------------------------------+ +-------------------+-------------------------------------+-------------------------------------+
```

2b)
```
+--------------------------+-------------------------------------+-------------------------------------+ +--------------------------+-------------------------------------+-------------------------------------+
|gpt                       |                                     |                                     | |gpt                       |                                     |                                     |
|   Raid 1 EFI Partition   |   Raid 1 Encrypted Root Partition   |   Raid 1 Encrypted Home Partition   | |   Raid 1 EFI Partition   |   Raid 1 Encrypted Root Partition   |   Raid 1 Encrypted Home Partition   |
|                          |                                     |                                     | |                          |                                     |                                     |
|   /efi                   |   root (/) and /swapfile            |   /home                             | |   /efi                   |   root (/) and /swapfile            |   /home                             |
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
|   /efi            |   root (/) and /swapfile            |   /home                             | |   /efi            |   root (/) and /swapfile            |   /home                             | ...
|                   |                                     |                                     | |                   |                                     |                                     | ...
|                   |   /dev/mapper/root                  |   /dev/mapper/home                  | |   copy of         |   /dev/mapper/root                  |   /dev/mapper/home                  | ...
|                   |-------------------------------------|-------------------------------------| |   /dev/sda1       |-------------------------------------|-------------------------------------| ...
|                   |   /dev/md0 (1 of n)                 |   /dev/md1 (1 of n)                 | |   synced daily?   |   /dev/md0 (2 of n)                 |   /dev/md1 (2 of n)                 | ...
|                   |-------------------------------------|-------------------------------------| |                   |-------------------------------------|-------------------------------------| ...
|   /dev/sda1       |   /dev/sda2                         |   /dev/sda3                         | |   /dev/sdb1       |   /dev/sdb2                         |   /dev/sdb3                         | ...
+-------------------+-------------------------------------+-------------------------------------+ +-------------------+-------------------------------------+-------------------------------------+ ...
```

3b)
```
+--------------------------+-------------------------------------+-------------------------------------+ +--------------------------+-------------------------------------+-------------------------------------+ ...
|gpt                       |                                     |                                     | |gpt                       |                                     |                                     | ...
|   Raid X EFI Partition   |   Raid X Encrypted Root Partition   |   Raid X Encrypted Home Partition   | |   Raid X EFI Partition   |   Raid X Encrypted Root Partition   |   Raid X Encrypted Home Partition   | ...
|                          |                                     |                                     | |                          |                                     |                                     | ...
|   /efi                   |   root (/) and /swapfile            |   /home                             | |   /efi                   |   root (/) and /swapfile            |   /home                             | ...
|                          |                                     |                                     | |                          |                                     |                                     | ...
|   metadata=1.0           |   /dev/mapper/root                  |   /dev/mapper/home                  | |   metadata=1.0           |   /dev/mapper/root                  |   /dev/mapper/home                  | ...
|                          |-------------------------------------|-------------------------------------| |                          |-------------------------------------|-------------------------------------| ...
|   /dev/md0 (1 of n)      |   /dev/md1 (1 of n)                 |   /dev/md2 (1 of n)                 | |   /dev/md0 (2 of n)      |   /dev/md1 (2 of n)                 |   /dev/md2 (2 of n)                 | ...
|--------------------------|-------------------------------------|-------------------------------------| |--------------------------|-------------------------------------|-------------------------------------| ...
|   /dev/sda1              |   /dev/sda2                         |   /dev/sda3                         | |   /dev/sdb1              |   /dev/sdb2                         |   /dev/sdb3                         | ...
+--------------------------+-------------------------------------+-------------------------------------+ +--------------------------+-------------------------------------+-------------------------------------+ ...
```

3c)
```
+--------------------------+------------------------------+ +-------------------------------------+ +-------------------------------------+ ...
|gpt                       |                              | |gpt                                  | |gpt                                  | ...
|   EFI Partition          |   Encrypted Root Partition   | |   Raid X Encrypted Home Partition   | |   Raid X Encrypted Home Partition   | ...
|                          |                              | |                                     | |                                     | ...
|   /efi                   |   root (/) and /swapfile     | |   /home                             | |   /home                             | ...
|                          |                              | |                                     | |                                     | ...
|                          |                              | |   /dev/mapper/home                  | |   /dev/mapper/home                  | ...
|                          |                              | |   ----------------------------------| |   ----------------------------------| ...
|                          |   /dev/mapper/root           | |   /dev/md0 (1 of n)                 | |   /dev/md0 (2 of n)                 | ...
|                          |------------------------------| |-------------------------------------| |-------------------------------------| ...
|   /dev/sda1              |   /dev/sda2                  | |   /dev/sdb1                         | |   /dev/sdc1                         | ...
+--------------------------+------------------------------+ +-------------------------------------+ +-------------------------------------+ ...
```
