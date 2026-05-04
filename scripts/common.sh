#!/usr/bin/env bash

_error_exit() {
    local reason="${1}";
    printf "%b%s%b\n" "\e[1;31m" "${reason^}" "\e[m" >&2;
    exit 1;
}

_check_internet() {
    ping -c 1 8.8.8.8 &>/dev/null || _error_exit "no internet connection";
}

_pacman_tui() {
    local title="${1}";
    shift;
    pacman -S --noconfirm --needed "$@" 2>&1 | dialog --title "${title}" --programbox 20 80;
}


_get_cpu_ucode() {
    local ucode="amd-ucode";
    grep -q "GenuineIntel" /proc/cpuinfo && ucode="intel-ucode";
    echo "${ucode}";
}

_is_efi() {
    [[ -d /sys/firmware/efi ]] || _error_exit "system is not booted in UEFI mode";
}

_save_state() {
    cat <<EOF > /tmp/artix_install_state.conf
DISK="${DISK}"
FS_TYPE="${FS_TYPE}"
INIT="${INIT}"
USE_LUKS="${USE_LUKS}"
LUKS_PASS="${LUKS_PASS:-}"
BOOTLOADER="${BOOTLOADER}"
KERNEL_CHOICE="${KERNEL_CHOICE}"
WM_DE="${WM_DE}"
USER_NAME="${USER_NAME}"
USER_PASS="${USER_PASS}"
ROOT_PASS="${ROOT_PASS}"
USER_SHELL="${USER_SHELL:-/bin/bash}"
EOF
    chmod 600 /tmp/artix_install_state.conf
}


_load_state() {
    if [[ -f /tmp/artix_install_state.conf ]]; then
        source /tmp/artix_install_state.conf;
    fi
    return 0;
}

_get_partition_name() {
    local disk="${1}";
    local part="${2}";
    if [[ "${disk}" =~ (nvme|mmcblk|loop) ]]; then
        echo "${disk}p${part}";
    else
        echo "${disk}${part}";
    fi
}

_ensure_tools() {
    local pkgs=();
    command -v sgdisk >/dev/null || pkgs+=("gptfdisk");
    command -v cryptsetup >/dev/null || pkgs+=("cryptsetup");
    [[ "${FS_TYPE}" == "btrfs" ]] && ! command -v mkfs.btrfs >/dev/null && pkgs+=("btrfs-progs");
    command -v mkfs.fat >/dev/null || pkgs+=("dosfstools");
    command -v efibootmgr >/dev/null || pkgs+=("efibootmgr");

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        _pacman_tui "Installing Essential Tools" "${pkgs[@]}";
    fi
}
