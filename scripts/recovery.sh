#!/usr/bin/env bash
set -Eeuo pipefail;

ROOT="${1:-/mnt}";

validate_recovery_root() {
    mountpoint -q "${ROOT}" \
        || die "recovery root is not mounted: ${ROOT}"

    [[ -d "${ROOT}/etc" ]] \
        || die "missing ${ROOT}/etc"

    [[ -d "${ROOT}/var/lib/pacman" ]] \
        || die "missing pacman database"
}

pacman_root_has() {
    [[ -d "${ROOT}/var/lib/pacman/local" ]] \
        || return 1

    pacman \
        --root "${ROOT}" \
        -Qq "${1}" \
        &>/dev/null
}

service_exists() {
    local path="${1}";

    [[ -e "${ROOT}/${path}" ]]
}

detect_init() {
    if [[ -d "${ROOT}/etc/runit" ]]; then
        state_set INIT runit

    elif [[ -d "${ROOT}/etc/dinit.d" ]]; then
        state_set INIT dinit

    elif [[ -d "${ROOT}/etc/s6" ]]; then
        state_set INIT s6

    else
        state_set INIT openrc
    fi
}

detect_filesystem() {
    local fs;

    fs="$(
        findmnt -no FSTYPE "${ROOT}" \
            2>/dev/null \
            || true
    )";

    [[ -n "${fs}" ]] \
        || fs='ext4';

    state_set FS_TYPE "${fs}";
}

detect_bootloader() {
    if [[ -d "${ROOT}/boot/grub" ]] \
        || [[ -f "${ROOT}/boot/grub/grub.cfg" ]]; then

        state_set BOOTLOADER grub

    elif [[ -d "${ROOT}/boot/EFI/refind" ]] \
        || [[ -f "${ROOT}/boot/refind_linux.conf" ]]; then

        state_set BOOTLOADER refind

    else
        state_set BOOTLOADER efistub
    fi
}

detect_kernel() {
    if pacman_root_has linux-zen; then
        state_set KERNEL_CHOICE linux-zen

    elif pacman_root_has linux-lts; then
        state_set KERNEL_CHOICE linux-lts

    elif pacman_root_has linux-hardened; then
        state_set KERNEL_CHOICE linux-hardened

    elif pacman_root_has linux-libre; then
        state_set KERNEL_CHOICE linux-libre

    elif pacman_root_has linux-cachyos-bore; then
        state_set KERNEL_CHOICE linux-cachyos-bore

    elif pacman_root_has linux-bazzite-bin; then
        state_set KERNEL_CHOICE linux-bazzite-bin

    elif pacman_root_has linux-xanmod-x64v4 \
        || pacman_root_has linux-xanmod-x64v3 \
        || pacman_root_has linux-xanmod-x64v2 \
        || pacman_root_has linux-xanmod; then

        state_set KERNEL_CHOICE xanmod

    elif [[ -d "${ROOT}/opt/linux-tkg" ]] \
        || pacman_root_has linux-tkg \
        || pacman_root_has linux-tkg-bore; then

        state_set KERNEL_CHOICE tkg

    else
        state_set KERNEL_CHOICE linux
    fi
}

detect_desktop() {
    if pacman_root_has mangowm; then
        state_set WM_DE mango

    elif pacman_root_has hyprland; then
        state_set WM_DE hyprland

    elif pacman_root_has niri; then
        state_set WM_DE niri

    elif pacman_root_has sway; then
        state_set WM_DE sway

    elif pacman_root_has xfce4; then
        state_set WM_DE xfce4

    elif pacman_root_has lxqt; then
        state_set WM_DE lxqt

    elif pacman_root_has lxde-common \
        || pacman_root_has lxde; then

        state_set WM_DE lxde

    elif pacman_root_has i3-wm; then
        state_set WM_DE i3wm

    elif pacman_root_has dwm; then
        state_set WM_DE dwm

    elif pacman_root_has icewm; then
        state_set WM_DE icewm

    else
        state_set WM_DE none
    fi
}

detect_display_manager() {
    if pacman_root_has sddm; then
        state_set DISPLAY_MANAGER sddm

    elif pacman_root_has lightdm; then
        state_set DISPLAY_MANAGER lightdm

    else
        state_set DISPLAY_MANAGER none
    fi
}

detect_xstack() {
    if pacman_root_has xlibre-xserver; then
        state_set X_STACK xlibre

    elif pacman_root_has xorg-server; then
        state_set X_STACK xorg

    else
        state_set X_STACK none
    fi
}

detect_seat_manager() {
    if pacman_root_has seatd; then
        state_set SEAT_MANAGER seatd
    else
        state_set SEAT_MANAGER elogind
    fi
}

detect_network_stack() {
    if pacman_root_has networkmanager; then
        state_set NETWORK_STACK networkmanager

    elif pacman_root_has connman; then
        state_set NETWORK_STACK connman

    elif pacman_root_has dhcpcd \
        || pacman_root_has iwd; then

        state_set NETWORK_STACK dhcpcd+iwd

    else
        state_set NETWORK_STACK none
    fi
}

detect_audio_stack() {
    if pacman_root_has pipewire; then
        state_set AUDIO_STACK pipewire

    elif pacman_root_has pulseaudio; then
        state_set AUDIO_STACK pulseaudio

    else
        state_set AUDIO_STACK none
    fi
}

detect_ucode() {
    if pacman_root_has intel-ucode; then
        state_set CPU_UCODE intel

    elif pacman_root_has amd-ucode; then
        state_set CPU_UCODE amd

    else
        state_set CPU_UCODE none
    fi
}

detect_user_shell() {
    local shell;

    shell="$(
        awk -F: \
            '$3 >= 1000 && $1 != "nobody" {print $7; exit}' \
            "${ROOT}/etc/passwd" \
            2>/dev/null \
            || true
    )";

    shell="${shell##*/}";

    case "${shell}" in
        bash|zsh|fish)
            ;;
        *)
            shell='bash'
            ;;
    esac

    state_set USER_SHELL "${shell}";
}

detect_extras() {
    local extras=();

    pacman_root_has git && extras+=(git)
    pacman_root_has flatpak && extras+=(flatpak)
    pacman_root_has fastfetch && extras+=(fastfetch)
    pacman_root_has ufw && extras+=(ufw)
    pacman_root_has bluez && extras+=(bluez)

    pacman_root_has zram-generator \
        || pacman_root_has zramen \
        && extras+=(zram-tools)

    pacman_root_has fzf && extras+=(fzf)
    pacman_root_has zoxide && extras+=(zoxide)
    pacman_root_has starship && extras+=(starship)
    pacman_root_has eza && extras+=(eza)
    pacman_root_has btop && extras+=(btop)
    pacman_root_has htop && extras+=(htop)
    pacman_root_has nvtop && extras+=(nvtop)
    pacman_root_has tmux && extras+=(tmux)
    pacman_root_has usb_modeswitch && extras+=(usb_modeswitch)
    pacman_root_has rsvc && extras+=(rsvc)

    state_set EXTRAS "${extras[*]}";
}

detect_repositories() {
    if grep -Eq \
        '^\[(core|extra|multilib)\]' \
        "${ROOT}/etc/pacman.conf" \
        2>/dev/null; then

        state_set ENABLE_ARCH_REPOS yes

    else
        state_set ENABLE_ARCH_REPOS no
    fi

    if grep -q '^\[chaotic-aur\]' \
        "${ROOT}/etc/pacman.conf" \
        2>/dev/null; then

        state_set HAS_CHAOTIC yes
    else
        state_set HAS_CHAOTIC no
    fi
}

detect_username() {
    local user;

    user="$(
        awk -F: \
            '$3 >= 1000 && $1 != "nobody" {print $1; exit}' \
            "${ROOT}/etc/passwd" \
            2>/dev/null \
            || true
    )";

    [[ -n "${user}" ]] \
        || user='artix';

    state_set USER_NAME "${user}";
}

detect_luks() {
    local source;
    local parent;

    source="$(
        findmnt -no SOURCE "${ROOT}" \
            2>/dev/null \
            || true
    )";

    [[ -n "${source}" ]] \
        || return 0;

    parent="$(
        lsblk -no PKNAME "${source}" \
            2>/dev/null \
            || true
    )";

    if [[ -n "${parent}" ]] \
        && cryptsetup isLuks "/dev/${parent}" \
            &>/dev/null; then

        state_set USE_LUKS yes

    else
        state_set USE_LUKS no
    fi
}

detect_disk() {
    local source;
    local pkname;

    source="$(
        findmnt -no SOURCE "${ROOT}" \
            2>/dev/null \
            || true
    )";

    [[ -n "${source}" ]] \
        || return 0;

    pkname="$(
        lsblk -no PKNAME "${source}" \
            2>/dev/null \
            || true
    )";

    if [[ -n "${pkname}" ]]; then
        state_set DISK "/dev/${pkname}";
    else
        state_set DISK "${source}";
    fi
}

detect_display_protocol() {
    if [[ -d "${ROOT}/usr/share/wayland-sessions" ]]; then
        state_set DISPLAY_PROTOCOL wayland

    elif [[ -d "${ROOT}/usr/share/xsessions" ]]; then
        state_set DISPLAY_PROTOCOL x11
    fi
}

detect_nvidia() {
    if pacman_root_has nvidia \
        || pacman_root_has nvidia-dkms \
        || pacman_root_has nvidia-open; then

        state_set GPU_DRIVER nvidia
    fi
}

detect_virtualization() {
    if pacman_root_has qemu-guest-agent; then
        state_set VM_GUEST qemu

    elif pacman_root_has virtualbox-guest-utils; then
        state_set VM_GUEST virtualbox

    elif pacman_root_has open-vm-tools; then
        state_set VM_GUEST vmware

    else
        state_set VM_GUEST none
    fi
}

detect_hostname() {
    local hostname='artix';

    [[ -f "${ROOT}/etc/hostname" ]] \
        && hostname="$(
            tr -d '[:space:]' < "${ROOT}/etc/hostname"
        )";

    state_set HOSTNAME "${hostname}";
}

reconstruct_state_from_system() {
    validate_recovery_root

    detect_disk
    detect_init
    detect_filesystem
    detect_bootloader
    detect_kernel
    detect_desktop
    detect_display_manager
    detect_xstack
    detect_seat_manager
    detect_network_stack
    detect_audio_stack
    detect_ucode
    detect_user_shell
    detect_extras
    detect_repositories
    detect_username
    detect_luks
    detect_display_protocol
    detect_nvidia
    detect_virtualization
    detect_hostname

    state_save
}