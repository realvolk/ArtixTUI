# ArtixTUI - Artix Linux TUI Installer

Modular TUI installer for Artix Linux.

Designed for users who want a configurable Artix setup without manually performing every installation step.

#### Version: v6.1.1.2
###### *(Version: Rewrite/Major Release, New Feature, Major bug fix, Minor bug fix/Hot fix)*

---

# Overview

ArtixTUI automates the installation process while still keeping the install modular, transparent, and user-controlled.

The installer follows a modular shell-based structure with separate stages and post-install components instead of one massive monolithic script.

Almost everything is selectable during installation.

The installer can automatically self-update when a newer upstream version is detected.

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

---

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

---

## Kernel Selection

Available kernel choices:

- Linux
- Linux LTS
- Linux Hardened
- Linux Libre
- CachyOS
- XanMod
- TKG Kernel
- Bazzite Kernel

---

## Filesystem Support

Supported filesystems:

- ext4
- BTRFS
- XFS
- F2FS
- Bcachefs
- exFAT
- ZFS

---

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

---

## Networking

Selectable network stack:

- NetworkManager
- dhcpcd + iwd
- ConnMan
- Manual setup

---

## Audio

Selectable audio stack:

- PipeWire
- PulseAudio
- No audio stack

---

## Security

Optional:

- LUKS full disk encryption

---

## Bootloaders

Supported bootloaders:

- GRUB
- rEFInd
- EFIStub (automatic efibootmgr entry creation)

---

## Shell Selection

Selectable user shell:

- Bash
- Zsh
- Fish

---

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
- UEFI boot mode
- Git

---

# Installation

```bash
git clone https://github.com/realvolk/ArtixTUI
cd ArtixTUI

chmod +x install

sudo ./install
```

The installer can automatically self-update when a newer upstream version is detected.

---

# What The Installer Does

- Verifies required environment
- Handles disk partitioning and formatting
- Configures init system
- Installs selected kernel
- Installs base system
- Configures networking
- Installs bootloader
- Automatically creates EFI boot entries
- Generates fstab
- Configures users
- Installs drivers
- Installs desktop environment/window manager
- Enables required services
- Applies post-install configuration
- Supports installer recovery/resume
- Self-updates outdated installer versions

---

# Script Structure

## Core

| File | Purpose |
|---|---|
| `install` | Main installer entry point |
| `scripts/common.sh` | Basic operations |
| `scripts/state.sh` | Installer state management |
| `scripts/recovery.sh` | Recovery options manager |
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

# Recovery

If installation is interrupted:

```bash
sudo ./install -r
```

To attempt recovery of a partially completed installation:

```bash
sudo ./install -rr
```

Recovery mode attempts to detect existing mounted installations in `/mnt`
and continue from the appropriate stage.

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

# Known Caveats

- Some custom kernels may require additional repositories.
- ZFS support depends on matching kernel headers.
- EFIStub installations require proper UEFI firmware support.

---

# Self-Updater Notice

The installer replaces outdated files during self-update.

Do not keep custom modifications inside the installer directory unless version controlled.

---

## The "Oh no's":

### The script won't even launch!

```bash
chmod +x install
```

---

### My terminal is acting all weird after the script exited for whatever reason!

```bash
TERM=xterm-256color
reset
```

Alternatively: **CTRL+ALT+F2** or any other shortcut for a new TTY.

*(NOTE: the `TERM=...` workaround also works inside VMs.)*

---

### My internet / wifi went out! What now!?

You should generally wait for your wifi (modem, router, etc.) to regain connection, then execute:

```bash
sudo ./install -r
```

---

### I found a weird bug! / I got thrown an "OK" and nothing else!

If you think you've found something that might be a bug, or a missing feature, check with:

```bash
sudo ./install -r -d
```

This runs the installer in debug mode using the `-d` (or `--debug`) flag.

If the issue still is not obvious, note the installation STAGE where the installer stopped.

##### Example: `drivers.sh` gets stuck on `[*] Installing drivers...`

```bash
cd ArtixTUI/scripts/post/
nano drivers.sh
```

Inside `drivers.sh`:

```bash
set -Eeuo pipefail;
```

Should temporarily become:

```bash
set -Eeuxo pipefail;
```

Save:
- CTRL+O
- Enter
- CTRL+X

Then run the installer again with:

```bash
sudo ./install -r
```

---

Alternatively, check the generated logs.

If a failure occurs, partitions usually remain mounted:

```bash
artix-chroot /mnt

cd /root/ArtixTUI
```

Inside `ArtixTUI/` you may find:

- `basestrap-debug.log`
- `drivers-debug.log`
- `post-stage.log`

###### P.S.

You can inspect logs with:

```bash
cat filename.log
```

---

### System failed to boot after installation

Boot failures are usually related to:

- incorrect EFI setup
- unsupported kernel/repository combinations
- failed driver installation
- incomplete bootloader configuration

Try:

```bash
sudo ./install -rr -d
```

Then inspect:

```bash
/root/ArtixTUI/
```

for generated logs.

---

# QnA

###### *Q: Why is there only 3 .log files for the total script?! What if it breaks somewhere else?*

###### A:

Some installation stages include dedicated debug logging
for easier troubleshooting of hardware-specific failures.

Additional logging may be added over time as new features and edge cases appear.

---

###### *Q: WTF? Why would I wanna go into the scripts folder and sub-folder to just set the -x flag?*

###### A:

Because it makes both debugging and bug reporting significantly easier.

If the shell trace shows exactly where the script hangs,
the problem is usually much easier to identify.

---

###### *Q: Where can I suggest new features?*

###### A:

Either:
- as an issue on the GitHub repo
- via Discord
- or smoke signals if you prefer

---

# Credits

Original project by:

- [realvolk](https://github.com/realvolk/)