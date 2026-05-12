#!/usr/bin/env bash
set -Eeuo pipefail;

tui_select_disk() {
    local disk;
    local disks=();

    while read -r name size model; do
        disks+=(
            "${name}"
            "${size} - ${model:-Unknown}"
        );
    done < <(
        lsblk -dpno NAME,SIZE,MODEL
    );

    disk=$(
        dialog --stdout \
            --title " Disk Selection " \
            --menu "Choose target drive:" \
            18 70 8 \
            "${disks[@]}"
    );

    [[ -n "${disk}" ]] || return 1;

    state_set DISK "${disk}";
}

tui_select_init() {
    local init;

    init=$(
        tui_menu \
            " Init System " \
            "Select init system:" \
            "openrc" "OpenRC" \
            "runit"  "runit" \
            "dinit"  "dinit" \
            "s6"     "s6"
    );

    [[ -n "${init}" ]] || return 1;

    state_set INIT "${init}";
}

tui_select_filesystem() {
    local fs;

    fs=$(
        tui_menu \
            " Filesystem " \
            "Select filesystem:" \
            "ext4"      "Reliable standard Linux filesystem" \
            "btrfs"     "Modern CoW filesystem with snapshots" \
            "xfs"       "High-performance filesystem for large files" \
            "f2fs"      "Flash-friendly filesystem for SSDs/NVMe" \
            "bcachefs"  "Modern CoW filesystem with compression/checksums" \
            "exfat"     "Cross-platform filesystem compatibility" \
            "zfs"       "Advanced pooled filesystem with snapshots and RAID"
    );

    [[ -n "${fs}" ]] || return 1;

    case "${fs}" in
        zfs)
            if ! pacman -Si zfs-utils >/dev/null 2>&1; then
                dialog \
                    --title " ZFS Unavailable " \
                    --msgbox \
"ZFS packages are unavailable in the current environment.

Please check your repositories or internet connection." \
                    10 70;

                return 1;
            fi
            ;;

        bcachefs)
            if ! pacman -Si bcachefs-tools >/dev/null 2>&1; then
                dialog \
                    --title " bcachefs Unavailable " \
                    --msgbox \
"bcachefs tools are unavailable in the current environment.

Please check your repositories or internet connection." \
                    10 70;

                return 1;
            fi
            ;;
    esac

    state_set FS_TYPE "${fs}";
}

tui_select_bootloader() {
    local bootloader;

    bootloader=$(
        tui_menu \
            " Bootloader " \
            "Select bootloader:" \
            "grub"    "GNU GRUB" \
            "refind"  "rEFInd" \
            "efistub" "Direct EFI boot"
    );

    [[ -n "${bootloader}" ]] || return 1;

    state_set BOOTLOADER "${bootloader}";
}

tui_select_kernel() {
    local kernel;

    kernel=$(
        tui_menu \
            " Kernel " \
            "Select kernel:" \
            "linux"                "Standard kernel" \
            "linux-zen"            "Zen kernel" \
            "linux-lts"            "Long-term support" \
            "linux-hardened"       "Security-focused" \
            "linux-libre"          "Free software only kernel" \
            "linux-cachyos-bore"   "CachyOS Bore scheduler kernel" \
            "linux-bazzite-bin"    "Bazzite prebuilt gaming kernel" \
            "xanmod"               "Performance-oriented XanMod kernel" \
            "tkg"                  "Customizable TKG kernel"
    );

    [[ -n "${kernel}" ]] || return 1;

    state_set KERNEL_CHOICE "${kernel}";
}

tui_select_desktop() {
    local desktop;

    desktop=$(
        tui_menu \
            " Desktop Environment " \
            "Select desktop environment:" \
            "xfce4"    "XFCE Desktop" \
            "lxqt"     "LXQt Desktop" \
            "kde"      "KDE Plasma desktop" \
            "lxde"     "Lightweight LXDE desktop" \
            "mango"    "Mango dynamic Wayland compositor" \
            "hyprland" "Hyprland Wayland compositor" \
            "niri"     "Scrollable tiling Wayland compositor" \
            "sway"     "i3-compatible Wayland compositor" \
            "i3wm"     "Minimal tiling WM" \
            "dwm"      "Dynamic window manager" \
            "icewm"    "Traditional lightweight WM" \
            "none"     "No desktop"
    );

    [[ -n "${desktop}" ]] || return 1;

    state_set WM_DE "${desktop}";

    if [[ "${desktop}" == 'kde' ]]; then
        local kde_profile;

        kde_profile=$(
            tui_menu \
                " KDE Profile " \
                "Select KDE Plasma profile:" \
                "minimal" "Minimal Plasma setup" \
                "desktop" "Standard Plasma desktop" \
                "full"    "Full KDE applications suite"
        );

        [[ -n "${kde_profile}" ]] || return 1;

        state_set KDE_PROFILE "${kde_profile}";
    else
        state_set KDE_PROFILE "none";
    fi
}

tui_select_display_manager() {
    local wm_de;
    local dm='none';

    wm_de="$(state_get WM_DE none)";

    case "${wm_de}" in
        none|dwm|i3wm|icewm|hyprland|niri|sway)
            dm=$(
                tui_menu \
                    " Display Manager " \
                    "Select display manager:" \
                    "none"     "No display manager" \
                    "lightdm"  "LightDM" \
                    "sddm"     "SDDM"
            );
            ;;
        
        *)
            dm=$(
                tui_menu \
                    " Display Manager " \
                    "Select display manager:" \
                    "lightdm"  "LightDM" \
                    "sddm"     "SDDM"
            );
            ;;
    esac

    [[ -n "${dm}" ]] || return 1;

    state_set DISPLAY_MANAGER "${dm}";
}

tui_select_xstack() {
    local wm_de;
    local stack;

    wm_de="$(state_get WM_DE none)";

    if [[ "${wm_de}" == 'none' ]]; then
        state_set X_STACK "none";
        return 0;
    fi

    stack=$(
        tui_menu \
            " Display Stack " \
            "Select display stack:" \
            "xorg"   "Traditional X.Org" \
            "xlibre" "xLibre stack"
    );

    [[ -n "${stack}" ]] || return 1;

    state_set X_STACK "${stack}";
}

tui_select_network_stack() {
    local stack;

    stack=$(
        tui_menu \
            " Networking " \
            "Select networking stack:" \
            "networkmanager" "Desktop friendly" \
            "dhcpcd+iwd"     "Minimal default" \
            "connman"        "Lightweight manager" \
            "none"           "Manual setup"
    );

    [[ -n "${stack}" ]] || return 1;

    state_set NETWORK_STACK "${stack}";
}

tui_select_audio_stack() {
    local stack;

    stack=$(
        tui_menu \
            " Audio " \
            "Select audio stack:" \
            "pipewire"   "Modern default" \
            "pulseaudio" "Legacy compatibility" \
            "none"       "No audio stack"
    );

    [[ -n "${stack}" ]] || return 1;

    state_set AUDIO_STACK "${stack}";
}

tui_select_shell() {
    local shell;

    shell=$(
        tui_menu \
            " User Shell " \
            "Select default user shell:" \
            "bash" "GNU Bash" \
            "zsh"  "Z Shell" \
            "fish" "Friendly Interactive Shell"
    );

    [[ -n "${shell}" ]] || return 1;

    state_set USER_SHELL "${shell}";
}

tui_select_extras() {
    local extras;

    extras=$(
        tui_checklist \
            " Extras " \
            "Select optional packages:" \
            "git"          "Git tools & base-devel"         on \
            "flatpak"      "Flatpak support"                off \
            "fastfetch"    "Fastfetch system info"          off \
            "ufw"          "Firewall"                       off \
            "bluez"        "Bluetooth support"              off \
            "zram-tools"   "Compressed RAM swap"            off \
            "fzf"          "Fuzzy finder"                   off \
            "zoxide"       "Smarter cd command"             off \
            "starship"     "Cross-shell prompt"             off \
            "eza"          "Modern ls replacement"          off \
            "btop"         "Modern resource monitor"        off \
            "htop"         "Interactive process viewer"     off \
            "nvtop"        "GPU process monitor"            off \
            "tmux"         "Terminal multiplexer"           off \
            "usb_modeswitch" "USB modem switching tools"    off \
            "rsvc"         "SashexSRB runit service helper" off \
            | tr -d '"' \
            | xargs
    );

    state_set EXTRAS "${extras}";
}

tui_select_luks() {
    if tui_yesno \
        " Disk Encryption " \
        "Enable LUKS full disk encryption?"; then

        state_set USE_LUKS "yes";

        local passphrase;

        passphrase=$(
            dialog --stdout \
                --insecure \
                --passwordbox \
                "Enter LUKS passphrase:" \
                10 60
        );

        [[ -n "${passphrase}" ]] || return 1;

        state_set LUKS_PASS "${passphrase}";
    else
        state_set USE_LUKS "no";
    fi
}

tui_select_arch_repos() {
    local kernel;
    local fs_type;
    local wm_de;

    kernel="$(state_get KERNEL_CHOICE linux)";
    fs_type="$(state_get FS_TYPE ext4)";
    wm_de="$(state_get WM_DE none)";

    local required='no';
    local reasons=();

    case "${kernel}" in
        linux-bazzite-bin|linux-cachyos-bore|xanmod)
            required='yes';
            reasons+=("Kernel '${kernel}' requires Arch repositories.");
            ;;
    esac

    case "${fs_type}" in
        zfs)
            required='yes';
            reasons+=("ZFS support depends on Arch repositories.");
            ;;
    esac

    case "${wm_de}" in
        hyprland|niri)
            required='yes';
            reasons+=("Selected Wayland environment may require Arch packages.");
            ;;
    esac

    if [[ "${required}" == 'yes' ]]; then
        dialog \
            --title " Arch Repositories Required " \
            --msgbox \
"Official Arch repositories will be ENABLED automatically.

Reasons:

$(printf ' - %s\n' "${reasons[@]}")" \
            15 70;

        state_set ENABLE_ARCH_REPOS "yes";
        return 0;
    fi

    if tui_yesno \
        " Arch Repositories " \
        "Enable official Arch repositories?"; then

        state_set ENABLE_ARCH_REPOS "yes";
    else
        state_set ENABLE_ARCH_REPOS "no";
    fi
}

tui_select_offline_mode() {
    local offline;

    offline=$(
        tui_menu \
            " Offline Installation " \
            "Allow offline installation?" \
            "no"  "Require internet" \
            "yes" "Allow cached/local install"
    );

    [[ -n "${offline}" ]] || return 1;

    state_set ALLOW_OFFLINE "${offline}";
}

tui_select_username() {
    local username;

    username=$(
        tui_input \
            " Username " \
            "Enter username:" \
            "artix"
    );

    [[ -n "${username}" ]] || return 1;

    state_set USER_NAME "${username}";
}

tui_select_user_password() {
    local password;

    password=$(
        dialog --stdout \
            --insecure \
            --passwordbox \
            "Enter user password:" \
            10 60
    );

    [[ -n "${password}" ]] || return 1;

    state_set USER_PASS "${password}";
}

tui_select_root_password() {
    local password;

    password=$(
        dialog --stdout \
            --insecure \
            --passwordbox \
            "Enter root password:" \
            10 60
    );

    [[ -n "${password}" ]] || return 1;

    state_set ROOT_PASS "${password}";
}

tui_select_hostname() {
    local hostname;

    hostname=$(
        tui_input \
            " Hostname " \
            "Enter system hostname:" \
            "artix"
    );

    [[ -n "${hostname}" ]] || return 1;

    if [[ ! "${hostname}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        dialog \
            --title " Invalid Hostname " \
            --msgbox \
"Hostname contains unsupported characters.

Allowed:
 - a-z
 - A-Z
 - 0-9
 - dots
 - dashes
 - underscores" \
            12 60;

        return 1;
    fi

    state_set HOSTNAME "${hostname}";
}

tui_select_timezone() {
    local timezone;

    timezone=$(
        tui_input \
            " Timezone " \
            "Enter timezone (Region/City):" \
            "Europe/Belgrade"
    );

    [[ -n "${timezone}" ]] || return 1;

    if [[ ! -f "/usr/share/zoneinfo/${timezone}" ]]; then
        dialog \
            --title " Invalid Timezone " \
            --msgbox \
"Timezone was not found on this system." \
            8 50;

        return 1;
    fi

    state_set TIMEZONE "${timezone}";
}

tui_select_locale() {
    local locale;

    locale=$(
        tui_input \
            " Locale " \
            "Enter locale:" \
            "en_US.UTF-8"
    );

    [[ -n "${locale}" ]] || return 1;

    state_set LOCALE "${locale}";
}

tui_select_keyboard_layout() {
    local keymap;

    keymap=$(
        tui_input \
            " Keyboard Layout " \
            "Enter keyboard layout:" \
            "us"
    );

    [[ -n "${keymap}" ]] || return 1;

    state_set KEYMAP "${keymap}";
}

tui_select_microcode() {
    local detected='amd-ucode';

    grep -q 'GenuineIntel' /proc/cpuinfo \
        && detected='intel-ucode';

    if tui_yesno \
        " CPU Microcode " \
        "Detected ${detected}.

Use detected microcode automatically?"; then

        state_set MICROCODE_OVERRIDE "${detected}";
        return 0;
    fi

    local microcode;

    microcode=$(
        tui_menu \
            " CPU Microcode " \
            "Select microcode package:" \
            "amd-ucode"   "AMD microcode" \
            "intel-ucode" "Intel microcode" \
            "none"        "Do not install microcode"
    );

    [[ -n "${microcode}" ]] || return 1;

    state_set MICROCODE_OVERRIDE "${microcode}";
}

tui_select_btrfs_layout() {
    local fs_type;
    local layout='standard';

    fs_type="$(state_get FS_TYPE ext4)";

    [[ "${fs_type}" == 'btrfs' ]] || return 0;

    layout=$(
        tui_menu \
            " BTRFS Layout " \
            "Select subvolume layout:" \
            "standard" "Root and home subvolumes" \
            "flat"     "Single flat subvolume layout" \
            "snapshot" "Snapshot-oriented layout"
    );

    [[ -n "${layout}" ]] || return 1;

    state_set BTRFS_LAYOUT "${layout}";
}

tui_show_sanity_warnings() {
    local warnings=();

    [[ "$(state_get FS_TYPE)" == 'exfat' ]] \
        && warnings+=("exFAT is not recommended for Linux root filesystems.")

    [[ "$(state_get KERNEL_CHOICE)" == 'linux-libre' ]] \
        && warnings+=("linux-libre may break Wi-Fi, GPU, and Bluetooth support.")

    [[ "$(state_get FS_TYPE)" == 'zfs' ]] \
        && warnings+=("ZFS support is experimental and DKMS-based.")

    [[ "$(state_get BOOTLOADER)" == 'efistub' ]] \
        && warnings+=("EFIStub requires proper firmware EFI support.")

    [[ "$(state_get WM_DE)" == 'none' ]] \
        && warnings+=("No desktop environment selected.")

    if [[ ${#warnings[@]} -eq 0 ]]; then
        return 0;
    fi

    dialog \
        --title " Sanity Warnings " \
        --msgbox \
"Please review the following warnings:

$(printf ' - %s\n' "${warnings[@]}")" \
        18 70;
}

tui_collect_install_config() {
    command -v dialog &>/dev/null \
        || pacman -Sy --noconfirm dialog;

    tui_select_disk;
    tui_select_init;
    tui_select_filesystem;
    tui_select_btrfs_layout;
    tui_select_bootloader;
    tui_select_kernel;
    tui_select_microcode;

    tui_select_desktop;
    tui_select_display_manager;
    tui_select_xstack;

    tui_select_network_stack;
    tui_select_audio_stack;

    tui_select_shell;
    tui_select_extras;
    tui_select_luks;

    tui_select_arch_repos;
    tui_select_offline_mode;

    tui_select_hostname;
    tui_select_timezone;
    tui_select_locale;
    tui_select_keyboard_layout;

    tui_select_username;
    tui_select_user_password;
    tui_select_root_password;

    tui_show_sanity_warnings;
}