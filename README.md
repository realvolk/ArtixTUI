# ArtixTUI - Artix Linux TUI Installer

Modular TUI installer for Artix Linux.  

Designed for users who want a configurable Artix setup without manually performing every installation step.

#### Version: v6.2.2.1  
*(Rewrite / Major Release / New Feature / Major bug fix / Minor bug fix / Hot fix)*

---

# Overview

ArtixTUI automates the installation process while keeping the process **modular, transparent, and user-controlled**.  

The installer follows a **modular shell-based structure** with separate stages and post-install components instead of one monolithic script. Almost everything is selectable during installation.  

It can **automatically self-update** when a newer upstream version is detected.

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
- CachyOS
- XanMod
- TKG Kernel
- Bazzite Kernel

## Filesystem Support
Supported filesystems:

- ext4
- BTRFS
- XFS
- F2FS
- Bcachefs
- exFAT
- ZFS

Filesystem utilities and kernel modules required by the selected filesystem
(e.g. `f2fs-tools`, `dosfstools`, `xfsprogs`, etc.) are automatically handled inside the live environment when needed.

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
- EFIStub (automatic efibootmgr entry creation)

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
- UEFI boot mode
- Git

Some advanced filesystem or kernel combinations may require temporary
package installation inside the live environment. ArtixTUI attempts to handle this automatically.

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

# Technics

## Installer Flags

- `-a, --auto` — TUI-driven automated Artix installation  
- `-m, --manual` — Manual installation mode  
- `-r, --resume` — Resume interrupted installation  
- `-rr, --recovery` — Recover partially completed installation  
- `-d, --debug` — Enable shell tracing (can be used with any mode)  
- `-h, --help` — Show this help message  

> **Note:** If the installer was interrupted (e.g., via CTRL+C), `-a` may act like `-r` and resume where it left off. Flags cannot be combined; only one mode flag should be used at a time.

## What the Installer Does

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

## Script Structure

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

### Modular Post-Install Components

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

Recovery mode attempts to detect existing mounted installations in `/mnt` and continue from the appropriate stage.

---

# Maintenance

Actively maintained and tested as features are added. Bug reports and feedback are welcome via GitHub issues or Discord (**volk.v**).

*Just because something is added does NOT mean it is immediately tested.*

---

# Known Caveats

- Some custom kernels may require additional repositories.
- ZFS support depends on matching kernel headers.
- EFIStub installations require proper UEFI firmware support.
- DKMS-based kernel/module combinations may increase installation time.
- Some filesystem combinations may require additional live-environment tooling.
- Certain combinations WILL break the script. Please report bugs for fixes.
- Certain things are known to break while attempting an install: ZFS, Bazzite, Xanmod, MangoWM, etc.

---

# Self-Updater Notice

The installer replaces outdated files during self-update.  
Do not keep custom modifications inside the installer directory unless version controlled.

---

# Troubleshooting ("Oh no's")

### The script won't launch?
```bash
chmod +x install
```

### Terminal acts weird after script exit?
```bash
TERM=xterm-256color
reset
```
Or switch to another TTY (e.g., CTRL+ALT+F2).

### Internet went out mid-install
Wait for network recovery, then:
```bash
sudo ./install -r
```

### Debugging hangs / weird behavior?
```bash
sudo ./install -r -d
```
Inspect logs in `/root/ArtixTUI/`:
- `basestrap-debug.log`  
- `drivers-debug.log`  
- `post-stage.log`  

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

Inside scripts, you can temporarily add `-x` to see shell traces.

---

# QnA

**Q:** Why only 3 debug logs?  
**A:** Key stages are logged; more may be added over time.

**Q:** Why manually enable `-x` in scripts?  
**A:** To pinpoint exact failures for easier debugging and reporting.

**Q:** Where can I suggest features?  
**A:** GitHub issues, Discord, or smoke signals if you perfer.

---

# Credits

Original project by [realvolk](https://github.com/realvolk)