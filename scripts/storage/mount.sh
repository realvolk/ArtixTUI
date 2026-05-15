#!/usr/bin/env bash
set -Eeuo pipefail

mount_filesystems() {
    local disk fs_type swap_enabled bootloader btrfs_layout
    disk="$(state_get DISK)"
    fs_type="$(state_get FS_TYPE)"
    swap_enabled="$(state_get SWAP_ENABLED no)"
    bootloader="$(state_get BOOTLOADER grub)"
    btrfs_layout="$(state_get BTRFS_LAYOUT standard)"

    local efi_part root_part efi_mount='/mnt/boot/efi'
    efi_part=$(get_partition_name "${disk}" 1)
    if [[ "${swap_enabled}" == 'yes' ]]; then
        root_part=$(get_partition_name "${disk}" 3)
    else
        root_part=$(get_partition_name "${disk}" 2)
    fi

    if [[ "${bootloader}" == 'efistub' ]]; then
        mkdir -p /mnt/boot
        efi_mount='/mnt/boot'
    else
        mkdir -p /mnt/boot/efi
    fi

    case "${fs_type}" in
        btrfs) modprobe btrfs 2>/dev/null || true ;;
        ext4)  modprobe ext4 2>/dev/null || true ;;
        xfs)   modprobe xfs 2>/dev/null || true ;;
        f2fs)  modprobe f2fs 2>/dev/null || true ;;
        exfat) modprobe exfat 2>/dev/null || true ;;
    esac
    command -v mount >/dev/null || die 'mount unavailable (util-linux missing)'
    modprobe vfat 2>/dev/null || die 'vfat kernel module unavailable'
    if mountpoint -q /mnt && mountpoint -q /mnt/boot/efi; then
        log_info "Filesystems already mounted, skipping remount."
        return 0
    fi
    umount -R /mnt/boot/efi 2>/dev/null || true
    umount -R /mnt 2>/dev/null || true
    mkdir -p /mnt
    log_info "Mounting root filesystem..."
    case "${fs_type}" in
        btrfs)
            mount "${root_part}" /mnt
            mountpoint -q /mnt || die 'failed to mount root filesystem'

            log_info "Creating BTRFS subvolumes..."
            case "${btrfs_layout}" in
                flat)
                    for subvol in @; do
                        if ! btrfs subvolume list /mnt | awk '{print $NF}' | grep -qx "${subvol}"; then
                            btrfs subvolume create "/mnt/${subvol}"
                        fi
                    done
                    ;;
                snapshot)
                    for subvol in @ @home @log @pkg @snapshots; do
                        if ! btrfs subvolume list /mnt | awk '{print $NF}' | grep -qx "${subvol}"; then
                            btrfs subvolume create "/mnt/${subvol}"
                        fi
                    done
                    ;;
                standard|*)
                    for subvol in @ @home; do
                        if ! btrfs subvolume list /mnt | awk '{print $NF}' | grep -qx "${subvol}"; then
                            btrfs subvolume create "/mnt/${subvol}"
                        fi
                    done
                    ;;
            esac

            umount /mnt
            mount -o noatime,compress=zstd,subvol=@ "${root_part}" /mnt
            mountpoint -q /mnt || die 'failed to mount root filesystem'

            case "${btrfs_layout}" in
                flat) ;;
                snapshot)
                    mount --mkdir -o noatime,compress=zstd,subvol=@home "${root_part}" /mnt/home
                    mount --mkdir -o noatime,compress=zstd,subvol=@log "${root_part}" /mnt/var/log
                    mount --mkdir -o noatime,compress=zstd,subvol=@pkg "${root_part}" /mnt/var/cache/pacman/pkg
                    mount --mkdir -o noatime,compress=zstd,subvol=@snapshots "${root_part}" /mnt/.snapshots
                    ;;
                standard|*)
                    mount --mkdir -o noatime,compress=zstd,subvol=@home "${root_part}" /mnt/home
                    ;;
            esac
            ;;
        zfs)
            zpool export zroot 2>/dev/null || true
            zpool import -R /mnt zroot
            zfs mount zroot/root
            mountpoint -q /mnt || die 'failed to mount ZFS root dataset'
            ;;
        ext4|xfs|f2fs|bcachefs)
            local mount_opts="defaults"
            if [[ "$(lsblk -dno ROTA "${root_part}" 2>/dev/null)" == "0" ]]; then
                mount_opts="${mount_opts},discard"
            fi
            mount -t "${fs_type}" -o "${mount_opts}" "${root_part}" /mnt
            mountpoint -q /mnt || die 'failed to mount root filesystem'
            ;;
        exfat)
            mount -t exfat "${root_part}" /mnt
            mountpoint -q /mnt || die 'failed to mount root filesystem'
            ;;
        *)
            die "unsupported filesystem: ${fs_type}"
            ;;
    esac
    local efi_fs
    efi_fs="$(blkid -o value -s TYPE "${efi_part}" 2>/dev/null || true)"

    [[ "${efi_fs}" == "vfat" ]] || \
        die "EFI partition is not vfat (detected: ${efi_fs:-unknown})"
    log_info "Mounting EFI partition..."
    mount -t vfat --mkdir "${efi_part}" "${efi_mount}"
    mountpoint -q "${efi_mount}" || die 'failed to mount EFI partition'

    log_info "Mount setup completed."
}