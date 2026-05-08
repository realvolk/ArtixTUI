#!/usr/bin/env bash
set -Eeuo pipefail;

configure_bootloader() {
    local bootloader;
    local kernel;

    bootloader="$(state_get BOOTLOADER grub)";
    kernel="$(state_get KERNEL_CHOICE linux)";

    {
        printf '[*] Generating initramfs...\n';

        artix-chroot /mnt mkinitcpio -P;

        case "${bootloader}" in
            grub)
                printf '[*] Installing GRUB...\n';

                artix-chroot /mnt grub-install \
                    --target=x86_64-efi \
                    --efi-directory=/boot/efi \
                    --bootloader-id=ARTIX;

                printf '[*] Generating GRUB configuration...\n';

                artix-chroot /mnt grub-mkconfig \
                    -o /boot/grub/grub.cfg;
                ;;

            refind)
                printf '[*] Installing rEFInd...\n';

                artix-chroot /mnt refind-install;
                ;;

            efistub)
                printf '[*] EFIStub selected.\n';
                printf '[*] Manual boot entry setup may be required.\n';
                ;;

            *)
                die "unsupported bootloader: ${bootloader}";
                ;;
        esac;

        printf '\n[*] Bootloader setup complete.\n';
    } 2>&1 | dialog \
        --clear \
        --title " Bootloader Setup " \
        --programbox 20 85;
}