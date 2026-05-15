<p align="center">
  <img src="https://github.com/realvolk/ArtixTUI/blob/main/.github/artixtui.png" width="196" alt="Artix Linux">
</p>

<h1 align="center">ArtixTUI</h1>

<p align="center">
  <strong>A beautiful, modular, TUI-first installer for Artix Linux</strong><br>
  No flags. No confusion. Just a gorgeous terminal interface.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v7.1.1.2-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash" alt="Bash">
  <img src="https://img.shields.io/badge/TUI-gum-FFB6C1?style=flat-square" alt="gum">
  <img src="https://img.shields.io/badge/License-Volk Open License 1.0-yellow?style=flat-square" alt="License">
</p>

---

# What is ArtixTUI?

ArtixTUI is a **TUI-first, modular installer** for Artix Linux (OpenRC, runit, dinit, s6).

It walks you through partitioning, filesystem creation, base system installation, bootloader setup, desktop environment, drivers, and extra tools, all from a single, beautiful terminal interface.

Built with **gum** by Charmbracelet, it looks better than `archinstall` and works with **any** Artix init system.

---

# Quick Start

```bash
git clone https://github.com/realvolk/ArtixTUI.git
cd ArtixTUI
chmod +x install
sudo ./install
```

That's it.

No `--auto`, no `--manual`, no confusing flags.

You'll be greeted by a main menu where you choose your installation mode.

---

# Installation Modes

| Mode | Description |
|------|-------------|
| 🟢 Automatic | The installer guides you through every configuration choice. |
| 🔵 Manual | You select a disk; the installer detects what's already done and resumes. |
| 🟡 Resume | Continue an interrupted installation from the last saved stage. |
| 🟠 Recovery | Scan `/mnt` for an existing system, reconstruct state, and repair. |
| 🔴 Power User | Compile everything from source, Gentoo-style (`CFLAGS`, `MAKEOPTS`, etc.) — coming in v7.2? |

A debug toggle is available for every mode from the same menu.

---

# Features

- Gorgeous TUI — built on gum *(no more dialog!)*
- Modular architecture — separate scripts for storage, install, post, stages
- Universal logger — every message is written to:
  - `/tmp/artix-installer/install.log`
  - `/mnt/var/log/artix-installer.log`
- Safe passwords — hashed with `openssl passwd -6`, never written to disk
- Full-disk encryption — LUKS support with passphrase confirmation
- EFIStub, GRUB, rEFInd — all bootloaders supported
- Multiple kernels:
  - `linux`
  - `zen`
  - `lts`
  - `hardened`
  - `libre`
  - `cachyos`
  - `bazzite`
  - `xanmod`
  - `tkg`
- Multiple filesystems:
  - `ext4`
  - `btrfs`
  - `xfs`
  - `f2fs`
  - `bcachefs`
  - `exfat`
  - `zfs`
- Desktop environments:
  - XFCE
  - LXQt
  - KDE Plasma
  - LXDE
  - Hyprland
  - MangoWM
  - Niri
  - Sway
  - i3
  - dwm
  - IceWM
- GPU detection:
  - NVIDIA (`open-dkms` or proprietary)
  - Intel
  - AMD
  - VESA fallback
  - VM guest drivers
- Extras:
  - flatpak
  - ufw
  - bluez
  - zram
  - fzf
  - zoxide
  - starship
  - eza
  - btop
  - tmux
  - rsvc
  - more
- Offline mode — install from cached packages when network is unavailable
- State persistence — all configuration saved to `/tmp/artix-installer/state.conf` for resume/recovery

---

# Dependencies

ArtixTUI requires `gum` for its TUI.

If it is not already installed, the installer will build it from source during the preflight stage (requires `go`, which will also be installed automatically).

Everything else is handled by the installer itself.

---

# Project Structure

```text
ArtixTUI/
├── .github/                    # Images, etc.
│   └── artixtui.png            # 🩵
├── install                     # entry point
├── LICENSE                     # Volk Open License 1.0
├── CONTRIBUTING                # Contributions file
├── VERSION                     # version file for auto-update
├── scripts/
│   ├── common.sh               # logging, helpers, requirements
│   ├── state.sh                # configuration state read/write
│   ├── recovery.sh             # existing-system detection
│   ├── kernels.sh              # kernel package detection
│   ├── tui/
│   │   ├── core.sh             # gum wrappers (all UI primitives)
│   │   ├── menus.sh            # configuration selection functions
│   │   └── summary.sh          # installation summary screen
│   ├── storage/
│   │   ├── partition.sh        # GPT partitioning
│   │   ├── filesystem.sh       # filesystem creation
│   │   └── mount.sh            # filesystem mounting
│   ├── install/
│   │   ├── basestrap.sh        # base system installation
│   │   ├── bootloader.sh       # GRUB / rEFInd / EFIStub setup
│   │   ├── handoff.sh          # configuration export to target
│   │   ├── services.sh         # service management wrappers
│   │   ├── system.sh           # hostname, locale, timezone
│   │   └── users.sh            # user creation and passwords
│   ├── post/
│   │   ├── networking.sh       # network stack configuration
│   │   ├── drivers.sh          # GPU, VM, and kernel drivers
│   │   ├── desktop.sh          # desktop environment installation
│   │   ├── audio.sh            # PipeWire / PulseAudio setup
│   │   └── extras.sh           # optional packages
│   └── stages/
│       ├── preflight.sh        # environment preparation
│       ├── storage.sh          # storage orchestration
│       ├── base.sh             # base installation stage
│       ├── chroot.sh           # chroot configuration stage
│       ├── post.sh             # post-install stage
│       └── finalize.sh         # cleanup and finalisation
```

---

# Supported Configurations

| Category | Options |
|---|---|
| Init system | OpenRC, runit, dinit, s6 |
| Filesystem | ext4, btrfs, xfs, f2fs, bcachefs, exfat, zfs |
| Bootloader | GRUB, rEFInd, EFIStub |
| Kernel | linux, zen, lts, hardened, libre, cachyos-bore, bazzite, xanmod, tkg |
| Desktop | XFCE, LXQt, KDE Plasma, LXDE, Hyprland, MangoWM, Niri, Sway, i3, dwm, IceWM, none |
| Network | NetworkManager, dhcpcd+iwd, ConnMan, none |
| Audio | PipeWire, PulseAudio, none |
| Shell | bash, zsh, fish |
| Display stack | X.Org, xLibre |
| Encryption | LUKS full-disk encryption |

---

# Contributing

Contributions are welcome and appreciated.
Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on testing,
submissions, and code of conduct.

---

# License

Licensed under the [Volk Open License 1.0](LICENSE) © [realvolk](https://github.com/realvolk) 2026.