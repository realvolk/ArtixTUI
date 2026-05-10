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

                printf '[*] Configuring EFIStub boot entry...\n';

                root_source="$(findmnt -rn -o SOURCE /mnt)";

                [[ -n "${root_source}" ]] \
                    || die 'failed to detect root partition';

                for esp_mount in \
                    /mnt/boot/efi \
                    /mnt/efi \
                    /mnt/boot; do

                    if findmnt -rn "${esp_mount}" >/dev/null 2>&1; then
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

                kernel_basename="$(basename "${kernel_image}")";
                initramfs_basename="$(basename "${initramfs_image}")";

                if [[ "${esp_mount}" != '/mnt/boot' ]]; then
                    printf '[*] Copying kernel artifacts to EFI partition...\n';

                    cp -f "${kernel_image}" \
                        "${esp_mount}/${kernel_basename}";

                    cp -f "${initramfs_image}" \
                        "${esp_mount}/${initramfs_basename}";

                    if [[ -f /mnt/boot/intel-ucode.img ]]; then
                        cp -f /mnt/boot/intel-ucode.img \
                            "${esp_mount}/intel-ucode.img";

                        microcode_image='initrd=\intel-ucode.img'
                    elif [[ -f /mnt/boot/amd-ucode.img ]]; then
                        cp -f /mnt/boot/amd-ucode.img \
                            "${esp_mount}/amd-ucode.img";

                        microcode_image='initrd=\amd-ucode.img'
                    fi
                else
                    if [[ -f /mnt/boot/intel-ucode.img ]]; then
                        microcode_image='initrd=\intel-ucode.img'
                    elif [[ -f /mnt/boot/amd-ucode.img ]]; then
                        microcode_image='initrd=\amd-ucode.img'
                    fi
                fi

                loader="\\${kernel_basename}"

                cmdline="root=UUID=${root_uuid} rw"

                if [[ -n "${microcode_image}" ]]; then
                    cmdline+=" ${microcode_image}"
                fi

                cmdline+=" initrd=\\${initramfs_basename}"

                printf '[*] Kernel image: %s\n' \
                    "${kernel_basename}";

                printf '[*] Initramfs image: %s\n' \
                    "${initramfs_basename}";

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