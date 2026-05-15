#!/usr/bin/env bash
set -Eeuo pipefail

create_filesystems() {
    local disk fs_type swap_enabled
    disk="$(state_get DISK)"
    [[ -b "${disk}" ]] || die "invalid disk: ${disk}"
    fs_type="$(state_get FS_TYPE)"
    swap_enabled="$(state_get SWAP_ENABLED no)"

    local efi_part swap_part root_part
    efi_part=$(get_partition_name "${disk}" 1)
    if [[ "${swap_enabled}" == 'yes' ]]; then
        swap_part=$(get_partition_name "${disk}" 2)
        root_part=$(get_partition_name "${disk}" 3)
    else
        root_part=$(get_partition_name "${disk}" 2)
    fi

    [[ -b "${efi_part}" ]] || die "invalid EFI partition: ${efi_part}"
    [[ -b "${root_part}" ]] || die "invalid root partition: ${root_part}"
    [[ "/dev/$(lsblk -no PKNAME "${efi_part}")" == "${disk}" ]] || die "EFI partition does not belong to selected disk"
    [[ "/dev/$(lsblk -no PKNAME "${root_part}")" == "${disk}" ]] || die "Root partition does not belong to selected disk"

    log_info "Wiping old filesystem signatures..."
    wipefs -af "${efi_part}" || true
    wipefs -af "${root_part}" || true

    if [[ "${swap_enabled}" == 'yes' ]]; then
        wipefs -af "${swap_part}" || true
    fi

    log_info "Ensuring EFI filesystem support..."
    pacman -S --needed --noconfirm dosfstools
    modprobe fat 2>/dev/null || true
    modprobe vfat 2>/dev/null || true

    case "${fs_type}" in
        btrfs)     pacman -S --needed --noconfirm btrfs-progs ; modprobe btrfs 2>/dev/null || true ;;
        ext4)      pacman -S --needed --noconfirm e2fsprogs  ; modprobe ext4 2>/dev/null || true ;;
        xfs)       pacman -S --needed --noconfirm xfsprogs   ; modprobe xfs 2>/dev/null || true ;;
        f2fs)      pacman -S --needed --noconfirm f2fs-tools ; command -v mkfs.f2fs >/dev/null || die 'mkfs.f2fs unavailable'; modprobe f2fs 2>/dev/null || true ;;
        bcachefs)
            if ! command -v mkfs.bcachefs >/dev/null 2>&1; then
                pacman -S --needed --noconfirm bcachefs-tools 2>/dev/null || true
            fi
            command -v mkfs.bcachefs >/dev/null || die 'mkfs.bcachefs unavailable'
            modprobe bcachefs 2>/dev/null || true ;;
        exfat)     pacman -S --needed --noconfirm exfatprogs ; modprobe exfat 2>/dev/null || true ;;
        zfs)
            command -v zpool >/dev/null || die 'zpool command unavailable'
            if ! modprobe zfs 2>/dev/null; then
                log_error "Failed to load ZFS kernel module. The live environment does not support ZFS."
                return 1
            fi ;;
    esac

    log_info "Formatting EFI partition..."
    mkfs.fat -F32 "${efi_part}" || die 'failed to create FAT32 EFI filesystem'

    partprobe "${disk}" || true
    udevadm settle || true

    if ! blkid -o value -s TYPE "${efi_part}" | grep -qi 'vfat'; then
        die "EFI partition ${efi_part} does not have a vfat signature — mkfs.fat may have failed silently"
    fi

    if [[ "${swap_enabled}" == 'yes' ]]; then
        log_info "Initializing swap..."
        [[ -b "${swap_part}" ]] || die "invalid swap partition: ${swap_part}"
        mkswap "${swap_part}"
        swapon "${swap_part}"
    fi

    case "${fs_type}" in
        btrfs)
            log_info "Creating BTRFS filesystem..."
            mkfs.btrfs -f "${root_part}"
            ;;

        ext4)
            log_info "Creating EXT4 filesystem..."
            mkfs.ext4 -F "${root_part}"
            ;;

        xfs)
            log_info "Creating XFS filesystem (GRUB-compatible)..."
            local xfs_config="/usr/share/xfsprogs/mkfs/lts_6.6.conf"
            
            if [[ -f "${xfs_config}" ]]; then
                mkfs.xfs -f -c "options=${xfs_config}" -m bigtime=0 "${root_part}"
            else
                mkfs.xfs -f -m bigtime=0 "${root_part}"
                log_warn "XFS LTS config not found – using upstream defaults. GRUB may fail if features are incompatible."
            fi
            ;;
        f2fs)
            log_info "Creating F2FS filesystem..."

            local dev_rota
            dev_rota=$(lsblk -dno ROTA "${root_part}" 2>/dev/null)

            if [[ "${dev_rota}" == "0" ]]; then
                log_warn "F2FS on non-rotational SSD – ext4 or XFS often perform better."

                if ! tui_yesno "F2FS on SSD" "F2FS is designed for raw flash (eMMC/SD/USB). Continue?"; then
                    die "User aborted F2FS creation"
                fi
            fi

            mkfs.f2fs -f -O extra_attr,compression "${root_part}"
            ;;

        bcachefs)
            log_info "Creating Bcachefs filesystem..."
            mkfs.bcachefs --force "${root_part}"
            ;;

        exfat)
            log_info "Creating exFAT filesystem..."
            mkfs.exfat -L "root" "${root_part}"
            ;;

        zfs)
            log_info "Clearing old ZFS labels..."
            zpool labelclear -f "${root_part}" 2>/dev/null || true
            wipefs -af "${root_part}" 2>/dev/null || true

            log_info "Creating ZFS pool..."
            zpool create -f \
                -o ashift=12 \
                -O compression=zstd \
                -O atime=off \
                -O mountpoint=none \
                zroot "${root_part}"

            zfs create -o mountpoint=/ zroot/root
            zfs mount zroot/root

            mkdir -p /mnt/boot
            ;;
    esac

    log_info "Filesystem creation complete."
}