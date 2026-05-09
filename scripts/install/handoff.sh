#!/usr/bin/env bash
set -Eeuo pipefail;

prepare_handoff() {
    {
        printf '[*] Detecting boot artifacts...\n';

        local kernel_image='';
        local initramfs_image='';
        local microcode_image='';

        kernel_image="$(
            find /mnt/boot \
                -maxdepth 1 \
                -type f \
                -name 'vmlinuz-*' \
                | sort \
                | head -n1
        )";

        initramfs_image="$(
            find /mnt/boot \
                -maxdepth 1 \
                -type f \
                -name 'initramfs-*.img' \
                ! -name '*fallback*' \
                | sort \
                | head -n1
        )";

        if [[ -f /mnt/boot/intel-ucode.img ]]; then
            microcode_image='intel-ucode.img'
        elif [[ -f /mnt/boot/amd-ucode.img ]]; then
            microcode_image='amd-ucode.img'
        fi

        [[ -n "${kernel_image}" ]] \
            && state_set KERNEL_IMAGE \
                "$(basename "${kernel_image}")"

        [[ -n "${initramfs_image}" ]] \
            && state_set INITRAMFS_IMAGE \
                "$(basename "${initramfs_image}")"

        [[ -n "${microcode_image}" ]] \
            && state_set MICROCODE_IMAGE \
                "${microcode_image}"

        printf '[*] Writing installer configuration...\n';

        cat <<EOF > /mnt/etc/artix-installer.conf
INIT="$(state_get INIT)"
KERNEL_CHOICE="$(state_get KERNEL_CHOICE)"
KERNEL_IMAGE="$(state_get KERNEL_IMAGE)"
INITRAMFS_IMAGE="$(state_get INITRAMFS_IMAGE)"
MICROCODE_IMAGE="$(state_get MICROCODE_IMAGE)"
BOOTLOADER="$(state_get BOOTLOADER)"
WM_DE="$(state_get WM_DE)"
NETWORK_STACK="$(state_get NETWORK_STACK)"
X_STACK="$(state_get X_STACK)"
ENABLE_ARCH_REPOS="$(state_get ENABLE_ARCH_REPOS)"
EOF

        printf '[*] Copying post-install modules...\n';

        mkdir -p \
            /mnt/usr/local/lib/artix-installer;

        cp -r ./scripts/post \
            /mnt/usr/local/lib/artix-installer/;

        cp ./scripts/install/services.sh \
            /mnt/usr/local/lib/artix-installer/services.sh;

        printf '\n[*] Handoff preparation complete.\n';
    } 2>&1 | dialog \
        --clear \
        --title " Handoff " \
        --programbox 20 85;
}