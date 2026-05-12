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

                if ! findmnt -rn -o FSTYPE /mnt/boot/efi \
                    | grep -qx 'vfat'; then

                    die 'EFI partition is not mounted as vfat at /boot/efi';
                fi

                if ! artix-chroot /mnt grub-install \
                    --target=x86_64-efi \
                    --efi-directory=/boot/efi \
                    --bootloader-id=ARTIX; then

                    die 'grub-install failed';
                fi

                printf '[*] Generating GRUB configuration...\n';

                if ! artix-chroot /mnt grub-mkconfig \
                    -o /boot/grub/grub.cfg; then

                    die 'grub-mkconfig failed';
                fi
                ;;

            refind)
                printf '[*] Installing rEFInd...\n';

                if ! artix-chroot /mnt refind-install; then
                    die 'refind-install failed';
                fi
                ;;

            efistub)
                local root_source;
                local root_uuid;
                local esp_source='';
                local esp_mount='';
                local esp_disk;
                local esp_part;
                local kernel_image;
                local initramfs_image;
                local microcode_image='';
                local cmdline;
                local loader;
                local kernel_basename;
                local initramfs_basename;
                local esp_artix_dir;
                local microcode_file;

                printf '[*] Configuring EFIStub boot entry...\n';

                command -v efibootmgr >/dev/null 2>&1 \
                    || die 'efibootmgr is unavailable';

                root_source="$(findmnt -rn -o SOURCE /mnt)";

                [[ -n "${root_source}" ]] \
                    || die 'failed to detect root partition';

                [[ -b "${root_source}" ]] \
                    || die 'invalid root block device';

                root_uuid="$(
                    blkid -s UUID -o value "${root_source}"
                )";

                [[ -n "${root_uuid}" ]] \
                    || die 'failed to detect root UUID';

                for esp_mount in \
                    /mnt/boot/efi \
                    /mnt/efi \
                    /mnt/boot; do

                    if findmnt -rn -o FSTYPE "${esp_mount}" \
                        | grep -qx 'vfat'; then

                        esp_source="$(
                            findmnt -rn -o SOURCE "${esp_mount}"
                        )";

                        break;
                    fi
                done

                [[ -n "${esp_source}" ]] \
                    || die 'failed to detect EFI partition';

                printf '[*] EFI partition mount: %s\n' \
                    "${esp_mount}";

                printf '[*] EFI partition source: %s\n' \
                    "${esp_source}";

                esp_disk="$(
                    lsblk -no PKNAME "${esp_source}" \
                        | head -n1
                )";

                [[ -n "${esp_disk}" ]] \
                    || die 'failed to detect EFI parent disk';

                esp_disk="/dev/${esp_disk}";

                esp_part="$(
                    lsblk -no PARTN "${esp_source}" \
                        | head -n1
                )";

                [[ -n "${esp_part}" ]] \
                    || die 'failed to detect EFI partition number';

                kernel_image="/mnt/boot/$(state_get KERNEL_IMAGE)";
                initramfs_image="/mnt/boot/$(state_get INITRAMFS_IMAGE)";
                microcode_file="$(state_get MICROCODE_IMAGE)";

                [[ -f "${kernel_image}" ]] \
                    || die 'failed to locate kernel image';

                [[ -f "${initramfs_image}" ]] \
                    || die 'failed to locate initramfs image';

                kernel_basename="$(basename "${kernel_image}")";
                initramfs_basename="$(basename "${initramfs_image}")";

                esp_artix_dir="${esp_mount}/EFI/Artix";

                printf '[*] Preparing EFI directory...\n';

                mkdir -p "${esp_artix_dir}";

                printf '[*] Copying kernel artifacts to EFI partition...\n';

                cp -f "${kernel_image}" \
                    "${esp_artix_dir}/${kernel_basename}";

                cp -f "${initramfs_image}" \
                    "${esp_artix_dir}/${initramfs_basename}";

                if [[ -n "${microcode_file}" ]] \
                    && [[ -f "/mnt/boot/${microcode_file}" ]]; then

                    cp -f "/mnt/boot/${microcode_file}" \
                        "${esp_artix_dir}/${microcode_file}";

                    microcode_image="initrd=\\EFI\\Artix\\${microcode_file}"
                fi

                loader="\\EFI\\Artix\\${kernel_basename}"

                cmdline="root=UUID=${root_uuid} rw"

                if [[ -n "${microcode_image}" ]]; then
                    cmdline+=" ${microcode_image}"
                fi

                cmdline+=" initrd=\\EFI\\Artix\\${initramfs_basename}"

                printf '[*] Kernel image: %s\n' \
                    "${kernel_basename}";

                printf '[*] Initramfs image: %s\n' \
                    "${initramfs_basename}";

                if [[ -n "${microcode_file}" ]]; then
                    printf '[*] Microcode image: %s\n' \
                        "${microcode_file}";
                fi

                printf '[*] Creating EFI boot entry...\n';

                if ! artix-chroot /mnt efibootmgr \
                    --create \
                    --disk "${esp_disk}" \
                    --part "${esp_part}" \
                    --label 'Artix Linux' \
                    --loader "${loader}" \
                    --unicode "${cmdline}" \
                    --verbose; then

                    die 'failed to create EFI boot entry';
                fi

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