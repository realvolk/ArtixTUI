#!/usr/bin/env bash
set -Eeuo pipefail;

mount_filesystems() {
    local disk;
    local fs_type;
    local swap_enabled;
    local bootloader;
    local btrfs_layout;

    disk="$(state_get DISK)";
    fs_type="$(state_get FS_TYPE)";
    swap_enabled="$(state_get SWAP_ENABLED no)";
    bootloader="$(state_get BOOTLOADER grub)";
    btrfs_layout="$(state_get BTRFS_LAYOUT standard)";

    local efi_part;
    local root_part;
    local efi_mount='/mnt/boot/efi';

    efi_part=$(get_partition_name "${disk}" 1);

    if [[ "${swap_enabled}" == 'yes' ]]; then
        root_part=$(get_partition_name "${disk}" 3);
    else
        root_part=$(get_partition_name "${disk}" 2);
    fi

    if [[ "${bootloader}" == 'efistub' ]]; then
        mkdir -p /mnt/boot
        efi_mount='/mnt/boot'
    else
        mkdir -p /mnt/boot/efi
    fi

    {
        case "${fs_type}" in
            btrfs)
                modprobe btrfs >/dev/null 2>&1 || true;
                ;;

            ext4)
                modprobe ext4 >/dev/null 2>&1 || true;
                ;;

            xfs)
                modprobe xfs >/dev/null 2>&1 || true;
                ;;

            f2fs)
                modprobe f2fs >/dev/null 2>&1 || true;
                ;;

            exfat)
                modprobe exfat >/dev/null 2>&1 || true;
                ;;
        esac

        modprobe vfat >/dev/null 2>&1 || true;

        printf '[*] Mounting root filesystem...\n';

        case "${fs_type}" in
            btrfs)
                mount "${root_part}" /mnt;

                mountpoint -q /mnt \
                    || die 'failed to mount root filesystem';

                printf '[*] Creating BTRFS subvolumes...\n';

                case "${btrfs_layout}" in
                    flat)
                        for subvol in @; do
                            if ! btrfs subvolume list /mnt \
                                | awk '{print $NF}' \
                                | grep -qx "${subvol}"; then

                                btrfs subvolume create "/mnt/${subvol}";
                            fi
                        done
                        ;;

                    snapshot)
                        for subvol in \
                            @ \
                            @home \
                            @log \
                            @pkg \
                            @snapshots; do

                            if ! btrfs subvolume list /mnt \
                                | awk '{print $NF}' \
                                | grep -qx "${subvol}"; then

                                btrfs subvolume create "/mnt/${subvol}";
                            fi
                        done
                        ;;

                    standard|*)
                        for subvol in \
                            @ \
                            @home; do

                            if ! btrfs subvolume list /mnt \
                                | awk '{print $NF}' \
                                | grep -qx "${subvol}"; then

                                btrfs subvolume create "/mnt/${subvol}";
                            fi
                        done
                        ;;
                esac

                umount /mnt;

                mount -o noatime,compress=zstd,subvol=@ \
                    "${root_part}" /mnt;

                mountpoint -q /mnt \
                    || die 'failed to mount root filesystem';

                case "${btrfs_layout}" in
                    flat)
                        ;;

                    snapshot)
                        mount --mkdir \
                            -o noatime,compress=zstd,subvol=@home \
                            "${root_part}" /mnt/home;

                        mount --mkdir \
                            -o noatime,compress=zstd,subvol=@log \
                            "${root_part}" /mnt/var/log;

                        mount --mkdir \
                            -o noatime,compress=zstd,subvol=@pkg \
                            "${root_part}" /mnt/var/cache/pacman/pkg;

                        mount --mkdir \
                            -o noatime,compress=zstd,subvol=@snapshots \
                            "${root_part}" /mnt/.snapshots;
                        ;;

                    standard|*)
                        mount --mkdir \
                            -o noatime,compress=zstd,subvol=@home \
                            "${root_part}" /mnt/home;
                        ;;
                esac
                ;;

            zfs)
                zpool export zroot 2>/dev/null || true;

                zpool import \
                    -R /mnt \
                    zroot;

                zfs mount zroot/root;

                mountpoint -q /mnt \
                    || die 'failed to mount ZFS root dataset';
                ;;

            ext4|xfs|f2fs|bcachefs)
                mount -t "${fs_type}" "${root_part}" /mnt;

                mountpoint -q /mnt \
                    || die 'failed to mount root filesystem';
                ;;

            exfat)
                mount -t exfat "${root_part}" /mnt;

                mountpoint -q /mnt \
                    || die 'failed to mount root filesystem';
                ;;

            *)
                die "unsupported filesystem: ${fs_type}";
                ;;
        esac

        printf '[*] Mounting EFI partition...\n';

        mount -t vfat --mkdir \
            "${efi_part}" \
            "${efi_mount}";

        mountpoint -q "${efi_mount}" \
            || die 'failed to mount EFI partition';

        printf '\n[*] Mount setup completed.\n';
    } 2>&1 | dialog \
        --clear \
        --title " Mount Setup " \
        --programbox 20 85;
}