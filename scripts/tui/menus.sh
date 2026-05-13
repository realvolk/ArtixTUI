#!/usr/bin/env bash
set -Eeuo pipefail

tui_select_disk() {
    local disk disks=()
    while IFS=' ' read -r name size model; do
        disks+=("${name} - ${size} (${model:-Unknown})")
    done < <(lsblk -dpno NAME,SIZE,MODEL -e 7)

    disk=$(tui_menu "Disk Selection" "Choose target drive:" "${disks[@]}") || return 1
    disk="${disk%% *}"
    state_set DISK "${disk}"
}

tui_select_init() {
    local init
    init=$(tui_menu "Init System" "Select init system:" \
        "OpenRC" "runit" "dinit" "s6") || return 1
    state_set INIT "${init,,}"
}

tui_select_filesystem() {
    local fs
    fs=$(tui_menu "Filesystem" "Select filesystem:" \
        "ext4" "btrfs" "xfs" "f2fs" "bcachefs" "exfat" "zfs") || return 1

    if [[ "${fs}" == "zfs" ]]; then
        pacman -Si zfs-utils &>/dev/null || {
            tui_msg "ZFS Unavailable" "ZFS packages unavailable. Check repositories."; return 1
        }
    elif [[ "${fs}" == "bcachefs" ]]; then
        pacman -Si bcachefs-tools &>/dev/null || {
            tui_msg "bcachefs Unavailable" "bcachefs tools unavailable."; return 1
        }
    fi
    state_set FS_TYPE "${fs}"
}

tui_select_bootloader() {
    local bl
    bl=$(tui_menu "Bootloader" "Select bootloader:" "GRUB" "rEFInd" "EFIStub") || return 1
    state_set BOOTLOADER "${bl,,}"
}

tui_select_kernel() {
    local k
    k=$(tui_menu "Kernel" "Select kernel:" \
        "linux" "linux-zen" "linux-lts" "linux-hardened" "linux-libre" \
        "linux-cachyos-bore" "linux-bazzite-bin" "xanmod" "tkg") || return 1
    state_set KERNEL_CHOICE "${k}"
}

tui_select_desktop() {
    local d
    d=$(tui_menu "Desktop Environment" "Select desktop:" \
        "xfce4" "lxqt" "kde" "lxde" "mango" "hyprland" "niri" "sway" \
        "i3wm" "dwm" "icewm" "none") || return 1
    state_set WM_DE "${d}"

    if [[ "${d}" == "kde" ]]; then
        local profile
        profile=$(tui_menu "KDE Profile" "Select KDE Plasma profile:" \
            "minimal" "desktop" "full") || return 1
        state_set KDE_PROFILE "${profile}"
    else
        state_set KDE_PROFILE "none"
    fi
}

tui_select_display_manager() {
    local wm dm
    wm="$(state_get WM_DE none)"
    if [[ "${wm}" =~ ^(none|dwm|i3wm|icewm|hyprland|mango|niri|sway)$ ]]; then
        dm=$(tui_menu "Display Manager" "Select display manager:" "None" "LightDM" "SDDM") || return 1
    else
        dm=$(tui_menu "Display Manager" "Select display manager:" "LightDM" "SDDM") || return 1
    fi
    state_set DISPLAY_MANAGER "${dm,,}"
}

tui_select_xstack() {
    local wm stack
    wm="$(state_get WM_DE none)"
    if [[ "${wm}" == "none" ]]; then
        state_set X_STACK "none"
        return 0
    fi
    stack=$(tui_menu "Display Stack" "Select display stack:" "X.Org" "xLibre") || return 1
    state_set X_STACK "${stack,,}"
}

tui_select_network_stack() {
    local ns
    ns=$(tui_menu "Networking" "Select network stack:" \
        "NetworkManager" "dhcpcd+iwd" "ConnMan" "None") || return 1
    state_set NETWORK_STACK "${ns,,}"
}

tui_select_audio_stack() {
    local as
    as=$(tui_menu "Audio" "Select audio stack:" "PipeWire" "PulseAudio" "None") || return 1
    state_set AUDIO_STACK "${as,,}"
}

tui_select_shell() {
    local s
    s=$(tui_menu "User Shell" "Select default shell:" "bash" "zsh" "fish") || return 1
    state_set USER_SHELL "${s}"
}

tui_select_extras() {
    local extras
    extras=$(tui_checklist "Extras" "Select optional packages:" \
        "git" "flatpak" "fastfetch" "ufw" "bluez" "zram-tools" \
        "fzf" "zoxide" "starship" "eza" "btop" "htop" "nvtop" \
        "tmux" "usb_modeswitch" "rsvc") || return 1
    state_set EXTRAS "${extras//$'\n'/ }"
}

tui_select_luks() {
    if tui_yesno "Disk Encryption" "Enable LUKS full disk encryption?"; then
        state_set USE_LUKS "yes"
        local pass
        pass=$(tui_password_confirm "LUKS Passphrase" "Enter passphrase:" "Confirm passphrase:") || return 1
        state_set LUKS_PASS "${pass}"
    else
        state_set USE_LUKS "no"
    fi
}

tui_select_arch_repos() {
    local kernel fs_type wm_de required='no' reasons=()
    kernel="$(state_get KERNEL_CHOICE linux)"
    fs_type="$(state_get FS_TYPE ext4)"
    wm_de="$(state_get WM_DE none)"

    case "${kernel}" in
        linux-bazzite-bin|linux-cachyos-bore|xanmod) required='yes'; reasons+=("Kernel ${kernel}") ;;
    esac
    case "${fs_type}" in
        zfs) required='yes'; reasons+=("ZFS filesystem") ;;
    esac
    case "${wm_de}" in
        hyprland|niri) required='yes'; reasons+=("${wm_de} may need Arch packages") ;;
    esac

    if [[ "${required}" == "yes" ]]; then
        local reason_list
        reason_list=$(printf ' - %s\n' "${reasons[@]}")
        tui_msg "Arch Repositories Required" "Enabling official Arch repositories because:\n${reason_list}"
        state_set ENABLE_ARCH_REPOS "yes"
        return 0
    fi

    if tui_yesno "Arch Repositories" "Enable official Arch repositories?"; then
        state_set ENABLE_ARCH_REPOS "yes"
    else
        state_set ENABLE_ARCH_REPOS "no"
    fi
}

tui_select_offline_mode() {
    local off
    off=$(tui_menu "Offline Installation" "Allow offline installation?" "No (require internet)" "Yes (cached install)") || return 1
    case "${off}" in
        Yes*) state_set ALLOW_OFFLINE "yes" ;;
        *)     state_set ALLOW_OFFLINE "no" ;;
    esac
}

tui_select_username() {
    local u
    u=$(tui_input "Username" "Enter username:" "artix") || return 1
    state_set USER_NAME "${u}"
}

tui_select_user_password() {
    local pass
    pass=$(tui_password_confirm "User Password" "Enter user password:" "Confirm password:") || return 1
    state_set USER_PASS "${pass}"
}

tui_select_root_password() {
    local pass
    pass=$(tui_password_confirm "Root Password" "Enter root password:" "Confirm password:") || return 1
    state_set ROOT_PASS "${pass}"
}

tui_select_hostname() {
    local h
    while true; do
        h=$(tui_input "Hostname" "Enter system hostname:" "artix") || return 1
        if [[ "${h}" =~ ^[a-zA-Z0-9][a-zA-Z0-9\-]*$ ]]; then break; fi
        tui_msg "Invalid Hostname" "Allowed: a-z, A-Z, 0-9, dash. Start with letter/digit."
    done
    state_set HOSTNAME "${h}"
}

tui_select_timezone() {
    local tz
    while true; do
        tz=$(tui_input "Timezone" "Enter timezone (Region/City):" "Europe/Belgrade") || return 1
        if [[ -f "/usr/share/zoneinfo/${tz}" ]]; then break; fi
        tui_msg "Invalid Timezone" "Timezone not found. Example: Europe/London"
    done
    state_set TIMEZONE "${tz}"
}

tui_select_locale() {
    local l
    l=$(tui_input "Locale" "Enter locale:" "en_US.UTF-8") || return 1
    state_set LOCALE "${l}"
}

tui_select_keyboard_layout() {
    local k
    k=$(tui_input "Keyboard Layout" "Enter keyboard layout:" "us") || return 1
    state_set KEYMAP "${k}"
}

tui_select_microcode() {
    local detected='amd-ucode'
    grep -q 'GenuineIntel' /proc/cpuinfo && detected='intel-ucode'

    if tui_yesno "CPU Microcode" "Detected ${detected}. Use automatically?"; then
        state_set MICROCODE_OVERRIDE "${detected}"
        return 0
    fi
    local u
    u=$(tui_menu "CPU Microcode" "Select microcode:" "amd-ucode" "intel-ucode" "none") || return 1
    state_set MICROCODE_OVERRIDE "${u}"
}

tui_select_btrfs_layout() {
    local fs_type
    fs_type="$(state_get FS_TYPE ext4)"
    [[ "${fs_type}" == "btrfs" ]] || return 0
    local layout
    layout=$(tui_menu "BTRFS Layout" "Select subvolume layout:" "standard" "flat" "snapshot") || return 1
    state_set BTRFS_LAYOUT "${layout}"
}

tui_show_sanity_warnings() {
    local warnings=()
    [[ "$(state_get FS_TYPE)" == "exfat" ]] && warnings+=("exFAT not recommended for root")
    [[ "$(state_get KERNEL_CHOICE)" == "linux-libre" ]] && warnings+=("linux-libre may lack hardware support")
    [[ "$(state_get FS_TYPE)" == "zfs" ]] && warnings+=("ZFS is experimental")
    [[ "$(state_get BOOTLOADER)" == "efistub" ]] && warnings+=("EFIStub needs compatible firmware")
    [[ "$(state_get WM_DE)" == "none" ]] && warnings+=("No desktop selected")

    if [[ ${#warnings[@]} -gt 0 ]]; then
        local msg
        msg=$(printf ' - %s\n' "${warnings[@]}")
        tui_msg "Sanity Warnings" "${msg}"
    fi
}

tui_collect_install_config() {
    tui_select_disk
    tui_select_init
    tui_select_filesystem
    tui_select_btrfs_layout
    tui_select_bootloader
    tui_select_kernel
    tui_select_microcode
    tui_select_desktop
    tui_select_display_manager
    tui_select_xstack
    tui_select_network_stack
    tui_select_audio_stack
    tui_select_shell
    tui_select_extras
    tui_select_luks
    tui_select_arch_repos
    tui_select_offline_mode
    tui_select_hostname
    tui_select_timezone
    tui_select_locale
    tui_select_keyboard_layout
    tui_select_username
    tui_select_user_password
    tui_select_root_password
    tui_show_sanity_warnings
}