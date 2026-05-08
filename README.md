# ArtixTUI - Artix Linux TUI Installer

Modular TUI installer for Artix Linux. 

Designed for users who want a configurable Artix setup without manually performing every installation step.

####  Version: v5.0.3
---

# Overview

ArtixTUI automates the installation process while still keeping the install modular, transparent, and user-controlled.

The installer follows a modular shell-based structure with separate stages and post-install components instead of one massive monolithic script.

Almost everything is selectable during installation.

---

# Features
## Init Systems

Supports all official Artix init systems:

- OpenRC
- runit
- s6
- dinit

## Display Stack

Selectable display server stack:

- X.Org
- xLibre

Wayland compositors automatically install XWayland support where needed.

## Desktop Environments / Window Managers

Currently supported:

- XFCE4
- LXQt
- LXDE
- Hyprland
- Niri
- Sway
- i3wm
- dwm
- IceWM

Minimal installs are also supported.


## Kernel Selection

Available kernel choices:

- Linux
- Linux LTS
- Linux Hardened
- Linux Libre
- CachyOS Bore
- XanMod
- Bazzite Kernel
- TKG Kernel

## Filesystem Support

Supported filesystems:

- ext4
- BTRFS
- XFS
- F2FS
- Bcachefs
- exFAT
- ZFS

## GPU Driver Detection

Automatic GPU and virtualization detection.

Supports:

- Intel
- AMD
- NVIDIA
- VMware
- VirtualBox
- QEMU/KVM

Includes support for:

- NVIDIA Open Kernel Modules
- Nouveau fallback
- xLibre driver stack

## Networking

Selectable network stack:

- NetworkManager
- dhcpcd + iwd
- ConnMan
- Manual setup

## Audio

Selectable audio stack:

- PipeWire
- PulseAudio
- No audio stack

## Security

Optional:

- LUKS full disk encryption

## Bootloaders

Supported bootloaders:

- GRUB
- rEFInd
- EFISTUB

## Shell Selection

Selectable user shell:

- Bash
- Zsh
- Fish

## Extra Tools

Optional extras menu includes:

- Git + base-devel
- Flatpak
- Fastfetch
- UFW
- Bluetooth support
- ZRAM
- fzf
- zoxide
- starship
- eza
- btop
- htop
- nvtop
- tmux
- usb_modeswitch
- rsvc (runit helper)

---

# Requirements

- Artix Linux live environment
- Internet connection
- EFI system
- Git

---

# Installation

```bash
git clone https://github.com/realvolk/ArtixTUI
cd ArtixTUI

chmod +x install

sudo ./install
```

---

# What The Installer Does

- Verifies required environment
- Handles disk partitioning and formatting
- Configures init system
- Installs selected kernel
- Installs base system
- Configures networking
- Installs bootloader
- Generates fstab
- Configures users
- Installs drivers
- Installs desktop environment/window manager
- Enables required services
- Applies post-install configuration

---

# Script Structure

## Core

| File | Purpose |
|---|---|
| `install` | Main installer entry point |
| `scripts/common.sh` | Basic operations |
| `scripts/state.sh` | Installer state management |
| `scripts/tui/` | TUI framework and menus |
| `scripts/stages/` | Installation stages |
| `scripts/install/` | Base installation logic |
| `scripts/post/` | Post-install modules |

---

## Modular Post-Install Components

Separated into individual modules:

- drivers
- audio
- desktop
- networking
- extras

---

# Goals

- Modular shell design
- Minimal assumptions
- Multi-init support
- Easy maintenance
- Easier debugging than monolithic installers
- Keep the installer understandable

---

# Maintenance

Actively maintained and tested as features are added. However, this does not mean that bugs are not present.

Bug reports and feedback are welcome, either as issues on the repo or directly contacting me on discord: **(volk.v)**.

I am the sole maintainer.

*Just because I added something does NOT mean it is immediately tested.*

---

## The "Oh no's":

### The script won't even launch! 
```bash
chmod +x install
```

### My terminal is acting all weird after the script exited for whatever reason!
```bash
TERM=xterm-256color
reset
```
Alternatively: **CTRL+ALT+F2** or any other shortcut for a new TTY (NOTE: the `TERM=...` will also work for VMs).
### My internet / wifi went out! What now!?

You should generally wait for your wifi (modem, router, etc.) to regain connection, then execute:
```bash
sudo ./install -r
```
### I found a weird bug! / I got thrown an "OK" and nothing else!
If you think you've found something that might be a bug, or a missing feature, check with:
```bash
sudo ./install -r -d
```

This will make your script run in debug mode via the `-d` (or `--debug`) flag. If it still won't tell you what's happening, note on which STAGE the script is on.

##### Example: `drivers.sh` gets stuck on ```[*] Installing drivers...```? This is how to check what happens:
```bash
cd ArtixTUI/scripts/post/ && nano drivers.sh

    INSIDE drivers.sh:
set -Eeuo pipefail;

    Should become:
set -Eeuxo pipefail;

```
CTRL+O, Enter, CTRL+X to exit. run the script with the -r flag.

Alternatively, check (If a bug occurs, the partitions will stay mounted):
```bash
artix-chroot /mnt
cd root/ArtixTUI
```
In `ArtixTUI/` (or `root`) you may find the following log files: `basestrap-debug.log`, `drivers-debug.log` and `post-stage.log `. 

###### P.S. You check with `cat ...` command.

### Er.. where's my system!? I rebooted and there's nothing!

That means that either the script completely failed the `artix-chroot` part and somehow still continued, or you're a wizard. Either way, make an issue on the github repo. I'll gladly help out.

---

# QnA

###### *Q: Why is there only 3 .log files for the total script?! What if it breaks somewhere else?*

###### A: Because the other parts worked fine during testing, except these 3. I will add more in the future as features pile up, or new bugs appear.

###### *Q: WTF? Why would I wanna go into the scripts folder and sub-folder to just set the -x flag?*

###### A: Because you'll make both your and my life way easier if the script tells you where it's hanging.

###### *Q: Where can I suggest new features?*

###### A: Either as an issue on the github repo, or messaging me on Discord, or smoke signals if you prefer.

---

# Credits

Original project by:

- [realvolk](https://github.com/realvolk/)