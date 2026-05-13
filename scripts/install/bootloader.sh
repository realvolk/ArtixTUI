#!/usr/bin/env bash
set -Eeuo pipefail

configure_bootloader() {
    local bootloader kernel
    bootloader="$(state_get BOOTLOADER grub)"
    kernel="$(state_get KERNEL_CHOICE linux)"

    log_info "Generating initramfs..."
    artix-chroot /mnt mkinitcpio -P || die 'failed to generate initramfs'

    case "${bootloader}" in
        grub)
            log_info "Installing GRUB..."
            findmnt -rn -o FSTYPE /mnt/boot/efi | grep -qx 'vfat' || die 'EFI partition not mounted as vfat'
            artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARTIX || die 'grub-install failed'
            log_info "Generating GRUB configuration..."
            artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || die 'grub-mkconfig failed'
            ;;
        refind)
            log_info "Installing rEFInd..."
            findmnt -rn -o FSTYPE /mnt/boot/efi | grep -qx 'vfat' || die 'EFI partition not mounted as vfat'
            artix-chroot /mnt refind-install || die 'refind-install failed'
            ;;
        efistub)
            log_info "Configuring EFIStub boot entry..."
            command -v efibootmgr >/dev/null 2>&1 || die 'efibootmgr unavailable'
            local root_source root_uuid esp_source esp_mount esp_disk esp_part
            root_source="$(findmnt -rn -o SOURCE /mnt)"
            [[ -n "${root_source}" ]] || die 'failed to detect root partition'
            [[ -b "${root_source}" ]] || die 'invalid root block device'
            root_uuid="$(blkid -s UUID -o value "${root_source}")"
            [[ -n "${root_uuid}" ]] || die 'failed to detect root UUID'

            for esp_mount in /mnt/boot/efi /mnt/efi /mnt/boot; do
                if findmnt -rn -o FSTYPE "${esp_mount}" | grep -qx 'vfat'; then
                    esp_source="$(findmnt -rn -o SOURCE "${esp_mount}")"
                    break
                fi
            done
            [[ -n "${esp_source}" ]] || die 'failed to detect EFI partition'
            log_info "EFI partition mount: ${esp_mount}"
            esp_disk="/dev/$(lsblk -no PKNAME "${esp_source}" | head -n1)"
            esp_part="$(lsblk -no PARTN "${esp_source}" | head -n1)"
            [[ -n "${esp_part}" ]] || die 'failed to detect EFI partition number'

            local kernel_image="/mnt/boot/$(state_get KERNEL_IMAGE)"
            local initramfs_image="/mnt/boot/$(state_get INITRAMFS_IMAGE)"
            local microcode_file="$(state_get MICROCODE_IMAGE)"
            [[ -f "${kernel_image}" ]] || die 'failed to locate kernel image'
            [[ -f "${initramfs_image}" ]] || die 'failed to locate initramfs image'

            local kernel_basename initramfs_basename microcode_image_str
            kernel_basename="$(basename "${kernel_image}")"
            initramfs_basename="$(basename "${initramfs_image}")"
            local esp_artix_dir="${esp_mount}/EFI/Artix"
            mkdir -p "${esp_artix_dir}"
            cp -f "${kernel_image}" "${esp_artix_dir}/${kernel_basename}"
            cp -f "${initramfs_image}" "${esp_artix_dir}/${initramfs_basename}"

            if [[ -n "${microcode_file}" && -f "/mnt/boot/${microcode_file}" ]]; then
                cp -f "/mnt/boot/${microcode_file}" "${esp_artix_dir}/${microcode_file}"
                microcode_image_str="initrd=\\EFI\\Artix\\${microcode_file}"
            fi

            local loader="\\EFI\\Artix\\${kernel_basename}"
            local cmdline="root=UUID=${root_uuid} rw ${microcode_image_str} initrd=\\EFI\\Artix\\${initramfs_basename}"

            log_info "Creating EFI boot entry..."
            artix-chroot /mnt efibootmgr --create --disk "${esp_disk}" --part "${esp_part}" \
                --label 'Artix Linux' --loader "${loader}" --unicode "${cmdline}" --verbose || die 'failed to create EFI boot entry'

            log_info "Verifying EFI boot entries..."
            artix-chroot /mnt efibootmgr -v | grep -qi 'Artix Linux' || die 'failed to verify EFI boot entry'
            ;;
        *)
            die "unsupported bootloader: ${bootloader}" ;;
    esac

    log_info "Bootloader setup complete."
}