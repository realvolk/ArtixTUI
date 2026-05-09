#!/usr/bin/env bash
set -Eeuo pipefail;

configure_bootloader() {
    local bootloader;
    local kernel;

    bootloader="$(state_get BOOTLOADER grub)";
    kernel="$(state_get KERNEL_CHOICE linux)";

    {
        printf '[*] Generating initramfs...\n';

        if ! artix-chroot /mnt mkinitcpio -P; then
            die 'failed to generate initramfs';
        fi

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
                local root_source;
                local root_uuid;
                local esp_source;
                local esp_disk;
                local esp_part;
                local kernel_image;
                local initramfs_image;
                local microcode_image='';
                local cmdline;
                local loader;

                printf '[*] Configuring EFIStub boot entry...\n';

                root_source="$(findmnt -no SOURCE /mnt)";
                esp_source="$(findmnt -no SOURCE /mnt/boot/efi)";

                [[ -n "${root_source}" ]] \
                    || die 'failed to detect root partition';

                [[ -n "${esp_source}" ]] \
                    || die 'failed to detect EFI partition';

                root_uuid="$(
                    blkid -s UUID -o value "${root_source}"
                )";

                [[ -n "${root_uuid}" ]] \
                    || die 'failed to detect root UUID';

                esp_disk="$(
                    lsblk -no PKNAME "${esp_source}" \
                        | head -n1
                )";

                [[ -n "${esp_disk}" ]] \
                    || die 'failed to detect EFI parent disk';

                esp_disk="/dev/${esp_disk}";

                esp_part="$(
                    lsblk -no PARTNUM "${esp_source}" \
                        | head -n1
                )";

                [[ -n "${esp_part}" ]] \
                    || die 'failed to detect EFI partition number';

                kernel_image="$(
                    find /mnt/boot \
                        -maxdepth 1 \
                        -type f \
                        -name 'vmlinuz-*' \
                        | sort \
                        | head -n1
                )";

                [[ -n "${kernel_image}" ]] \
                    || die 'failed to locate kernel image';

                initramfs_image="$(
                    find /mnt/boot \
                        -maxdepth 1 \
                        -type f \
                        -name 'initramfs-*.img' \
                        ! -name '*fallback*' \
                        | sort \
                        | head -n1
                )";

                [[ -n "${initramfs_image}" ]] \
                    || die 'failed to locate initramfs image';

                if [[ -f /mnt/boot/intel-ucode.img ]]; then
                    microcode_image='initrd=\intel-ucode.img'
                elif [[ -f /mnt/boot/amd-ucode.img ]]; then
                    microcode_image='initrd=\amd-ucode.img'
                fi

                loader="\\$(basename "${kernel_image}")"

                cmdline="root=UUID=${root_uuid} rw"

                if [[ -n "${microcode_image}" ]]; then
                    cmdline+=" ${microcode_image}"
                fi

                cmdline+=" initrd=\\$(basename "${initramfs_image}")"

                printf '[*] Kernel image: %s\n' \
                    "$(basename "${kernel_image}")";

                printf '[*] Initramfs image: %s\n' \
                    "$(basename "${initramfs_image}")";

                printf '[*] Creating EFI boot entry...\n';

                artix-chroot /mnt efibootmgr \
                    --create \
                    --disk "${esp_disk}" \
                    --part "${esp_part}" \
                    --label 'Artix Linux' \
                    --loader "${loader}" \
                    --unicode "${cmdline}" \
                    --verbose;

                printf '[*] Verifying EFI boot entries...\n';

                if ! artix-chroot /mnt efibootmgr -v \
                    | grep -qi 'Artix Linux'; then

                    die 'failed to verify EFI boot entry';
                fi
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