#!/usr/bin/env bash
set -Eeuo pipefail;

prepare_handoff() {
    {
        printf '[*] Writing installer configuration...\n';

        cat <<EOF > /mnt/etc/artix-installer.conf
INIT="$(state_get INIT)"
KERNEL_CHOICE="$(state_get KERNEL_CHOICE)"
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