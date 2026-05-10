#!/usr/bin/env bash
set -Eeuo pipefail;

prepare_handoff() {
    local script_dir;
    local kernel_image='';
    local initramfs_image='';
    local microcode_image='';

    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)";

    {
        printf '[*] Detecting boot artifacts...\n';

        mapfile -t kernels < <(
            find /mnt/boot \
                -maxdepth 1 \
                -type f \
                -name 'vmlinuz-*' \
                2>/dev/null \
                | sort
        );

        mapfile -t initramfses < <(
            find /mnt/boot \
                -maxdepth 1 \
                -type f \
                -name 'initramfs-*.img' \
                ! -name '*fallback*' \
                2>/dev/null \
                | sort
        );

        [[ ${#kernels[@]} -gt 0 ]] \
            && kernel_image="${kernels[0]}";

        [[ ${#initramfses[@]} -gt 0 ]] \
            && initramfs_image="${initramfses[0]}";

        if [[ -f /mnt/boot/intel-ucode.img ]]; then
            microcode_image='intel-ucode.img'
        elif [[ -f /mnt/boot/amd-ucode.img ]]; then
            microcode_image='amd-ucode.img'
        fi

        [[ -n "${kernel_image}" ]] \
            && state_set KERNEL_IMAGE \
                "$(basename -- "${kernel_image}")"

        [[ -n "${initramfs_image}" ]] \
            && state_set INITRAMFS_IMAGE \
                "$(basename -- "${initramfs_image}")"

        [[ -n "${microcode_image}" ]] \
            && state_set MICROCODE_IMAGE \
                "${microcode_image}"

        printf '[*] Writing installer configuration...\n';

        install -Dm600 /dev/null \
            /mnt/etc/artix-installer.conf;

        cat <<EOF > /mnt/etc/artix-installer.conf
DISK="$(state_get DISK)"
FS_TYPE="$(state_get FS_TYPE)"

INIT="$(state_get INIT)"

USE_LUKS="$(state_get USE_LUKS)"
LUKS_PASS="$(state_get LUKS_PASS)"

BOOTLOADER="$(state_get BOOTLOADER)"

DISPLAY_MANAGER="$(state_get DISPLAY_MANAGER)"
AUDIO_STACK="$(state_get AUDIO_STACK)"

SWAP_ENABLED="$(state_get SWAP_ENABLED)"
SWAP_SIZE="$(state_get SWAP_SIZE)"

EXTRAS="$(state_get EXTRAS)"

KERNEL_CHOICE="$(state_get KERNEL_CHOICE)"
KERNEL_IMAGE="$(state_get KERNEL_IMAGE)"
INITRAMFS_IMAGE="$(state_get INITRAMFS_IMAGE)"
MICROCODE_IMAGE="$(state_get MICROCODE_IMAGE)"

WM_DE="$(state_get WM_DE)"

USER_NAME="$(state_get USER_NAME)"
USER_PASS="$(state_get USER_PASS)"
ROOT_PASS="$(state_get ROOT_PASS)"

USER_SHELL="$(state_get USER_SHELL)"

NETWORK_STACK="$(state_get NETWORK_STACK)"
ALLOW_OFFLINE="$(state_get ALLOW_OFFLINE)"

X_STACK="$(state_get X_STACK)"

ENABLE_ARCH_REPOS="$(state_get ENABLE_ARCH_REPOS)"
EOF

        chmod 600 /mnt/etc/artix-installer.conf;

        printf '[*] Copying post-install modules...\n';

        install -d \
            /mnt/usr/local/lib/artix-installer;

        cp -r \
            "${script_dir}/../post/." \
            /mnt/usr/local/lib/artix-installer/post;

        cp \
            "${script_dir}/services.sh" \
            /mnt/usr/local/lib/artix-installer/services.sh;

        printf '\n[*] Handoff preparation complete.\n';
    } 2>&1 | dialog \
        --clear \
        --title " Handoff " \
        --programbox 20 85
}