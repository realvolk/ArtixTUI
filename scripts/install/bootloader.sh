#!/usr/bin/env bash
set -Eeuo pipefail

configure_bootloader() {
    local bootloader kernel fs_type root_param=''
    bootloader="$(state_get BOOTLOADER grub)"
    kernel="$(state_get KERNEL_CHOICE linux)"
    fs_type="$(state_get FS_TYPE)"
    [[ "${fs_type}" == 'zfs' ]] && root_param='root=ZFS=zroot/root'

    log_info "Generating initramfs..."
    artix-chroot /mnt mkinitcpio -P || die 'failed to generate initramfs'
    local root_device
    root_device=$(artix-chroot /mnt findmnt -n -o SOURCE /) || true
    [[ -n "${root_device}" ]] || die 'failed to detect root device'

    case "${bootloader}" in
        grub)
            log_info "Installing GRUB..."
            findmnt -rn -o FSTYPE /mnt/boot/efi | grep -qx 'vfat' || die 'EFI partition not mounted as vfat'

            if [[ "${fs_type}" == "xfs" ]]; then
                log_info "Verifying XFS features for GRUB compatibility..."
                if artix-chroot /mnt xfs_info "${root_device}" 2>/dev/null | grep -q 'bigtime=1'; then
                    die "XFS bigtime is enabled and may be incompatible with older GRUB builds."
                fi
            fi

            artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARTIX || die 'grub-install failed'
            if [[ -n "${root_param}" ]]; then
                artix-chroot /mnt sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${root_param}\"|" /etc/default/grub
            fi
            log_info "Generating GRUB configuration..."
            artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || die 'grub-mkconfig failed'
            ;;
        refind)
            log_info "Installing rEFInd..."
            findmnt -rn -o FSTYPE /mnt/boot/efi | grep -qx 'vfat' || die 'EFI partition not mounted as vfat'
            local refind_root_param
            if [[ -n "${root_param}" ]]; then
                refind_root_param="${root_param}"
            else
                local refind_root_device refind_root_uuid
                refind_root_device=$(findmnt -n -o SOURCE --target /mnt)
                refind_root_uuid=$(blkid -s UUID -o value "${refind_root_device}")
                refind_root_param="root=UUID=${refind_root_uuid}"
            fi
            artix-chroot /mnt bash -c "echo \"${refind_root_param} rw\" > /boot/refind_linux.conf"
            artix-chroot /mnt refind-install || die 'refind-install failed'
            ;;
        efistub)
            log_info "Configuring EFIStub boot entry..."
            command -v efibootmgr >/dev/null 2>&1 || die 'efibootmgr unavailable'
            local root_source root_uuid esp_source esp_mount esp_disk esp_part
            root_source="$(findmnt -rn -o SOURCE --target /mnt)"
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
            local cmdline

            if [[ "${fs_type}" == 'zfs' ]]; then
                cmdline="root=ZFS=zroot/root rw"
            else
                cmdline="root=UUID=${root_uuid} rw"
            fi

            [[ -n "${microcode_image_str:-}" ]] && \
                cmdline+=" ${microcode_image_str}"

            cmdline+=" initrd=\\EFI\\Artix\\${initramfs_basename}"

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