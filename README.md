# ArtixInstall - TUI Version!

Artix Linux installation script. Intended for anyone willing to try out Artix without the hassle.
(TUI)

## Overview

This script automates Artix Linux installation while adhering to UNIX philosophy principles: modularity, plain text interfaces, and small focused tools that pipe together.

Everything is up to the user's choice.

## Features

**NEWEST FEATURE(S)**: NVIDIA 20,30,40,50 Driver support! 

**Init systems**: OpenRC, runit, s6, dinit

**Display drivers**: Includes Xlibre drivers and Xorg, up for taste of the user.

**Security**: Optional LUKS encryption.

**Storage:** BTRFS or EXT4. 

**Network**: Ethernet default. Installs iwd, wpa_supplicant, and dhcpcd.

**Bootloaders**: Grub, rEFInd, efistub.

**Kernels**: Baseline Linux Kernel, LTS, Hardened, Xanmod (AUR), TKG (Compile-able)

**Desktop environments**: Selectable during the installation process: XFCE4, XLQt, XLQE, Wayland, dwm, vxvm, i3..

## Requirements

- Artix Linux live environment *(any init system)*

- Internet connectivity

- Git 

## Installation
    bash

    git clone https://github.com/MadeInAmbrosia/ArtixTUI
    cd ArtixTUI
    chmod +x install
    sudo ./install -h

## What the script does

- Verifies network connectivity

- Gives 2 options:

- Automatic: Script partitions the disk

- Manual: User pre-partitions before running script

- Presents configuration options for init system, kernel and bootloader, DE.

- Installs base system

- Installs iwd, wpa_supplicant, and dhcpcd

- Configures first-boot scripts for driver and service finalization.

## Post-install

- First boot triggers firstboot.sh, which handles:

- Driver installation (including Xlibre where applicable).

- Service enabling based on selected init system.

- WiFi configuration via iwd.

- Allows the user to choose to enable arch repos.

- Creates the user, installs drivers of choice, sets up audio, the DE.

- Contains bonus tools such as Git and base-devel, Codecs, UFW, Bluetooth, Flatpak, Zram, Fastfetch, (runit only) SashexSRB's rsvc.

## Script structure
### File	Purpose
*install* -	Main installation routine

*firstboot.sh* - Post-install configuration on first boot

*firstboot_trigger.sh* -	Trigger mechanism for firstboot.sh

*scripts/* - Manual and Auto scripts for base-line installation, along with the core logic scripts (common.sh, engine.sh, pkgs.sh)

## Maintenance

Actively maintained and tested for every new feature added.

Any bugs should be reported either here on Github or via contacting *volk.v* on Discord.

## Credits

#### Original: [realvolk](https://github.com/realvolk/)

